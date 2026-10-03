# Jot Rev A

First custom PCB: handheld push-to-talk voice capture with BLE sync to the iPhone app.
Architecture: [JOT-HW-001](Architecture/JOT-HW-001_Hardware_Architecture.pdf).

| Folder | What goes there |
| --- | --- |
| `Architecture/` | JOT-HW-001 and other design documents (pin map, power budget) |
| `Datasheets/` | Part datasheets, grouped by block from JOT-HW-001 section 4 |
| `KiCad/` | The KiCad project: schematic, PCB, project-local symbols and footprints |
| `BOM/` | Bill of materials exported from KiCad, with LCSC part numbers |
| `Fabrication/` | Gerbers, drill files, and assembly files sent to the board house |

## Datasheets by block

| Folder | Parts |
| --- | --- |
| `Power/` | USB-C connector and ESD, BQ25101 charger, TPS7A02 LDO, MAX17048, JST-PH, battery |
| `MCU/` | Raytac MDBT50Q-1MV2, nRF52840 Product Specification, 32.768 kHz crystal |
| `Audio/` | TDK T3902 PDM microphone, AO3401A mic power switch |
| `Storage/` | 128 MB QSPI NOR flash |
| `Sensors/` | LIS2DW12 accelerometer, DRV2605L haptic driver, LRA |
| `UI/` | Button, RGB LED, Rec LED, charge LED, buzzer, AO3400A, 1N4148W |
| `NFC/` | NFC antenna design notes and tuning references |
| `Passives/` | Samsung CL05/CL10 capacitor and UNI-ROYAL resistor series datasheets |
