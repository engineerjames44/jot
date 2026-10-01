# Jot branding

The mark is a lowercase **j** in a heavy, rounded stroke whose dot is the
signal-orange orb (`#FF6B35`), the same orb as the record button. It's flat
apart from a soft glow on the orb.

| Dark (default) | Light | Tinted (approx.) | Clear (approx.) |
| --- | --- | --- | --- |
| ![](AppIcon/previews/dark.png) | ![](AppIcon/previews/light.png) | ![](AppIcon/previews/tinted.png) | ![](AppIcon/previews/clear.png) |

The tinted and clear previews only approximate what iOS renders. Use Icon
Composer's previews for the real thing.

## Files

```
AppIcon/
  dark/   1-background.svg  2-j.svg  3-orb.svg  3-orb-solid.svg
  light/  1-background.svg  2-j.svg  3-orb.svg  3-orb-solid.svg
  mono/                     2-j.svg  3-orb.svg  3-orb-solid.svg   (for Tinted and Clear)
  previews/  dark.png light.png tinted.png clear.png
tools/
  make_icon_layers.py   regenerates every SVG from one set of geometry
  render_icon.swift     renders the PNG previews and the fallback app icon
```

Every SVG is a 1024×1024 canvas with the art in place, so the layers line up
when stacked. `3-orb-solid.svg` is the orb without its baked-in glow. Try it if
the Liquid Glass lighting looks better on its own.

To regenerate after a geometry or color change (from the repo root):

```bash
python3 Branding/tools/make_icon_layers.py
```

```bash
swift Branding/tools/render_icon.swift
```

## Assembling the icon in Icon Composer

Icon Composer ships with Xcode 26 and later (**Xcode › Open Developer Tool ›
Icon Composer**). Labels can shift between versions, but the steps are the same.

1. **New document.** Choose iOS (add other platforms later if you want).
2. **Background.** Select the icon itself (the top item in the sidebar). In the
   inspector, set **Fill** to a solid color `#0E0E10`. A fill lets the system
   light the background properly. Alternatively, drag in
   `dark/1-background.svg` as the bottom layer.
3. **Add the j.** Drag `dark/2-j.svg` onto the canvas. It arrives in its own
   group.
4. **Add the orb.** Drag `dark/3-orb.svg` in as a **separate group above the
   j**. Separate groups give each its own depth and glass.
5. **Liquid Glass:**
   - **Orb group:** turn Liquid Glass on, keep translucency off so the orange
     stays vivid, and use a **chromatic** shadow so it casts a warm glow.
   - **j group:** turn Liquid Glass on with low translucency and a **neutral**
     shadow.
   - If the specular highlight on the orb fights the baked-in glow, swap in
     `3-orb-solid.svg`.
6. **Appearances.** Use the appearance switcher under the canvas. For each
   appearance, select a layer and override its fill or opacity:

   | Appearance | Background | j | Orb |
   | --- | --- | --- | --- |
   | **Default** | `#0E0E10` | `#F5F5F7` | `#FF6B35` |
   | **Dark** | `#0E0E10` | `#F5F5F7` | `#FF6B35` |
   | **Clear / Tinted** (mono) | system | white, 60% opacity | white, 100% |

   iOS shows **Default** on light home screens and **Dark** on dark ones. Using
   the dark design for both keeps Jot dark-first everywhere, as specified. If
   you'd rather follow the system, give Default the light colors (background
   `#FFFFFF`, j `#0E0E10`, orb `#FF6B35`), or build it from the `light/`
   layers.

   For Clear and Tinted, the orb stays solid and the j steps back to 60%, so the
   orb is the recognizable element. The `mono/` layers already have these
   values if you prefer swapping images to overriding fills.
7. **Check small sizes.** Preview the home screen, Spotlight, and Settings sizes.
   The j and orb fill about 60% of the canvas, so they should read clearly even
   at the smallest size.
8. **Save into the project** as `AppIcon.icon` inside the `Jot/` folder. The
   folder is synchronized, so Xcode picks it up without any manual adding.
9. **Retire the fallback.** Delete `Jot/Assets.xcassets/AppIcon.appiconset`,
   the flat PNG icon used until now. The target's App Icon setting is already
   `AppIcon`, so it resolves to the new `.icon` file. Build and check the home
   screen.

## Wordmark

In the app the wordmark is live text, not an image: "jot" in SF Pro Rounded
Heavy, using a dotless j (U+0237) with `BrandOrb` placed where the dot goes.
See `Wordmark` in `Jot/DesignSystem/Brand.swift`. It appears on the onboarding
screens and at the top of Settings.

## Launch

The launch screen (`Config/Info.plist` → `UILaunchScreen`) is the orb alone,
centered on `#0E0E10`. The orb image is `LaunchOrb.svg` in the asset catalog.
After launch, `LaunchHandoff` takes over from that exact orb: it pulses once,
then shrinks and glides into the record button while the background fades.
With Reduce Motion on, it simply fades.
