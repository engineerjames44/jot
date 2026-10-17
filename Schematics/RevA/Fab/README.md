# Jot Rev A: fabrication files

Generated 16 October 2026 from `KiCad/Jot_RevA/Jot_RevA.kicad_pcb` (KiCad 10). Regenerate them whenever the
board changes; these files are only valid for the board they were plotted from.

| File | What it is |
|---|---|
| `Jot_RevA_Gerbers.zip` | Upload to JLCPCB. 11 Gerber layers (4 copper, 2 mask, 2 silkscreen, 2 paste, outline) and 2 Excellon drill files |
| `gerbers/` | The same files unzipped, plus the drill maps (PDF) and the Gerber job file |
| `assembly/` | JLCPCB assembly files: parts list (BOM) and placement file (CPL), see below |
| `review/` | Package for the Raytac antenna layout review: the Gerber zip, one PDF page per copper layer, two renders |
| `drc.rpt` | Design-rule check of the plotted board: 0 errors, 0 unconnected pads, 3 library-version warnings |

## Board

4 layers, 1.0 mm FR-4, 37 × 60 mm plus a 12 × 2.6 mm tab under the USB-C socket (37 × 62.6 mm overall), 1 oz copper. Stack-up: top signals, solid ground, 3.3 V and battery power,
bottom signals. Vias 0.3 mm drill / 0.6 mm pad, tented. Design rules 0.15 mm minimum track and space; the
narrowest track on the board is 0.2 mm, power tracks 0.5 mm.

## Export settings

Following JLCPCB's KiCad 9 guide:

- **Gerbers:** Protel filename extensions, X2 format with netlist attributes, 4.6 mm coordinates, zones checked
  and refilled before plotting.
- **Drill:** Excellon, millimetres, decimal zeros, absolute origin, alternate drill mode for oval holes,
  plated and non-plated holes in separate files. Expected counts: 182 plated holes and 10 non-plated.

Before ordering, check the zip in JLCPCB's online Gerber viewer.

## Assembly (JLCPCB)

`assembly/` holds the two files JLCPCB's PCBA order asks for:

| File | What it is |
|---|---|
| `Jot_RevA_BOM_JLCPCB.csv` | Comment, Designator, Footprint, LCSC Part #. 34 lines, 65 parts, all on the top side |
| `Jot_RevA_CPL_JLCPCB.csv` | Designator, Mid X, Mid Y, Layer, Rotation for the same 65 parts, in mm, same origin as the Gerbers |

Not assembled (left out of both files on purpose): J2 battery wires, AE1 NFC antenna wires and TP1/TP2 motor
pads (all hand-soldered), U3 second mic, C18/C19 NFC tuning pads (not fitted), TP3-TP9 test pads and H1-H4
mounting holes (copper only).

U1 (Raytac module, C5118826) and U8 (DRV2605L, C527464) come from the pre-ordered parts in the JLCPCB account.
Check both show as matched to that stock, not as new purchases.

### Ordering steps

1. Upload `Jot_RevA_Gerbers.zip`: 4 layers, 1.0 mm, 5 boards. Check the viewer shows 37 × 62.6 mm.
2. Turn on PCB Assembly: **Standard** (U7, the LIS2DW12 accelerometer, is Standard-only: LGA, X-ray inspection), top side, all 5 boards.
3. Upload the BOM and CPL. Confirm every line matched its LCSC part.
4. In the placement preview, check every polarised part against the table below. JLCPCB's part models don't
   always use KiCad's zero rotation (SOT-23, TSSOP, DFN, WSON and LGA parts are the usual ones to come out 90 or
   180 degrees off). If a pin-1 dot is in the wrong corner, rotate that part in the preview. The KiCad file is
   correct for the board; only JLCPCB's model is turned.

### Pin 1 on the board (top view, board as in the renders: module at the top)

| Ref | Part | Footprint | KiCad rotation | Pin 1 | Check |
|---|---|---|---|---|---|
| BZ1 | MLT-5020 | BUZ-SMD_L5.0-W5.5-P4.60 | 0 | bottom-left | + terminal |
| D1 | KT-0603R | LED_0603_1608Metric | 0 | left | cathode |
| D2 | TJ-S1615SW6TGLCCYRGB-A5 | LED_RGB_TOGIALED_1615_1.6x1.5mm | 180 | bottom-left | common anode |
| D3 | NCD0603G3 | LED_0603_1608Metric | 0 | left | cathode |
| D4 | 1N4148W | D_SOD-123 | 0 | left | cathode (bar) |
| D5 | SMF5.0A | D_SOD-123F | 90 | bottom | cathode (bar), towards USB power |
| J1 | TYPE-C-31-M-12 | USB_C_Receptacle_HRO_TYPE-C-31-M-12 | 0 | top-left | symmetrical; check it sits on the tab |
| Q1 | AO3400A | SOT-23 | 0 | top-left |  |
| Q2 | AO3401A | SOT-23 | 0 | top-left |  |
| Q3 | AO3400A | SOT-23 | 0 | top-left |  |
| Q4 | AO3400A | SOT-23 | 0 | top-left |  |
| Q5 | AO3400A | SOT-23 | 0 | top-left |  |
| Q6 | AO3401A | SOT-23 | 0 | top-left |  |
| Q7 | AO3400A | SOT-23 | 0 | top-left |  |
| Q8 | AO3400A | SOT-23 | 0 | top-left |  |
| SW1 | TS-1010-C-A | KEY-SMD_TX-1010-X-X | 270 | top-left | plunger must point right, out over the board edge towards the side button |
| U1 | MDBT50Q-1MV2 | Raytac_MDBT50Q | 0 | top-left | antenna end at the top board edge |
| U2 | MMICT3902-00-012 | Knowles_LGA-5_3.5x2.65mm | 180 | bottom-right |  |
| U4 | W25Q256JVEIQ | WSON-8-1EP_8x6mm_P1.27mm_EP3.4x4.3mm | 0 | top-left |  |
| U5 | MCP73831T-2ACI/OT | SOT-23-5 | 0 | top-left |  |
| U6 | MAX17048G+T10 | DFN-8-1EP_2x2mm_P0.5mm_EP0.9x1.3mm | 0 | top-left |  |
| U7 | LIS2DW12TR | LGA-12_2x2mm_P0.5mm | 0 | top-left |  |
| U8 | DRV2605LDGSR | TSSOP-10_3x3mm_P0.5mm | 0 | top-left |  |
| U9 | TPS7A0233PDBVR | SOT-23-5 | 0 | top-left |  |
| U10 | USBLC6-2SC6 | SOT-23-6 | 0 | top-left |  |
| Y1 | SC-32S 32.768kHz 20PPM 12.5pF | Crystal_SMD_3215-2Pin_3.2x1.5mm | 0 | right | not polarised; either way works |
