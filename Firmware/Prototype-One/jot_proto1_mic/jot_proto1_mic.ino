// Jot Prototype One, step 5a: microphone check on the XIAO nRF52840 Sense.
// While the button is held, the built-in PDM mic records at 16 kHz and the
// sound level (RMS) is printed to the Serial Monitor about 10 times a second.
// Talk while holding the button: the numbers should jump. Release: it stops.
// Uses the PDM library that comes with the Seeed nRF52 mbed-enabled core.

#include <PDM.h>

const int BUTTON_PIN = D1;
const int SAMPLE_RATE = 16000;

short sampleBuffer[512];
volatile int samplesRead = 0;

void onPDMdata() {
  int bytes = PDM.available();
  PDM.read(sampleBuffer, bytes);
  samplesRead = bytes / 2;
}

void setLed(int pin, bool on) { digitalWrite(pin, on ? LOW : HIGH); }  // active-low LEDs

void setup() {
  pinMode(BUTTON_PIN, INPUT_PULLUP);
  pinMode(LEDR, OUTPUT); pinMode(LEDB, OUTPUT);
  setLed(LEDR, false); setLed(LEDB, false);
  Serial.begin(115200);

  PDM.onReceive(onPDMdata);
  PDM.setGain(30);
  if (!PDM.begin(1, SAMPLE_RATE)) {   // 1 channel (mono), 16 kHz
    Serial.println("Mic failed to start");
    while (true) { setLed(LEDR, true); delay(200); setLed(LEDR, false); delay(200); }
  }
  Serial.println("Hold the button and talk");
}

void loop() {
  static bool wasPressed = false;
  static unsigned long lastPrint = 0;
  static double sumSquares = 0;
  static long count = 0;

  bool pressed = digitalRead(BUTTON_PIN) == LOW;
  setLed(LEDB, pressed);

  if (samplesRead) {
    if (pressed) {
      for (int i = 0; i < samplesRead; i++) { sumSquares += (double)sampleBuffer[i] * sampleBuffer[i]; count++; }
    }
    samplesRead = 0;
  }

  if (pressed && !wasPressed) Serial.println("--- recording ---");
  if (!pressed && wasPressed) Serial.println("--- stopped ---");
  wasPressed = pressed;

  if (pressed && millis() - lastPrint >= 100 && count > 0) {
    int level = (int)sqrt(sumSquares / count);
    Serial.print("level ");
    Serial.print(level);
    Serial.print("  ");
    for (int i = 0; i < min(level / 50, 60); i++) Serial.print('#');  // simple bar
    Serial.println();
    sumSquares = 0; count = 0; lastPrint = millis();
  }
}
