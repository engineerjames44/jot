# Jot case v1: Fusion script that builds the case from the concept render.
#
# Run it in Fusion: Utilities > Scripts and Add-Ins (Shift+S) > "+" > pick this JotCase folder > Run.
# It opens a new design with: front shell, back shell, orange grooved button, orange logo dot, and grey
# reference blocks (PCB, its tallest parts, battery) so you can check that everything fits.
#
# Every size is in the CFG table below, in millimetres. Change a number and run it again: it makes a
# fresh design each time. Measure the real parts and update CFG before trusting any fit.
#
# Axes: X = width (left to right), Y = length (bottom to top), Z = thickness (back = 0, front = T).
# The front (Z = T) carries the three dots and the "jot" logo; the button is on the right (+X) edge;
# USB-C is on the bottom (-Y) edge; the two mic holes are on the top (+Y) edge, left of centre.
#
# Assembly: battery into the back shell, PCB onto the four standoffs, button into its slot from inside the
# front shell, front shell on (the lip on the back shell locates it), then four M2 x 10 self-tapping screws
# from the back: through the standoffs and the PCB into the bosses inside the front shell. They clamp the
# board and hold the two shells together.

import traceback

import adsk.core
import adsk.fusion

CFG = {
    # Outer shape (render proportions: about 1.6 : 1, big corner radius)
    "length": 68.0,          # Y
    "width": 42.0,           # X
    "thickness": 12.8,       # Z: stacked layout (battery under the PCB); stack-up at the bottom
    "corner_radius": 7.0,    # plan-view corner radius
    "edge_radius": 2.0,      # rounding of the front and back edges
    "wall": 1.2,             # shell wall thickness
    "split_z": 7.0,          # where the front and back shells meet (from the back face)

    # Lip: a thin ring on the back shell that slides inside the front shell to line the halves up
    "lip_height": 0.7,
    "lip_thickness": 0.6,
    "lip_clearance": 0.15,

    # Front details
    "dot_y": 3.4,            # three status dots, 45% down from the top
    "dot_pitch": 4.1,
    "dot_diameter": 1.2,
    "logo_y": -27.2,         # "jot" logo, 90% down from the top
    "logo_height": 3.5,
    "logo_depth": 0.3,
    "logo_dot_diameter": 0.8,  # orange dot over the j: pocket in the front shell plus a separate insert
    "logo_dot_depth": 0.5,
    "logo_dot_dx": 0.0,      # nudge the dot right (+) or left (-), mm
    "logo_dot_dy": 0.0,      # nudge the dot up (+) or down (-), mm

    # Side button (right edge, about a quarter of the way down)
    "button_y": 15.0,        # centre
    "button_length": 6.5,    # along Y
    "button_height": 3.0,    # along Z
    "button_z": 9.3,         # centre: about 1.2 mm above the PCB top for the TS-1010 actuator
    "button_proud": 0.8,     # how far the cap sticks out of the side
    "button_clearance": 0.2,
    "button_flange": 1.0,    # inside flange, each end along Y, stops the button falling out
    "button_flange_thickness": 0.9,  # reaches SW1's plunger tip (PCB X 118.82) with about 0.08 mm to spare
    "groove_count": 3,       # grooves across the button face
    "groove_width": 0.4,
    "groove_depth": 0.3,
    "groove_pitch": 1.4,

    # USB-C (bottom edge), stadium-shaped opening for the plug overmould
    "usb_width": 9.6,
    "usb_height": 3.6,
    "usb_z": 9.7,            # receptacle centre, about 1.6 mm above the PCB top

    # Mic hole (top edge). The T3902 is bottom-port: it hears through a hole in the PCB, from underneath,
    # so the case hole sits below the board (the battery doesn't reach the top end). A sealed channel from
    # here to the mic's PCB hole is added once layout fixes the mic position.
    # Layout (8 Oct): U2 and U3 sit top-left, sound ports at x -11.5 / -7.7, y 21.3.
    "mic_x": (-11.5, -7.7),
    "mic_diameter": 1.0,
    "mic_z": 5.5,

    # Buzzer (BZ1 at x 14.5, y -0.5 on the PCB top): a slot in the right wall, below the button
    "buzzer_y": -0.5,
    "buzzer_slot_length": 5.0,
    "buzzer_slot_height": 1.0,
    "buzzer_slot_z": 9.6,

    # The PCB has a tab under the USB-C socket (to y -32.6), so the lip has a gap there
    "usb_lip_gap": 14.0,

    # NFC: Molex 146236-0101 flex antenna (15 x 25 mm + tab, 0.27 mm) stuck in a pocket in the back
    # shell's floor, ferrite towards the battery, tab end towards the top so its wires clear the battery
    # and run to the AE1 holes (x 17, y 18.8 / 22.4). The top battery rib gets a notch for the tab.
    "nfc_pocket_width": 15.5,
    "nfc_pocket_length": 31.0,
    "nfc_pocket_depth": 0.35,
    "nfc_pocket_y": 0.0,

    # Reference blocks (not printed): Rev A board and the Adafruit 1578 cell (PKCELL LP503035, 500 mAh).
    # Manufacturer drawing: 30 +/-0.1 x 35 +/-0.1 x 5.0 +/-0.1 mm including the protection board; sized
    # here at the top of the tolerance. Leads (100 mm) exit from one 30 mm end, at the protection board.
    "pcb_width": 37.0,
    "pcb_length": 60.0,
    "pcb_thickness": 1.0,
    "pcb_z": 7.1,            # bottom face of the PCB
    "component_height": 3.2, # tallest top-side part (USB-C receptacle ~3.2 mm, module 2.1 mm)
    "battery_width": 30.1,
    "battery_length": 35.1,
    "battery_thickness": 5.3,  # 5.1 mm max + 0.2 mm room for swelling (plus 0.3 mm gap to the PCB)
    "battery_y": -6.5,       # centre: clears the bottom screw posts by 1.3 mm
    "battery_z": 1.5,        # bottom face (back wall 1.2 + clearance 0.3)

    # Screws: four M2 x 10 self-tapping screws from the back, through standoffs and PCB into front bosses
    "standoff_inset": 2.5,   # hole centre from the PCB edge (the PCB gets 2.2 mm holes here at layout)
    "standoff_diameter": 4.5,
    "boss_diameter": 4.5,    # posts inside the front shell, resting on the PCB
    "boss_gap": 0.1,         # between the boss and the PCB top
    "screw_clearance": 2.3,  # through the back shell and standoffs
    "screw_pilot": 1.6,      # in the front bosses, for the screw to cut its thread
    "counterbore_diameter": 4.2,  # recess for the screw head in the back face
    "counterbore_depth": 2.0,
    "front_skin": 0.8,       # plastic left between the pilot hole and the front face
    "pcb_hole": 2.2,         # M2 clearance hole in the PCB (shown in the REF PCB block)

    # Back engraving: a numbered limited run
    "unit_total": 5,
    "back_line1": "JOT \u00b7 {n}/{total}",
    "back_line2": "jamescronin.dev",
    "back_line1_height": 1.6,
    "back_line2_height": 1.4,
    "back_line1_y": 1.2,     # centre of each line: the pair sits in the middle of the back
    "back_line2_y": -1.2,
    "back_depth": 0.3,

    # Battery ribs: low walls in the back shell that stop the cell sliding around
    "rib_height": 1.5,
    "rib_width": 0.8,
    "battery_clearance": 0.5,
}

