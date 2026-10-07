// Jot Prototype One, step 5b: record a clip while the button is held, send it over BLE on release.
// XIAO nRF52840 Sense, Seeed nRF52 mbed-enabled core, ArduinoBLE library.
//
// Audio: built-in PDM mic, 16 kHz mono, compressed with IMA ADPCM (4 bits per sample,
// 2 samples per byte, low nibble first) = 8 KB per second. Encoder state starts at
// predictor 0, index 0 for every clip. Up to ~15 s per clip (RAM buffer).
//
// Jot BLE service (the iPhone app uses these IDs):
//   Service           a5bc1576-7c64-4efe-9c40-2b39fdf53bed
//   Button  (notify)  15619899-b8cd-4254-97ff-0c757fa68b3d   uint8: 1 pressed, 0 released
//   Audio   (notify)  18d71983-6ed1-441e-bdd3-80fe9e1b1529   clip packets, max 128 bytes:
//     START  01 | codec u8 (1 = IMA ADPCM) | sample rate u16 LE | total bytes u32 LE
//     DATA   02 | packet number u16 LE (from 0) | up to 125 bytes of ADPCM
//     END    03 | packet count u16 LE | total bytes u32 LE
//   Status (read/notify) 0d4a7b8e-5c21-4f3a-8e6d-2b9c1a7f4e53   battery, every 10 s and on change:
//     percent u8 | flags u8 (bit 0 = charging) | millivolts u16 LE
//   Resend  (write)   6e0b7c52-2f6a-4d0e-9b8c-3f1d5a7e9c41   from the phone, after an END:
//     04 | count u8 (0-60) | packet numbers u16 LE...   resends those packets, then END again
//   Audio streams while the button is held, one packet every PACKET_GAP_MS (sent flat
//   out, ArduinoBLE silently drops packets). START goes at the press with total 0; the
//   END after release carries the real totals. Anything still lost is asked for again
//   by the phone, so the last clip stays in RAM.

#include <ArduinoBLE.h>
#include <PDM.h>

const int BUTTON_PIN = D1;
const int SAMPLE_RATE = 16000;
const int CLIP_MAX = 120000;            // bytes of ADPCM = 15 s
const int PACKET_MAX = 128;
const int PACKET_GAP_MS = 14;           // ~71 packets/s; the audio needs 64
const int DEBOUNCE_MS = 20;
const int DATA_MAX = PACKET_MAX - 3;

BLEService jotService("a5bc1576-7c64-4efe-9c40-2b39fdf53bed");
BLEByteCharacteristic buttonChar("15619899-b8cd-4254-97ff-0c757fa68b3d", BLERead | BLENotify);
BLECharacteristic audioChar("18d71983-6ed1-441e-bdd3-80fe9e1b1529", BLENotify, PACKET_MAX, false);
BLECharacteristic statusChar("0d4a7b8e-5c21-4f3a-8e6d-2b9c1a7f4e53", BLERead | BLENotify, 4, true);
BLECharacteristic resendChar("6e0b7c52-2f6a-4d0e-9b8c-3f1d5a7e9c41", BLEWrite, PACKET_MAX, false);

uint8_t clip[CLIP_MAX];
volatile int clipLen = 0;               // bytes written
volatile bool highNibble = false;
volatile bool recording = false;
int lastTotal = 0;                      // bytes in the last clip, kept for resends
bool streaming = false;                 // this clip is being sent while it records
int nextSeq = 0;                        // next packet to stream
unsigned long lastSendAt = 0;

// ---- IMA ADPCM encoder ----
const int8_t indexTable[16] = {-1, -1, -1, -1, 2, 4, 6, 8, -1, -1, -1, -1, 2, 4, 6, 8};
const int16_t stepTable[89] = {
  7, 8, 9, 10, 11, 12, 13, 14, 16, 17, 19, 21, 23, 25, 28, 31, 34, 37, 41, 45, 50, 55, 60, 66,
  73, 80, 88, 97, 107, 118, 130, 143, 157, 173, 190, 209, 230, 253, 279, 307, 337, 371, 408,
  449, 494, 544, 598, 658, 724, 796, 876, 963, 1060, 1166, 1282, 1411, 1552, 1707, 1878, 2066,
  2272, 2499, 2749, 3024, 3327, 3660, 4026, 4428, 4871, 5358, 5894, 6484, 7132, 7845, 8630,
  9493, 10442, 11487, 12635, 13899, 15289, 16818, 18500, 20350, 22385, 24623, 27086, 29794, 32767};
int predictor = 0, stepIndex = 0;

uint8_t adpcmEncode(int16_t sample) {
  int step = stepTable[stepIndex];
  int diff = sample - predictor;
  uint8_t code = 0;
  if (diff < 0) { code = 8; diff = -diff; }
  int delta = step >> 3;
  if (diff >= step) { code |= 4; diff -= step; delta += step; }
  step >>= 1;
  if (diff >= step) { code |= 2; diff -= step; delta += step; }
  step >>= 1;
  if (diff >= step) { code |= 1; delta += step; }
  predictor += (code & 8) ? -delta : delta;
  if (predictor > 32767) predictor = 32767;
  if (predictor < -32768) predictor = -32768;
  stepIndex += indexTable[code];
  if (stepIndex < 0) stepIndex = 0;
  if (stepIndex > 88) stepIndex = 88;
  return code;
}

