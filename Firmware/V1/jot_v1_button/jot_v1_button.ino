// Jot V1, step 3: button test on the XIAO nRF52840 Sense.
// Button between D1 and GND (one top leg, one bottom leg). No resistor:
// the chip's internal pull-up holds D1 HIGH, pressing pulls it LOW.
// While the button is held, the XIAO's built-in LED lights up blue.

const int BUTTON_PIN = D1;

void setup() {
  pinMode(BUTTON_PIN, INPUT_PULLUP);
  pinMode(LEDB, OUTPUT);
  digitalWrite(LEDB, HIGH);  // the XIAO's LEDs are active-low: HIGH = off

  Serial.begin(115200);
}

void loop() {
  bool pressed = digitalRead(BUTTON_PIN) == LOW;
  digitalWrite(LEDB, pressed ? LOW : HIGH);

  static bool wasPressed = false;
  if (pressed != wasPressed) {
    Serial.println(pressed ? "pressed" : "released");
    wasPressed = pressed;
  }
  delay(10);  // also smooths out button bounce
}
