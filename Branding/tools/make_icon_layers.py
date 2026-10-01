#!/usr/bin/env python3
"""Generates Jot's app icon layers as 1024x1024 SVGs, one folder per appearance.

Run from the repo root:  python3 Branding/tools/make_icon_layers.py

Geometry lives here once, so every variant (and the PNG renderer in
render_icon.swift, which mirrors these numbers) stays in sync.
"""
from pathlib import Path

SIZE = 1024
# The j and orb fill about 60% of the canvas height, centered.
STROKE = 136               # j stroke width (heavy, rounded caps)
R = STROKE / 2
ORB_R = 88                 # a bit larger than a normal dot (which would be ~R)
TOP, BOTTOM = 202, 822     # vertical extent of the mark (orb top .. hook bottom)
ORB_CY = TOP + ORB_R
GAP = 34
STEM_TOP = ORB_CY + ORB_R + GAP + R
HOOK_Y = BOTTOM - R
STEM_X = 581               # chosen so the mark's bounding box is centered
J_PATH = (f"M {STEM_X} {STEM_TOP} V 625 "
          f"C {STEM_X} 708, {STEM_X - 52} {HOOK_Y}, {STEM_X - 138} {HOOK_Y}")

ACCENT = "#FF6B35"
VARIANTS = {
    # name: (background, j color, orb color, orb glow opacity, j opacity)
    "dark":  ("#0E0E10", "#F5F5F7", ACCENT, 0.55, 1.0),
    "light": ("#FFFFFF", "#0E0E10", ACCENT, 0.35, 1.0),
    # Tinted and Clear: iOS supplies the color, so layers are grayscale.
    # The orb stays solid white and the j steps back, so the orb still reads.
    "mono":  (None, "#FFFFFF", "#FFFFFF", 0.35, 0.6),
}


def svg(body: str) -> str:
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{SIZE}" height="{SIZE}" '
            f'viewBox="0 0 {SIZE} {SIZE}">\n{body}\n</svg>\n')


def background(color: str) -> str:
    return svg(f'  <rect width="{SIZE}" height="{SIZE}" fill="{color}"/>')


def j_layer(color: str, opacity: float) -> str:
    return svg(f'  <path d="{J_PATH}" fill="none" stroke="{color}" stroke-opacity="{opacity}" '
               f'stroke-width="{STROKE}" stroke-linecap="round" stroke-linejoin="round"/>')


def orb_layer(color: str, glow: float) -> str:
    return svg(f'''  <defs>
    <radialGradient id="glow" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0.45" stop-color="{color}" stop-opacity="{glow}"/>
      <stop offset="1" stop-color="{color}" stop-opacity="0"/>
    </radialGradient>
  </defs>
  <circle cx="{STEM_X}" cy="{ORB_CY}" r="{ORB_R * 2.1:.0f}" fill="url(#glow)"/>
  <circle cx="{STEM_X}" cy="{ORB_CY}" r="{ORB_R}" fill="{color}"/>''')


def main() -> None:
    out = Path(__file__).resolve().parent.parent / "AppIcon"
    for name, (bg, j_color, orb_color, glow, j_opacity) in VARIANTS.items():
        folder = out / name
        folder.mkdir(parents=True, exist_ok=True)
        if bg:
            (folder / "1-background.svg").write_text(background(bg))
        (folder / "2-j.svg").write_text(j_layer(j_color, j_opacity))
        (folder / "3-orb.svg").write_text(orb_layer(orb_color, glow))
        # Same orb without the baked-in glow, if Liquid Glass lighting looks better alone.
        (folder / "3-orb-solid.svg").write_text(orb_layer(orb_color, 0))
        print("wrote", folder.relative_to(out.parent.parent))


if __name__ == "__main__":
    main()
