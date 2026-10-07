// Jot Prototype One, step 4: Bluetooth button on the XIAO nRF52840 Sense.
// Advertises as "Jot". The iPhone subscribes to the button characteristic and
// gets 1 when the button is pressed and 0 when it's released.
// Needs the ArduinoBLE library (Library Manager).
//
// Jot BLE service (keep these IDs; the iPhone app will use them):
//   Service           a5bc1576-7c64-4efe-9c40-2b39fdf53bed
//   Button  (notify)  15619899-b8cd-4254-97ff-0c757fa68b3d   uint8: 1 pressed, 0 released
//   Audio   (notify)  18d71983-6ed1-441e-bdd3-80fe9e1b1529   reserved for step 5

#include <ArduinoBLE.h>

const int BUTTON_PIN = D1;

BLEService jotService("a5bc1576-7c64-4efe-9c40-2b39fdf53bed");
BLEByteCharacteristic buttonChar("15619899-b8cd-4254-97ff-0c757fa68b3d", BLERead | BLENotify);

void setLed(int pin, bool on) { digitalWrite(pin, on ? LOW : HIGH); }  // XIAO LEDs are active-low

void setup() {
  pinMode(BUTTON_PIN, INPUT_PULLUP);
  pinMode(LEDR, OUTPUT); pinMode(LEDG, OUTPUT); pinMode(LEDB, OUTPUT);
  setLed(LEDR, false); setLed(LEDG, false); setLed(LEDB, false);
  Serial.begin(115200);

  if (!BLE.begin()) {
    Serial.println("BLE failed to start");
    while (true) { setLed(LEDR, true); delay(200); setLed(LEDR, false); delay(200); }  // red blink = BLE error
  }
  BLE.setLocalName("Jot");
  BLE.setDeviceName("Jot");
  BLE.setAdvertisedService(jotService);
  jotService.addCharacteristic(buttonChar);
  BLE.addService(jotService);
  buttonChar.writeValue(0);
  BLE.advertise();
  Serial.println("Advertising as Jot");
}

void loop() {
  BLEDevice central = BLE.central();
  setLed(LEDG, central && central.connected());  // green = phone connected

  bool pressed = digitalRead(BUTTON_PIN) == LOW;
  setLed(LEDB, pressed);                          // blue = button held

  static bool wasPressed = false;
  if (pressed != wasPressed) {
    wasPressed = pressed;
    buttonChar.writeValue(pressed ? 1 : 0);       // sends a notification if the phone subscribed
    Serial.println(pressed ? "pressed" : "released");
  }
  BLE.poll();
  delay(10);
}
