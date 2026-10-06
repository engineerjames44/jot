// Jot V1, step 5b: record a clip while the button is held, send it over BLE on release.
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

#include <ArduinoBLE.h>
#include <PDM.h>

const int BUTTON_PIN = D1;
const int SAMPLE_RATE = 16000;
const int CLIP_MAX = 120000;            // bytes of ADPCM = 15 s
const int PACKET_MAX = 128;
const int DATA_MAX = PACKET_MAX - 3;

BLEService jotService("a5bc1576-7c64-4efe-9c40-2b39fdf53bed");
BLEByteCharacteristic buttonChar("15619899-b8cd-4254-97ff-0c757fa68b3d", BLERead | BLENotify);
BLECharacteristic audioChar("18d71983-6ed1-441e-bdd3-80fe9e1b1529", BLENotify, PACKET_MAX, false);

uint8_t clip[CLIP_MAX];
volatile int clipLen = 0;               // bytes written
volatile bool highNibble = false;
volatile bool recording = false;

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

bool sendPacket(const uint8_t* data, int len) {
  for (int tries = 0; tries < 200; tries++) {
    if (audioChar.writeValue(data, len)) return true;
    BLE.poll();
    delay(2);
  }
  return false;
}

void sendClip(int total) {
  uint8_t p[PACKET_MAX];
  unsigned long t0 = millis();
  p[0] = 0x01; p[1] = 1;
  p[2] = SAMPLE_RATE & 0xff; p[3] = SAMPLE_RATE >> 8;
  for (int i = 0; i < 4; i++) p[4 + i] = (total >> (8 * i)) & 0xff;
  if (!sendPacket(p, 8)) { Serial.println("START failed"); return; }

  uint16_t seq = 0;
  for (int off = 0; off < total; off += DATA_MAX, seq++) {
    int n = min(DATA_MAX, total - off);
    p[0] = 0x02; p[1] = seq & 0xff; p[2] = seq >> 8;
    memcpy(p + 3, clip + off, n);
    if (!sendPacket(p, 3 + n)) { Serial.print("DATA failed at packet "); Serial.println(seq); return; }
    BLE.poll();
  }
  p[0] = 0x03; p[1] = seq & 0xff; p[2] = seq >> 8;
  for (int i = 0; i < 4; i++) p[3 + i] = (total >> (8 * i)) & 0xff;
  sendPacket(p, 7);

  unsigned long ms = millis() - t0;
  Serial.print("Sent "); Serial.print(total); Serial.print(" bytes in "); Serial.print(seq);
  Serial.print(" packets, "); Serial.print(ms); Serial.print(" ms (");
  Serial.print(ms ? total * 1000UL / ms : 0); Serial.println(" bytes/s)");
}

void setup() {
  pinMode(BUTTON_PIN, INPUT_PULLUP);
  pinMode(LEDR, OUTPUT); pinMode(LEDG, OUTPUT); pinMode(LEDB, OUTPUT);
  setLed(LEDR, false); setLed(LEDG, false); setLed(LEDB, false);
  Serial.begin(115200);

  if (!BLE.begin()) { Serial.println("BLE failed"); while (true) { setLed(LEDR, true); delay(200); setLed(LEDR, false); delay(200); } }
  BLE.setLocalName("Jot");
  BLE.setDeviceName("Jot");
  BLE.setAdvertisedService(jotService);
  jotService.addCharacteristic(buttonChar);
  jotService.addCharacteristic(audioChar);
  BLE.addService(jotService);
  buttonChar.writeValue(0);
  BLE.advertise();

  PDM.onReceive(onPDMdata);
  PDM.setGain(30);
  if (!PDM.begin(1, SAMPLE_RATE)) { Serial.println("Mic failed"); while (true) { setLed(LEDR, true); delay(200); setLed(LEDR, false); delay(200); } }
  Serial.println("Ready. Connect from the phone, then hold the button and talk.");
}

void loop() {
  BLE.poll();
  BLEDevice central = BLE.central();
  bool connected = central && central.connected();
  setLed(LEDG, connected && !recording);

  bool pressed = digitalRead(BUTTON_PIN) == LOW;
  static bool wasPressed = false;

  if (pressed && !wasPressed) {             // start recording
    noInterrupts(); clipLen = 0; highNibble = false; predictor = 0; stepIndex = 0; recording = true; interrupts();
    setLed(LEDB, true);
    buttonChar.writeValue(1);
    Serial.println("recording...");
  }
  if (!pressed && wasPressed) {             // stop and send
    noInterrupts(); recording = false; int total = clipLen; interrupts();
    setLed(LEDB, false);
    buttonChar.writeValue(0);
    Serial.print("recorded "); Serial.print(total); Serial.print(" bytes (");
    Serial.print(total * 2.0 / SAMPLE_RATE, 1); Serial.println(" s)");
    if (connected && total > 0) sendClip(total);
    else Serial.println("not connected: clip not sent");
  }
  if (recording && clipLen >= CLIP_MAX) setLed(LEDR, true); else setLed(LEDR, false);  // red = clip full
  wasPressed = pressed;
  delay(5);
}
