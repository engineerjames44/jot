// Renders Jot's icon to PNG with CoreGraphics, mirroring make_icon_layers.py.
//   swift Branding/tools/render_icon.swift
// Writes the 1024 px app icon (opaque, as App Store requires) into the asset
// catalog, plus previews of each appearance into Branding/AppIcon/previews.
import AppKit
import CoreGraphics
import Foundation

let size = 1024
let stroke: CGFloat = 136, r = stroke / 2, orbR: CGFloat = 88
let top: CGFloat = 202, bottom: CGFloat = 822
let orbCY = top + orbR, stemTop = orbCY + orbR + 34 + r, hookY = bottom - r, stemX: CGFloat = 581

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

struct Variant {
    let name: String
    let background: [CGColor]   // one color = flat, two = vertical gradient (for previews)
    let j: CGColor
    let orb: CGColor
    let glow: CGFloat
}

func render(_ v: Variant, to url: URL) {
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    // Flip to SVG-style coordinates (origin top-left).
    ctx.translateBy(x: 0, y: CGFloat(size)); ctx.scaleBy(x: 1, y: -1)

    let full = CGRect(x: 0, y: 0, width: size, height: size)
    if v.background.count == 1 {
        ctx.setFillColor(v.background[0]); ctx.fill(full)
    } else {
        let g = CGGradient(colorsSpace: nil, colors: v.background as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: size), options: [])
    }

    // The j.
    let path = CGMutablePath()
    path.move(to: CGPoint(x: stemX, y: stemTop))
    path.addLine(to: CGPoint(x: stemX, y: 625))
    path.addCurve(to: CGPoint(x: stemX - 138, y: hookY),
                  control1: CGPoint(x: stemX, y: 708), control2: CGPoint(x: stemX - 52, y: hookY))
    ctx.addPath(path)
    ctx.setStrokeColor(v.j); ctx.setLineWidth(stroke); ctx.setLineCap(.round); ctx.setLineJoin(.round)
    ctx.strokePath()

    // The orb's soft glow, then the orb.
    let center = CGPoint(x: stemX, y: orbCY)
    let glow = CGGradient(colorsSpace: nil,
                          colors: [v.orb.copy(alpha: v.glow)!, v.orb.copy(alpha: 0)!] as CFArray,
                          locations: [0.45, 1])!
    ctx.drawRadialGradient(glow, startCenter: center, startRadius: 0, endCenter: center,
                           endRadius: orbR * 2.1, options: [])
    ctx.setFillColor(v.orb)
    ctx.fillEllipse(in: CGRect(x: center.x - orbR, y: center.y - orbR, width: orbR * 2, height: orbR * 2))

    let image = ctx.makeImage()!
    let rep = NSBitmapImageRep(cgImage: image)
    try! rep.representation(using: .png, properties: [:])!.write(to: url)
    print("wrote", url.path)
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let previews = root.appending(path: "Branding/AppIcon/previews")
try FileManager.default.createDirectory(at: previews, withIntermediateDirectories: true)

let accent: UInt32 = 0xFF6B35
let dark = Variant(name: "dark", background: [color(0x0E0E10)], j: color(0xF5F5F7), orb: color(accent), glow: 0.55)
let light = Variant(name: "light", background: [color(0xFFFFFF)], j: color(0x0E0E10), orb: color(accent), glow: 0.35)
// Approximations of how iOS shows the mono layers; the real ones come from Icon Composer.
let tinted = Variant(name: "tinted", background: [color(0x1C1C1E), color(0x0A0A0B)],
                     j: color(0xFFB08F, 0.6), orb: color(0xFFB08F), glow: 0.35)
let clear = Variant(name: "clear", background: [color(0x5A6C7D), color(0x2B3540)],
                    j: color(0xFFFFFF, 0.6), orb: color(0xFFFFFF), glow: 0.35)

render(dark, to: root.appending(path: "Jot/Assets.xcassets/AppIcon.appiconset/AppIcon.png"))
for variant in [dark, light, tinted, clear] {
    render(variant, to: previews.appending(path: "\(variant.name).png"))
}