# Save pictures of the finished model into ../renders (front, back, side, three-quarter view).
SAVE_IMAGES = True
# Export print-ready STL files into ../stl: front shell, button, logo dot, and one back shell per unit
# (numbered 1/5 to 5/5).
EXPORT_STL = True

MM = 0.1  # the Fusion API works in centimetres


def vi(mm):
    return adsk.core.ValueInput.createByReal(mm * MM)


def p3(x, y, z):
    return adsk.core.Point3D.create(x * MM, y * MM, z * MM)


def rounded_rect(sketch, w, l, r):
    lines = sketch.sketchCurves.sketchLines.addTwoPointRectangle(p3(-w / 2, -l / 2, 0), p3(w / 2, l / 2, 0))
    arcs = sketch.sketchCurves.sketchArcs
    for i in range(4):
        a, b = lines.item(i), lines.item((i + 1) % 4)
        arcs.addFillet(a, a.endSketchPoint.geometry, b, b.startSketchPoint.geometry, r * MM)


def run(context):
    app = adsk.core.Application.get()
    ui = app.userInterface
    try:
        app.documents.add(adsk.core.DocumentTypes.FusionDesignDocumentType)
        design = adsk.fusion.Design.cast(app.activeProduct)
        design.designType = adsk.fusion.DesignTypes.ParametricDesignType
        root = design.rootComponent
        feats = root.features
        c = CFG
        L, W, T = c["length"], c["width"], c["thickness"]
        wall = c["wall"]

        # Record the main sizes as user parameters so they show in Modify > Change Parameters.
        for name in ("length", "width", "thickness", "corner_radius", "edge_radius", "wall"):
            design.userParameters.add("jot_" + name, vi(c[name]), "mm", "Jot case (set in the script)")

        # Helpers: temporary solids added through a base feature, then used to join or cut.
        tbm = adsk.fusion.TemporaryBRepManager.get()

        def box(x0, x1, y0, y1, z0, z1):
            obb = adsk.core.OrientedBoundingBox3D.create(
                p3((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2),
                adsk.core.Vector3D.create(1, 0, 0),
                adsk.core.Vector3D.create(0, 1, 0),
                abs(x1 - x0) * MM, abs(y1 - y0) * MM, abs(z1 - z0) * MM,
            )
            return tbm.createBox(obb)

        def cyl(a, b, d):
            return tbm.createCylinderOrCone(p3(*a), d / 2 * MM, p3(*b), d / 2 * MM)

        def add_bodies(temps, name):
            # Bodies made inside a base feature must be fetched again once it is finished.
            base = feats.baseFeatures.add()
            base.startEdit()
            for t in temps:
                root.bRepBodies.add(t, base)
            base.finishEdit()
            base.name = name
            return [base.bodies.item(i) for i in range(base.bodies.count)]

        def combine(target, tools, op, keep=False):
            coll = adsk.core.ObjectCollection.create()
            for tb in tools:
                # A tool that misses the target makes the whole combine fail, so skip those.
                if tb.isValid and tb.boundingBox.intersects(target.boundingBox):
                    coll.add(tb)
            if coll.count == 0:
                return
            cin = feats.combineFeatures.createInput(target, coll)
            cin.operation = op
            cin.isKeepToolBodies = keep
            feats.combineFeatures.add(cin)
            if keep:
                for tb in tools:
                    if tb.isValid:
                        tb.isLightBulbOn = False

        JOIN = adsk.fusion.FeatureOperations.JoinFeatureOperation
        CUT = adsk.fusion.FeatureOperations.CutFeatureOperation

        # 1. Rounded-rectangle outline, extruded to the full thickness.
        sk = root.sketches.add(root.xYConstructionPlane)
        sk.name = "Outline"
        rounded_rect(sk, W, L, c["corner_radius"])
        ext = feats.extrudeFeatures.addSimple(sk.profiles.item(0), vi(T), adsk.fusion.FeatureOperations.NewBodyFeatureOperation)
        body = ext.bodies.item(0)

        # 2. Round the front and back edges.
        edges = adsk.core.ObjectCollection.create()
        for face in (ext.startFaces.item(0), ext.endFaces.item(0)):
            for e in face.edges:
                edges.add(e)
        finput = feats.filletFeatures.createInput()
        try:
            finput.edgeSetInputs.addConstantRadiusEdgeSet(edges, vi(c["edge_radius"]), True)
        except AttributeError:
            finput.addConstantRadiusEdgeSet(edges, vi(c["edge_radius"]), True)
        feats.filletFeatures.add(finput)

        # 3. Split into front and back shells.
        planes = root.constructionPlanes
        pin = planes.createInput()
        pin.setByOffset(root.xYConstructionPlane, vi(c["split_z"]))
        split_plane = planes.add(pin)
        split_plane.name = "Split line"
        feats.splitBodyFeatures.add(feats.splitBodyFeatures.createInput(body, split_plane, True))
        front = back = None
        for b in root.bRepBodies:
            if b.boundingBox.minPoint.z > (c["split_z"] - 0.01) * MM:
                front = b
            else:
                back = b
        front.name = "Front shell"
        back.name = "Back shell"

        # 4. Hollow each shell, leaving it open at the split face.
        for b in (front, back):
            faces = adsk.core.ObjectCollection.create()
            for f in b.faces:
                if isinstance(f.geometry, adsk.core.Plane) and abs(f.pointOnFace.z - c["split_z"] * MM) < 1e-4:
                    faces.add(f)
            sinput = feats.shellFeatures.createInput(faces, False)
            sinput.insideThickness = vi(wall)
            feats.shellFeatures.add(sinput)

        # 5. Lip: a ring that stands up from the back shell and slides just inside the front shell's wall.
        #    A wider ring below the split line ties it into the back shell's wall.
        o_off = wall + c["lip_clearance"]
        i_off = o_off + c["lip_thickness"]

        def ring_profile(name, outer_off, inner_off):
            rsk = root.sketches.add(split_plane)
            rsk.name = name
            rounded_rect(rsk, W - 2 * outer_off, L - 2 * outer_off, c["corner_radius"] - outer_off)
            rounded_rect(rsk, W - 2 * inner_off, L - 2 * inner_off, c["corner_radius"] - inner_off)
            for i in range(rsk.profiles.count):
                if rsk.profiles.item(i).profileLoops.count == 2:
                    return rsk.profiles.item(i)
            return None

        root_ring = ring_profile("Lip root", wall - 0.1, i_off)
        rin = feats.extrudeFeatures.createInput(root_ring, JOIN)
        rin.setDistanceExtent(False, vi(-1.0))
        rin.participantBodies = [back]
        feats.extrudeFeatures.add(rin)

        lip_ring = ring_profile("Lip", o_off, i_off)
        lin = feats.extrudeFeatures.createInput(lip_ring, JOIN)
        lin.startExtent = adsk.fusion.OffsetStartDefinition.create(vi(-0.5))
        lin.setDistanceExtent(False, vi(c["lip_height"] + 0.5))
        lin.participantBodies = [back]
        feats.extrudeFeatures.add(lin)

        # Gap in the lip for the PCB's USB tab (the wall itself is untouched).
        g = c["usb_lip_gap"] / 2
        combine(back, add_bodies([box(-g, g, -L / 2 + wall + 0.05, -L / 2 + wall + 1.3, c["split_z"] - 0.05, c["split_z"] + c["lip_height"] + 0.2)], "USB lip gap"), CUT)

        # 6. Standoffs and battery ribs on the back shell; bosses on the front shell.
        sx = c["pcb_width"] / 2 - c["standoff_inset"]
        sy = c["pcb_length"] / 2 - c["standoff_inset"]
        hole_xy = [(x, y) for x in (-sx, sx) for y in (-sy, sy)]
        pcb_top = c["pcb_z"] + c["pcb_thickness"]

        back_joins = [cyl((x, y, wall - 0.3), (x, y, c["pcb_z"]), c["standoff_diameter"]) for x, y in hole_xy]
        bw, blen, bc, rw = c["battery_width"], c["battery_length"], c["battery_clearance"], c["rib_width"]
        bx0, bx1 = -bw / 2 - bc, bw / 2 + bc
        by0, by1 = c["battery_y"] - blen / 2 - bc, c["battery_y"] + blen / 2 + bc
        rz0, rz1 = wall - 0.3, wall + c["rib_height"]
        side = 0.6 * blen  # side ribs run along the middle of the long edges, clear of the standoffs
        back_joins += [
            box(bx0 - rw, bx0, c["battery_y"] - side / 2, c["battery_y"] + side / 2, rz0, rz1),
            box(bx1, bx1 + rw, c["battery_y"] - side / 2, c["battery_y"] + side / 2, rz0, rz1),
            box(-bw / 3, bw / 3, by0 - rw, by0, rz0, rz1),
            box(-bw / 3, bw / 3, by1, by1 + rw, rz0, rz1),
        ]
        combine(back, add_bodies(back_joins, "Standoffs and ribs"), JOIN)

        # NFC antenna pocket in the back floor, plus a notch in the top rib where the antenna's tab passes.
        nw, nl, nd, ny = c["nfc_pocket_width"], c["nfc_pocket_length"], c["nfc_pocket_depth"], c["nfc_pocket_y"]
        combine(back, add_bodies([
            box(-nw / 2, nw / 2, ny - nl / 2, ny + nl / 2, wall - nd, wall + 0.05),
            box(-nw / 2, nw / 2, by1 - 0.1, by1 + rw + 0.1, wall - nd, rz1 + 0.1),
        ], "NFC pocket"), CUT)

        front_joins = [cyl((x, y, pcb_top + c["boss_gap"]), (x, y, T - wall + 0.3), c["boss_diameter"]) for x, y in hole_xy]
        combine(front, add_bodies(front_joins, "Screw bosses"), JOIN)

        # Screw holes: clearance + head recess through the back, pilot holes up into the front bosses.
        back_cuts = []
        for x, y in hole_xy:
            back_cuts.append(cyl((x, y, -0.5), (x, y, c["pcb_z"] + 0.1), c["screw_clearance"]))
            back_cuts.append(cyl((x, y, -0.5), (x, y, c["counterbore_depth"]), c["counterbore_diameter"]))
        combine(back, add_bodies(back_cuts, "Screw clearance"), CUT)
        pilots = [cyl((x, y, pcb_top - 0.1), (x, y, T - c["front_skin"]), c["screw_pilot"]) for x, y in hole_xy]
        combine(front, add_bodies(pilots, "Screw pilots"), CUT)

        # 7. Openings: dots, button slot, USB-C, mics, buzzer slot.
        tools = []
        for k in (-1, 0, 1):
            x = k * c["dot_pitch"]
            tools.append(cyl((x, c["dot_y"], T - wall - 0.5), (x, c["dot_y"], T + 0.5), c["dot_diameter"]))
        by, bl, bh, bz = c["button_y"], c["button_length"], c["button_height"], c["button_z"]
        tools.append(box(W / 2 - wall - 0.5, W / 2 + 0.5, by - bl / 2, by + bl / 2, bz - bh / 2, bz + bh / 2))
        uw, uh, uz = c["usb_width"], c["usb_height"], c["usb_z"]
        y0, y1 = -L / 2 - 0.5, -L / 2 + wall + 0.5
        tools.append(box(-(uw - uh) / 2, (uw - uh) / 2, y0, y1, uz - uh / 2, uz + uh / 2))
        for s in (-1, 1):
            xe = s * (uw - uh) / 2
            tools.append(cyl((xe, y0, uz), (xe, y1, uz), uh))
        for mx in c["mic_x"]:
            tools.append(cyl((mx, L / 2 - wall - 0.5, c["mic_z"]), (mx, L / 2 + 0.5, c["mic_z"]), c["mic_diameter"]))
        zy, zl, zh, zz = c["buzzer_y"], c["buzzer_slot_length"], c["buzzer_slot_height"], c["buzzer_slot_z"]
        tools.append(box(W / 2 - wall - 0.5, W / 2 + 0.5, zy - zl / 2, zy + zl / 2, zz - zh / 2, zz + zh / 2))
        tool_bodies = add_bodies(tools, "Openings")
        combine(front, tool_bodies, CUT, keep=True)
        combine(back, tool_bodies, CUT, keep=True)

        # 8. Logo: engrave "jot", then a pocket for the orange dot over the j.
        dot_xy = None
        try:
            pin = planes.createInput()
            pin.setByOffset(root.xYConstructionPlane, vi(T))
            front_plane = planes.add(pin)
            front_plane.name = "Front face"
            lsk = root.sketches.add(front_plane)
            lsk.name = "Logo"
            h = c["logo_height"]
            ly = c["logo_y"]

            def text(s, left):
                ti = lsk.sketchTexts.createInput2(s, h * MM)
                ti.setAsMultiLine(
                    p3(left, ly - h, 0), p3(left + 20, ly + h, 0),
                    adsk.core.HorizontalAlignments.LeftHorizontalAlignment,
                    adsk.core.VerticalAlignments.MiddleVerticalAlignment, 0,
                )
                return lsk.sketchTexts.add(ti)

            # Measure, then place "jot" centred; measure "j" alone to find where its dot sits.
            try:
                probe = text("jot", 0)
                bb = probe.boundingBox
                word_w = (bb.maxPoint.x - bb.minPoint.x) / MM
                word_minx = bb.minPoint.x / MM
                probe.deleteMe()
                left = -word_w / 2 - word_minx
                jprobe = text("j", left)
                jb = jprobe.boundingBox
                # Centre of the j's own dot: the top of the glyph, half a stroke in from its right side.
                stroke = 0.13 * h
                dot_xy = (jb.maxPoint.x / MM - stroke / 2, jb.maxPoint.y / MM - stroke / 2)
                jprobe.deleteMe()
            except Exception:
                # Fusion couldn't report the text size: estimate from typical letter widths.
                word_w = 1.35 * h
                left = -word_w / 2
                dot_xy = (left + 0.22 * h, ly + 0.55 * h)
            txt = text("jot", left)

            ein = feats.extrudeFeatures.createInput(txt, CUT)
            ein.setDistanceExtent(False, vi(-c["logo_depth"]))
            ein.participantBodies = [front]
            feats.extrudeFeatures.add(ein)
        except Exception:
            ui.messageBox("The logo step failed; everything else was built.\n\n" + traceback.format_exc())

        if dot_xy is not None:
            dx, dy = dot_xy[0] + c["logo_dot_dx"], dot_xy[1] + c["logo_dot_dy"]
            pocket = cyl((dx, dy, T - c["logo_dot_depth"]), (dx, dy, T + 0.5), c["logo_dot_diameter"])
            combine(front, add_bodies([pocket], "Logo dot pocket"), CUT)

        # 8b. Back engraving, cut into the back shell's outer face (sketched on that face so it reads correctly
        #     from behind). Line 1 carries the unit number; it starts as 1 and the STL export steps through all.
        back_text = None
        try:
            back_face = None
            for f in back.faces:
                if isinstance(f.geometry, adsk.core.Plane) and abs(f.pointOnFace.z) < 1e-4:
                    back_face = f
            bsk = root.sketches.add(back_face)
            bsk.name = "Back engraving"

            def back_line(s, h, y):
                a_ = bsk.modelToSketchSpace(p3(-18, y - h, 0))
                b_ = bsk.modelToSketchSpace(p3(18, y + h, 0))
                lo = adsk.core.Point3D.create(min(a_.x, b_.x), min(a_.y, b_.y), 0)
                hi = adsk.core.Point3D.create(max(a_.x, b_.x), max(a_.y, b_.y), 0)
                ti = bsk.sketchTexts.createInput2(s, h * MM)
                ti.setAsMultiLine(
                    lo, hi,
                    adsk.core.HorizontalAlignments.CenterHorizontalAlignment,
                    adsk.core.VerticalAlignments.MiddleVerticalAlignment, 0,
                )
                return bsk.sketchTexts.add(ti)

            back_text = back_line(c["back_line1"].format(n=1, total=c["unit_total"]), c["back_line1_height"], c["back_line1_y"])
            line2 = back_line(c["back_line2"], c["back_line2_height"], c["back_line2_y"])
            for t in (back_text, line2):
                bin_ = feats.extrudeFeatures.createInput(t, CUT)
                bin_.setDistanceExtent(False, vi(-c["back_depth"]))
                bin_.participantBodies = [back]
                feats.extrudeFeatures.add(bin_)
        except Exception:
            ui.messageBox("The back engraving failed; everything else was built.\n\n" + traceback.format_exc())

        # 9. Button: cap with three grooves on its face and an inside flange; orange logo dot insert.
        cl, pr = c["button_clearance"], c["button_proud"]
        ft, fl = c["button_flange_thickness"], c["button_flange"]
        cap = box(W / 2 - wall, W / 2 + pr, by - bl / 2 + cl, by + bl / 2 - cl, bz - bh / 2 + cl, bz + bh / 2 - cl)
        flange = box(W / 2 - wall - ft, W / 2 - wall, by - bl / 2 - fl, by + bl / 2 + fl, bz - bh / 2 + cl, bz + bh / 2 - cl)
        tbm.booleanOperation(cap, flange, adsk.fusion.BooleanTypes.UnionBooleanType)
        n, gp, gw, gd = int(c["groove_count"]), c["groove_pitch"], c["groove_width"], c["groove_depth"]
        for k in range(n):
            gy = by + (k - (n - 1) / 2) * gp
            groove = box(W / 2 + pr - gd, W / 2 + pr + 0.5, gy - gw / 2, gy + gw / 2, bz - bh, bz + bh)
            tbm.booleanOperation(cap, groove, adsk.fusion.BooleanTypes.DifferenceBooleanType)

        parts = [cap]
        names = ["Button (orange)"]
        if dot_xy is not None:
            parts.append(cyl((dx, dy, T - c["logo_dot_depth"]), (dx, dy, T), c["logo_dot_diameter"] - 0.1))
            names.append("Logo dot (orange)")
        parts += [
            box(-c["pcb_width"] / 2, c["pcb_width"] / 2, -c["pcb_length"] / 2, c["pcb_length"] / 2, c["pcb_z"], pcb_top),
            box(-c["pcb_width"] / 2 + 1, c["pcb_width"] / 2 - 1, -c["pcb_length"] / 2 + 1, c["pcb_length"] / 2 - 1,
                pcb_top, pcb_top + c["component_height"]),
            box(bx0 + bc, bx1 - bc, by0 + bc, by1 - bc, c["battery_z"], c["battery_z"] + c["battery_thickness"]),
        ]
        names += ["REF PCB", "REF tallest parts", "REF Battery Adafruit 1578"]
        made = add_bodies(parts, "Parts")
        for b, nm in zip(made, names):
            b.name = nm
        cap_b = made[0]
        dot_b = made[1] if dot_xy is not None else None
        pcb_b = made[-3]

        # Mounting holes in the reference PCB, to match the standoffs.
        holes = [cyl((x, y, c["pcb_z"] - 0.5), (x, y, pcb_top + 0.5), c["pcb_hole"]) for x, y in hole_xy]
        combine(pcb_b, add_bodies(holes, "PCB holes"), CUT)

        # 10. Colours are left to Fusion's defaults: scripted appearance edits proved unreliable. To colour
        #     parts, drag an appearance onto them (right-click a body > Appearance).

        app.activeViewport.fit()
        exported = ""
        if EXPORT_STL:
            try:
                exported = export_stls(design, c, front, back, cap_b, dot_b, back_text)
            except Exception:
                ui.messageBox("STL export failed:\n\n" + traceback.format_exc())
        saved = ""
        if SAVE_IMAGES:
            try:
                saved = save_views(app, design, c)
            except Exception:
                saved = "\n\nSaving pictures failed:\n" + traceback.format_exc()
        if saved and "failed" in saved:
            ui.messageBox(saved)
        ui.messageBox(
            "Jot case v1 built.\n\nFront and back shells with lip, standoffs, screw bosses and battery ribs; "
            "orange grooved button and logo dot; REF blocks for the PCB, its tallest parts and the battery.\n\n"
            "Check fit with Inspect > Interference. All sizes are in CFG at the top of JotCase.py."
        )
    except Exception:
        if ui:
            ui.messageBox("Jot case script failed:\n\n" + traceback.format_exc())


def export_stls(design, c, front, back, cap_b, dot_b, back_text):
    """Write one STL per printed part, and one back shell per unit number, into ../stl."""
    import os
    out = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "stl")
    os.makedirs(out, exist_ok=True)
    em = design.exportManager

    def stl(body, name):
        opts = em.createSTLExportOptions(body, os.path.join(out, name + ".stl"))
        opts.meshRefinement = adsk.fusion.MeshRefinementSettings.MeshRefinementHigh
        em.execute(opts)

    stl(front, "jot_front_shell")
    stl(cap_b, "jot_button_orange")
    if dot_b is not None:
        stl(dot_b, "jot_logo_dot_orange")
    total = int(c["unit_total"])
    for n in range(1, total + 1):
        if back_text is not None:
            back_text.text = c["back_line1"].format(n=n, total=total)
            design.computeAll()
        stl(back, "jot_back_shell_{}of{}".format(n, total))
    if back_text is not None:  # leave the model showing unit 1
        back_text.text = c["back_line1"].format(n=1, total=total)
        design.computeAll()
    return out