// ---- mic ----
short pdmBuffer[512];

void onPDMdata() {
  int bytes = PDM.available();
  PDM.read(pdmBuffer, bytes);
  if (!recording) return;
  int n = bytes / 2;
  for (int i = 0; i < n && clipLen < CLIP_MAX; i++) {
    uint8_t code = adpcmEncode(pdmBuffer[i]);
    if (!highNibble) { clip[clipLen] = code; highNibble = true; }
    else { clip[clipLen] |= code << 4; clipLen++; highNibble = false; }
  }
}

void setLed(int pin, bool on) { digitalWrite(pin, on ? LOW : HIGH); }  // active-low LEDs

// Hardware watchdog: if the loop ever stops feeding it for 8 s, the XIAO resets itself.
void startWatchdog() {
  NRF_WDT->CONFIG = (WDT_CONFIG_SLEEP_Run << WDT_CONFIG_SLEEP_Pos) | (WDT_CONFIG_HALT_Pause << WDT_CONFIG_HALT_Pos);
  NRF_WDT->CRV = 8 * 32768;
  NRF_WDT->RREN = WDT_RREN_RR0_Msk;
  NRF_WDT->TASKS_START = 1;
}
void feedWatchdog() { NRF_WDT->RR[0] = WDT_RR_RR_Reload; }

// ---- battery ----
// XIAO: battery through a 1M/510k divider to P0.31, enabled by P0.14 LOW. Keep P0.14
// LOW (driving it HIGH while charging can damage P0.31). Charge status on P0.17, LOW = charging.
int batteryMillivolts() {
  long sum = 0;
  for (int i = 0; i < 8; i++) sum += analogRead(P0_31);
  return (int)(sum / 8 * 3300L / 1023 * 1510 / 510);
}

int batteryPercent(int mv) {
  // Rough LiPo curve at light load.
  const int volts[] = {3300, 3500, 3600, 3700, 3750, 3800, 3900, 4000, 4100, 4200};
  const int pct[]   = {   0,    5,   10,   25,   40,   50,   65,   80,   92,  100};
  if (mv <= volts[0]) return 0;
  for (int i = 1; i < 10; i++)
    if (mv <= volts[i]) return pct[i - 1] + (pct[i] - pct[i - 1]) * (mv - volts[i - 1]) / (volts[i] - volts[i - 1]);
  return 100;
}

void updateStatus(bool force) {
  static unsigned long lastAt = 0;
  static bool lastCharging = false;
  bool charging = digitalRead(P0_17) == LOW;
  if (!force && charging == lastCharging && millis() - lastAt < 10000) return;
  lastAt = millis();
  lastCharging = charging;
  int mv = batteryMillivolts();
  uint8_t p[4] = {(uint8_t)batteryPercent(mv), (uint8_t)(charging ? 1 : 0), (uint8_t)(mv & 0xff), (uint8_t)(mv >> 8)};
  statusChar.writeValue(p, 4);
}

bool sendPacket(const uint8_t* data, int len) {
  for (int tries = 0; tries < 200; tries++) {
    if (!BLE.connected()) return false;     // no phone: don't sit retrying
    if (audioChar.writeValue(data, len)) return true;
    BLE.poll();
    delay(2);
  }
  return false;
}

// Waits out the gap since the last packet, then sends.
bool pacedPacket(const uint8_t* data, int len) {
  while (millis() - lastSendAt < PACKET_GAP_MS) BLE.poll();
  feedWatchdog();
  lastSendAt = millis();
  return sendPacket(data, len);
}

bool sendData(int seq, int total) {
  uint8_t p[PACKET_MAX];
  int off = seq * DATA_MAX;
  if (off < 0 || off >= total) return true;
  int n = min(DATA_MAX, total - off);
  p[0] = 0x02; p[1] = seq & 0xff; p[2] = seq >> 8;
  memcpy(p + 3, clip + off, n);
  return pacedPacket(p, 3 + n);
}

void sendEnd(int total) {
  uint8_t p[7];
  int count = (total + DATA_MAX - 1) / DATA_MAX;
  p[0] = 0x03; p[1] = count & 0xff; p[2] = count >> 8;
  for (int i = 0; i < 4; i++) p[3 + i] = (total >> (8 * i)) & 0xff;
  pacedPacket(p, 7);
  pacedPacket(p, 7);                    // twice: a lost END costs the phone a wait
}

void sendStart() {
  uint8_t p[8] = {0x01, 1, SAMPLE_RATE & 0xff, SAMPLE_RATE >> 8, 0, 0, 0, 0};
  pacedPacket(p, 8);
}

