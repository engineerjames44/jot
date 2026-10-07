// Jot Prototype One: hold the button to record, the clip streams to the iPhone over BLE.
// XIAO nRF52840 Sense on the "Seeed nRF52 Boards" core (not mbed), Bluefruit library.
// Same BLE service and packets as jot_proto1_clip (the ArduinoBLE version), so the app is
// unchanged. Bluefruit waits for a free radio buffer instead of dropping packets, and
// asks for a bigger, faster link (2M PHY, longer packets).
//
// Audio: built-in PDM mic, 16 kHz mono, IMA ADPCM (4 bits per sample, 2 samples per
// byte, low nibble first) = 8 KB per second. Encoder state starts at predictor 0,
// index 0 for every clip. Up to 15 s per clip (RAM).
//
// Jot BLE service:
//   Service             a5bc1576-7c64-4efe-9c40-2b39fdf53bed
//   Button  (notify)    15619899-b8cd-4254-97ff-0c757fa68b3d   uint8: 1 pressed, 0 released
//   Audio   (notify)    18d71983-6ed1-441e-bdd3-80fe9e1b1529   clip packets, max 128 bytes:
//     START  01 | codec u8 (1 = IMA ADPCM) | sample rate u16 LE | total bytes u32 LE (0 at the press)
//     DATA   02 | packet number u16 LE (from 0) | up to 125 bytes of ADPCM
//     END    03 | packet count u16 LE | total bytes u32 LE
//   Status (read/notify) 0d4a7b8e-5c21-4f3a-8e6d-2b9c1a7f4e53   every 10 s and on change:
//     percent u8 | flags u8 (bit 0 = charging) | millivolts u16 LE
//   Resend  (write)     6e0b7c52-2f6a-4d0e-9b8c-3f1d5a7e9c41   from the phone, after an END:
//     04 | count u8 (0-60) | packet numbers u16 LE...   resends those packets, then END again
//   Audio streams while the button is held; the phone asks again for anything missing,
//   so the last clip stays in RAM.

#include <bluefruit.h>
#include <PDM.h>

const int BUTTON_PIN = D1;
const int SAMPLE_RATE = 16000;
const int CLIP_MAX = 120000;            // bytes of ADPCM = 15 s
const int PACKET_MAX = 128;
const int DATA_MAX = PACKET_MAX - 3;
const int DEBOUNCE_MS = 20;
const int PIN_CHG = 23;                 // P0.17, the charger's ~CHG (the variant doesn't name it)

// UUIDs, least significant byte first.
const uint8_t UUID_SERVICE[16] = {0xED, 0x3B, 0xF5, 0xFD, 0x39, 0x2B, 0x40, 0x9C, 0xFE, 0x4E, 0x64, 0x7C, 0x76, 0x15, 0xBC, 0xA5};
const uint8_t UUID_BUTTON[16]  = {0x3D, 0x8B, 0xA6, 0x7F, 0x75, 0x0C, 0xFF, 0x97, 0x54, 0x42, 0xCD, 0xB8, 0x99, 0x98, 0x61, 0x15};
const uint8_t UUID_AUDIO[16]   = {0x29, 0x15, 0x1B, 0x9E, 0xFE, 0x80, 0xD3, 0xBD, 0x1E, 0x44, 0xD1, 0x6E, 0x83, 0x19, 0xD7, 0x18};
const uint8_t UUID_RESEND[16]  = {0x41, 0x9C, 0x7E, 0x5A, 0x1D, 0x3F, 0x8C, 0x9B, 0x0E, 0x4D, 0x6A, 0x2F, 0x52, 0x7C, 0x0B, 0x6E};
const uint8_t UUID_STATUS[16]  = {0x53, 0x4E, 0x7F, 0x1A, 0x9C, 0x2B, 0x6D, 0x8E, 0x3A, 0x4F, 0x21, 0x5C, 0x8E, 0x7B, 0x4A, 0x0D};

BLEService jotService(UUID_SERVICE);
BLECharacteristic buttonChar(UUID_BUTTON);
BLECharacteristic audioChar(UUID_AUDIO);
BLECharacteristic resendChar(UUID_RESEND);
BLECharacteristic statusChar(UUID_STATUS);

uint8_t clip[CLIP_MAX];
volatile int clipLen = 0;               // bytes written
volatile bool highNibble = false;
volatile bool recording = false;
int lastTotal = 0;                      // bytes in the last clip, kept for resends
bool streaming = false;                 // this clip is being sent while it records
int nextSeq = 0;                        // next packet to stream

