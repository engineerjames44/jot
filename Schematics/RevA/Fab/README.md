# Jot Rev A: fabrication files

Generated 16 October 2026 from `KiCad/Jot_RevA/Jot_RevA.kicad_pcb` (KiCad 10). Regenerate them whenever the
board changes; these files are only valid for the board they were plotted from.

| File | What it is |
|---|---|
| `Jot_RevA_Gerbers.zip` | Upload to JLCPCB. 11 Gerber layers (4 copper, 2 mask, 2 silkscreen, 2 paste, outline) and 2 Excellon drill files |
| `gerbers/` | The same files unzipped, plus the drill maps (PDF) and the Gerber job file |
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

## Still to make for assembly

The JLCPCB parts list (`../BOM/Jot_RevA_JLCPCB_BOM.csv`) is ready. The placement file (CPL) still has to be
exported, and its part rotations checked in JLCPCB's preview. J2 (battery wires) is not fitted and is left out
of both.