// After release: send whatever hasn't streamed yet, then END.
void finishClip(int total) {
  unsigned long t0 = millis();
  if (!streaming) { sendStart(); nextSeq = 0; }
  int count = (total + DATA_MAX - 1) / DATA_MAX;
  int left = count - nextSeq;
  for (; nextSeq < count; nextSeq++) {
    if (!sendData(nextSeq, total)) { Serial.print("DATA failed at packet "); Serial.println(nextSeq); return; }
  }
  sendEnd(total);
  streaming = false;
  Serial.print("Sent "); Serial.print(count); Serial.print(" packets; ");
  Serial.print(left); Serial.print(" were left at release, sent in ");
  Serial.print(millis() - t0); Serial.println(" ms");
}

// The phone asks for packets it missed: 04 | count | packet numbers u16 LE.
void handleResend() {
  int len = resendChar.valueLength();
  uint8_t req[PACKET_MAX];
  memcpy(req, resendChar.value(), len);
  if (len < 2 || req[0] != 0x04 || recording || lastTotal == 0) return;
  int count = min((int)req[1], (len - 2) / 2);
  for (int i = 0; i < count; i++) {
    if (!sendData(req[2 + 2 * i] | (req[3 + 2 * i] << 8), lastTotal)) return;
    BLE.poll();
  }
  sendEnd(lastTotal);
  Serial.print("Resent "); Serial.print(count); Serial.println(" packets");
}

void setup() {
  pinMode(BUTTON_PIN, INPUT_PULLUP);
  pinMode(P0_14, OUTPUT); digitalWrite(P0_14, LOW);   // battery divider on
  pinMode(P0_17, INPUT);                              // charge status
  pinMode(LEDR, OUTPUT); pinMode(LEDG, OUTPUT); pinMode(LEDB, OUTPUT);
  setLed(LEDR, false); setLed(LEDG, false); setLed(LEDB, false);
  Serial.begin(115200);

  if (!BLE.begin()) { Serial.println("BLE failed"); while (true) { setLed(LEDR, true); delay(200); setLed(LEDR, false); delay(200); } }
  BLE.setLocalName("Jot");
  BLE.setDeviceName("Jot");
  BLE.setAdvertisedService(jotService);
  BLE.setConnectionInterval(12, 24);    // ask for 15-30 ms (units of 1.25 ms) for faster sending
  jotService.addCharacteristic(buttonChar);
  jotService.addCharacteristic(audioChar);
  jotService.addCharacteristic(resendChar);
  jotService.addCharacteristic(statusChar);
  BLE.addService(jotService);
  buttonChar.writeValue(0);
  updateStatus(true);
  BLE.advertise();

  PDM.onReceive(onPDMdata);
  PDM.setGain(30);
  if (!PDM.begin(1, SAMPLE_RATE)) { Serial.println("Mic failed"); while (true) { setLed(LEDR, true); delay(200); setLed(LEDR, false); delay(200); } }
  startWatchdog();
  Serial.println("Ready. Connect from the phone, then hold the button and talk.");
}

void loop() {
  feedWatchdog();
  BLE.poll();
  BLEDevice central = BLE.central();
  bool connected = central && central.connected();
  setLed(LEDG, connected && !recording);

  static bool wasConnected = false;
  if (connected && !wasConnected) { Serial.println("connected"); updateStatus(true); }
  if (!connected && wasConnected) {         // phone gone: stop sending, advertise again
    Serial.println("disconnected");
    streaming = false;
    BLE.advertise();
  }
  wasConnected = connected;
  if (!recording) updateStatus(false);

  // Debounced button.
  static bool pressed = false;
  static bool lastReading = false;
  static unsigned long changedAt = 0;
  bool reading = digitalRead(BUTTON_PIN) == LOW;
  if (reading != lastReading) { lastReading = reading; changedAt = millis(); }
  bool wasPressed = pressed;
  if (millis() - changedAt >= DEBOUNCE_MS) pressed = reading;

  if (pressed && !wasPressed) {             // start recording, and streaming if connected
    noInterrupts(); clipLen = 0; highNibble = false; predictor = 0; stepIndex = 0; recording = true; interrupts();
    setLed(LEDB, true);
    buttonChar.writeValue(1);
    streaming = connected;
    nextSeq = 0;
    if (streaming) sendStart();
    Serial.println("recording...");
  }
  if (recording && streaming && (nextSeq + 1) * DATA_MAX <= clipLen && millis() - lastSendAt >= PACKET_GAP_MS) {
    if (sendData(nextSeq, clipLen)) nextSeq++;   // a full packet is ready: stream it
    else streaming = false;                      // phone gone: finish later if it's back
  }
  if (!pressed && wasPressed) {             // stop and finish sending
    noInterrupts(); recording = false; int total = clipLen; interrupts();
    setLed(LEDB, false);
    buttonChar.writeValue(0);
    Serial.print("recorded "); Serial.print(total); Serial.print(" bytes (");
    Serial.print(total * 2.0 / SAMPLE_RATE, 1); Serial.println(" s)");
    lastTotal = total;
    if (connected && total > 0) finishClip(total);
    else { streaming = false; Serial.println("not connected: clip not sent"); }
  }
  if (resendChar.written()) handleResend();
  if (recording && clipLen >= CLIP_MAX) setLed(LEDR, true); else setLed(LEDR, false);  // red = clip full
  delay(1);
}