def save_views(app, design, c):
    """Point the camera at the model from four directions and save each view as a PNG."""
    import os
    out = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "renders")
    os.makedirs(out, exist_ok=True)
    # Hide the reference blocks so the pictures show only the case.
    for b in design.rootComponent.bRepBodies:
        if b.name.startswith("REF"):
            b.isLightBulbOn = False
    vp = app.activeViewport
    d = max(c["length"], c["width"]) * 3 * MM
    views = {
        "front": ((0, 0, d), (0, 1, 0)),
        "back": ((0, 0, -d), (0, 1, 0)),
        "side": ((d, 0, c["thickness"] / 2 * MM), (0, 0, 1)),
        "three_quarter": ((d * 0.7, -d * 0.5, d * 0.8), (0, 0, 1)),
    }
    for name, (eye, up) in views.items():
        cam = vp.camera
        cam.target = adsk.core.Point3D.create(0, 0, c["thickness"] / 2 * MM)
        cam.eye = adsk.core.Point3D.create(*eye)
        cam.upVector = adsk.core.Vector3D.create(*up)
        cam.isFitView = True
        vp.camera = cam
        vp.refresh()
        vp.saveAsImageFile(os.path.join(out, "jot_case_" + name + ".png"), 1600, 1200)
    for b in design.rootComponent.bRepBodies:
        if b.name.startswith("REF"):
            b.isLightBulbOn = True
    return out