// A resend request from the phone, handled in loop() (the callback runs in the BLE task).
uint8_t resendReq[PACKET_MAX];
volatile int resendLen = 0;

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
// XIAO: battery through a 1M/510k divider to PIN_VBAT (P0.31), enabled by VBAT_ENABLE
// (P0.14) LOW. Keep it LOW: driving it HIGH while charging can damage P0.31.
// Charge status on PIN_CHG (P0.17), LOW = charging.
int batteryMillivolts() {
  long sum = 0;
  for (int i = 0; i < 8; i++) sum += analogRead(PIN_VBAT);
  return (int)(sum / 8 * 2400L / 4095 * 1510 / 510);    // 12-bit, 2.4 V reference
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
  bool charging = digitalRead(PIN_CHG) == LOW;
  if (!force && charging == lastCharging && millis() - lastAt < 10000) return;
  lastAt = millis();
  lastCharging = charging;
  int mv = batteryMillivolts();
  uint8_t p[4] = {(uint8_t)batteryPercent(mv), (uint8_t)(charging ? 1 : 0), (uint8_t)(mv & 0xff), (uint8_t)(mv >> 8)};
  statusChar.write(p, 4);
  if (statusChar.notifyEnabled()) statusChar.notify(p, 4);
}

// ---- sending ----
// notify() waits for a free radio buffer (up to ~100 ms) instead of dropping the packet.
bool sendPacket(const uint8_t* data, int len) {
  feedWatchdog();
  if (!Bluefruit.connected() || !audioChar.notifyEnabled()) return false;
  for (int tries = 0; tries < 5; tries++) {
    if (audioChar.notify(data, len)) return true;
    if (!Bluefruit.connected()) return false;
  }
  return false;
}

bool sendData(int seq, int total) {
  uint8_t p[PACKET_MAX];
  int off = seq * DATA_MAX;
  if (off < 0 || off >= total) return true;
  int n = min(DATA_MAX, total - off);
  p[0] = 0x02; p[1] = seq & 0xff; p[2] = seq >> 8;
  memcpy(p + 3, clip + off, n);
  return sendPacket(p, 3 + n);
}

void sendEnd(int total) {
  uint8_t p[7];
  int count = (total + DATA_MAX - 1) / DATA_MAX;
  p[0] = 0x03; p[1] = count & 0xff; p[2] = count >> 8;
  for (int i = 0; i < 4; i++) p[3 + i] = (total >> (8 * i)) & 0xff;
  sendPacket(p, 7);
}

void sendStart() {
  uint8_t p[8] = {0x01, 1, SAMPLE_RATE & 0xff, SAMPLE_RATE >> 8, 0, 0, 0, 0};
  sendPacket(p, 8);
}

// After release: send whatever hasn't streamed yet, then END.
void finishClip(int total) {
  unsigned long t0 = millis();
  if (!streaming) { sendStart(); nextSeq = 0; }
  int count = (total + DATA_MAX - 1) / DATA_MAX;
  int left = count - nextSeq;
  for (; nextSeq < count; nextSeq++) {
    if (!sendData(nextSeq, total)) { Serial.print("DATA failed at packet "); Serial.println(nextSeq); streaming = false; return; }
  }
  sendEnd(total);
  streaming = false;
  Serial.print("Sent "); Serial.print(count); Serial.print(" packets; ");
  Serial.print(left); Serial.print(" were left at release, sent in ");
  Serial.print(millis() - t0); Serial.println(" ms");
}

void onResendWrite(uint16_t conn, BLECharacteristic* chr, uint8_t* data, uint16_t len) {
  if (resendLen) return;                    // still handling the last one; the phone asks again
  memcpy(resendReq, data, min((int)len, PACKET_MAX));
  resendLen = min((int)len, PACKET_MAX);
}

// The phone asks for packets it missed: 04 | count | packet numbers u16 LE.
void handleResend() {
  int len = resendLen;
  if (len < 2 || resendReq[0] != 0x04 || recording || lastTotal == 0) { resendLen = 0; return; }
  int count = min((int)resendReq[1], (len - 2) / 2);
  for (int i = 0; i < count; i++) {
    if (!sendData(resendReq[2 + 2 * i] | (resendReq[3 + 2 * i] << 8), lastTotal)) { resendLen = 0; return; }
  }
  sendEnd(lastTotal);
  resendLen = 0;
  Serial.print("Resent "); Serial.print(count); Serial.println(" packets");
}

// ---- connection ----
void onConnect(uint16_t conn) {
  BLEConnection* c = Bluefruit.Connection(conn);
  c->requestPHY();                          // 2 Mbit/s radio if the phone allows
  c->requestDataLengthUpdate();             // longer packets on air
  c->requestMtuExchange(247);
  Serial.println("connected");
}

void onDisconnect(uint16_t conn, uint8_t reason) {
  streaming = false;
  Serial.print("disconnected, reason 0x"); Serial.println(reason, HEX);
}

