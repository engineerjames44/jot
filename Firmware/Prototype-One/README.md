# Jot Prototype One

Breadboard prototype of Jot: a Seeed XIAO nRF52840 Sense, a 350 mAh LiPo on the
BAT pads, and a push button from D1 to GND. It proves the full loop before the
Rev A board: hold the button, speak, let go, and the iPhone app transcribes and
sorts what you said.

## Sketches

| Sketch | Board package | What it does |
|---|---|---|
| `jot_proto1_bluefruit` | **Seeed nRF52 Boards** (not mbed) | **Use this one.** Streams audio over BLE while the button is held; the phone asks again for any missed packets. Battery and charging status. |
| `jot_proto1_clip` | Seeed nRF52 mbed-enabled Boards | Same protocol on ArduinoBLE. Kept for reference: it dropped packets and connections. |
| `jot_proto1_mic` | mbed | Microphone level check. |
| `jot_proto1_ble` | mbed | Button over BLE (first BLE test). |
| `jot_proto1_button` | mbed | Button and LED test. |

The BLE service, characteristics and packet format are documented at the top of
`jot_proto1_bluefruit.ino`. The app side is in `Jot/Device/`.