# Notes:
# - Stack-up, back to front (12.8 mm): wall 1.2, clearance 0.3, Adafruit 1578 cell 5.1 max + 0.2 swelling,
#   clearance 0.3, PCB 1.0, tallest part 3.2 (USB-C receptacle), clearance 0.3, wall 1.2.
#   The first v0 was 16 mm with the 7.8 mm Adafruit 3898 cell and 1.5 mm walls. A mid-mount USB-C would
#   save about 1.1 mm more, but the schematic is locked for Rev A.
# - Battery: Adafruit 1578 (PKCELL LP503035, 500 mAh, protection board, JST-PH with Adafruit polarity).
#   Check its polarity with a meter before the first plug-in. Its leads go at the bottom end: J2 is at
#   the bottom right of the PCB with its opening facing down, so the wires come round the bottom edge.
# - Screws: M2 x 10 self-tapping for plastic, head sits in the 2.0 mm recess in the back.
# - Matched to the Rev A placement (8 Oct): lip gap for the USB tab, button flange thick enough to reach
#   SW1, two mic holes over U2/U3, buzzer slot, NFC antenna pocket. Tune the flange after a test print.
# - Still to add: light pipes behind the dots, sealed sound channels from the mic holes to the mics'
#   PCB ports, a place for the vibration motor.