void setup() {
  pinMode(BUTTON_PIN, INPUT_PULLUP);
  pinMode(VBAT_ENABLE, OUTPUT); digitalWrite(VBAT_ENABLE, LOW);   // battery divider on
  pinMode(PIN_CHG, INPUT);
  analogReference(AR_INTERNAL_2_4);
  analogReadResolution(12);
  pinMode(LED_RED, OUTPUT); pinMode(LED_GREEN, OUTPUT); pinMode(LED_BLUE, OUTPUT);
  setLed(LED_RED, false); setLed(LED_GREEN, false); setLed(LED_BLUE, false);
  Serial.begin(115200);

  Bluefruit.configPrphBandwidth(BANDWIDTH_MAX);
  Bluefruit.begin();
  Bluefruit.autoConnLed(false);
  Bluefruit.setTxPower(4);
  Bluefruit.setName("Jot");
  Bluefruit.Periph.setConnInterval(12, 24); // 15-30 ms
  Bluefruit.Periph.setConnectCallback(onConnect);
  Bluefruit.Periph.setDisconnectCallback(onDisconnect);

  jotService.begin();

  buttonChar.setProperties(CHR_PROPS_READ | CHR_PROPS_NOTIFY);
  buttonChar.setPermission(SECMODE_OPEN, SECMODE_NO_ACCESS);
  buttonChar.setFixedLen(1);
  buttonChar.begin();
  buttonChar.write8(0);

  audioChar.setProperties(CHR_PROPS_NOTIFY);
  audioChar.setPermission(SECMODE_OPEN, SECMODE_NO_ACCESS);
  audioChar.setMaxLen(PACKET_MAX);
  audioChar.begin();

  resendChar.setProperties(CHR_PROPS_WRITE);
  resendChar.setPermission(SECMODE_NO_ACCESS, SECMODE_OPEN);
  resendChar.setMaxLen(PACKET_MAX);
  resendChar.setWriteCallback(onResendWrite);
  resendChar.begin();

  statusChar.setProperties(CHR_PROPS_READ | CHR_PROPS_NOTIFY);
  statusChar.setPermission(SECMODE_OPEN, SECMODE_NO_ACCESS);
  statusChar.setFixedLen(4);
  statusChar.begin();
  updateStatus(true);

  Bluefruit.Advertising.addFlags(BLE_GAP_ADV_FLAGS_LE_ONLY_GENERAL_DISC_MODE);
  Bluefruit.Advertising.addTxPower();
  Bluefruit.Advertising.addService(jotService);
  Bluefruit.ScanResponse.addName();
  Bluefruit.Advertising.restartOnDisconnect(true);   // advertise again after every drop
  Bluefruit.Advertising.setInterval(32, 244);         // 20 ms fast, then 152.5 ms
  Bluefruit.Advertising.setFastTimeout(30);
  Bluefruit.Advertising.start(0);

  PDM.onReceive(onPDMdata);
  PDM.setGain(30);
  if (!PDM.begin(1, SAMPLE_RATE)) { Serial.println("Mic failed"); while (true) { setLed(LED_RED, true); delay(200); setLed(LED_RED, false); delay(200); } }
  startWatchdog();
  Serial.println("Ready. Connect from the phone, then hold the button and talk.");
}

void loop() {
  feedWatchdog();
  bool connected = Bluefruit.connected();
  setLed(LED_GREEN, connected && !recording);
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
    setLed(LED_BLUE, true);
    if (buttonChar.notifyEnabled()) buttonChar.notify8(1);
    buttonChar.write8(1);
    streaming = connected;
    nextSeq = 0;
    if (streaming) sendStart();
    Serial.println("recording...");
  }
  if (recording && streaming && (nextSeq + 1) * DATA_MAX <= clipLen) {
    if (sendData(nextSeq, clipLen)) nextSeq++;   // a full packet is ready: stream it
    else streaming = false;                      // phone gone: send it all at release if it's back
  }
  if (!pressed && wasPressed) {             // stop and finish sending
    noInterrupts(); recording = false; int total = clipLen; interrupts();
    setLed(LED_BLUE, false);
    if (buttonChar.notifyEnabled()) buttonChar.notify8(0);
    buttonChar.write8(0);
    Serial.print("recorded "); Serial.print(total); Serial.print(" bytes (");
    Serial.print(total * 2.0 / SAMPLE_RATE, 1); Serial.println(" s)");
    lastTotal = total;
    if (Bluefruit.connected() && total > 0) finishClip(total);
    else { streaming = false; Serial.println("not connected: clip not sent"); }
  }
  if (resendLen) handleResend();
  if (recording && clipLen >= CLIP_MAX) setLed(LED_RED, true); else setLed(LED_RED, false);  // red = clip full
  delay(1);
}
