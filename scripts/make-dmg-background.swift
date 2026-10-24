#!/usr/bin/env swift
// Draws the background of the Vibecode24 disk image window and writes:
//   Assets/dmg-background.png      (660 x 400)
//   Assets/dmg-background@2x.png   (1320 x 800)
//   Assets/dmg-background.tiff     (both, combined with `tiffutil -cathidpicheck`)
//
// Usage: swift scripts/make-dmg-background.swift
//
// Layout in window points, origin at the top left (the coordinates create-dmg uses):
// app icon centred at (165, 190), Applications link at (495, 190).

import AppKit
import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
let repoRoot = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
let assetsDir = repoRoot.appendingPathComponent("Assets")

let width: CGFloat = 660
let height: CGFloat = 400
let appSlot = CGPoint(x: 165, y: 190)
let applicationsSlot = CGPoint(x: 495, y: 190)
let iconSize: CGFloat = 128
let caption = "Drag Vibecode24 to Applications"

let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        colorSpace: sRGB,
        components: [
            CGFloat((hex >> 16) & 0xFF) / 255,
            CGFloat((hex >> 8) & 0xFF) / 255,
            CGFloat(hex & 0xFF) / 255,
            alpha,
        ])!
}

let backgroundTop: UInt32 = 0x1B1712
let backgroundBottom: UInt32 = 0x110E0B
let ink: UInt32 = 0xF2ECE1  // warm off-white
let plate: UInt32 = 0x7E776C  // warm mid-tone under the Finder labels
// Distance from an icon centre to the centre of its Finder label (128 pt icons, 13 pt text).
let labelOffset: CGFloat = 84

func render(scale: CGFloat) -> CGImage {
    let pw = Int(width * scale), ph = Int(height * scale)
    let ctx = CGContext(
        data: nil, width: pw, height: ph, bitsPerComponent: 8, bytesPerRow: 0, space: sRGB,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.scaleBy(x: scale, y: scale)
    // Work in top-left-origin points, like Finder.
    ctx.translateBy(x: 0, y: height)
    ctx.scaleBy(x: 1, y: -1)

    // Ground: warm near-black with a slight vertical tonal shift.
    let ground = CGGradient(
        colorsSpace: sRGB, colors: [rgb(backgroundTop), rgb(backgroundBottom)] as CFArray,
        locations: [0, 1])!
    ctx.drawLinearGradient(
        ground, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: height), options: [])

    // Dotted guide from the app towards Applications, ending in an open chevron.
    let gap: CGFloat = iconSize / 2 + 30
    let startX = appSlot.x + gap
    let endX = applicationsSlot.x - gap
    let y = appSlot.y
    ctx.setFillColor(rgb(ink, 0.34))
    let dot: CGFloat = 3
    let pitch: CGFloat = 10
    var x = startX
    while x <= endX - 15 {
        ctx.fillEllipse(in: CGRect(x: x - dot / 2, y: y - dot / 2, width: dot, height: dot))
        x += pitch
    }
    let chevron = CGMutablePath()
    chevron.move(to: CGPoint(x: endX - 7, y: y - 7))
    chevron.addLine(to: CGPoint(x: endX, y: y))
    chevron.addLine(to: CGPoint(x: endX - 7, y: y + 7))
    ctx.addPath(chevron)
    ctx.setStrokeColor(rgb(ink, 0.5))
    ctx.setLineWidth(2)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.strokePath()

    // Name plates under both icons. Finder draws icon labels black in Light Mode and white
    // in Dark Mode whatever the background is, so the labels sit on a warm mid-tone that
    // keeps both readable (contrast above 4:1 either way).
    let plateSize = CGSize(width: 132, height: 22)
    for slot in [appSlot, applicationsSlot] {
        let rect = CGRect(
            x: slot.x - plateSize.width / 2, y: slot.y + labelOffset - plateSize.height / 2,
            width: plateSize.width, height: plateSize.height)
        ctx.addPath(CGPath(
            roundedRect: rect, cornerWidth: plateSize.height / 2, cornerHeight: plateSize.height / 2,
            transform: nil))
        ctx.setFillColor(rgb(plate))
        ctx.fillPath()
    }

    // One line of text near the bottom, in the system font.
    let font = NSFont.systemFont(ofSize: 13, weight: .regular)
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor(cgColor: rgb(ink, 0.62))!,
        .kern: 0.1,
    ]
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: caption, attributes: attributes))
    let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
    let baseline: CGFloat = 330
    ctx.saveGState()
    // CoreText draws with y pointing up; flip locally around the baseline.
    ctx.translateBy(x: (width - bounds.width) / 2 - bounds.minX, y: baseline)
    ctx.scaleBy(x: 1, y: -1)
    ctx.textPosition = .zero
    CTLineDraw(line, ctx)
    ctx.restoreGState()

    return ctx.makeImage()!
}

func writePNG(_ image: CGImage, to url: URL, dpi: CGFloat) throws {
    guard
        let dest = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { throw NSError(domain: "make-dmg-background", code: 1) }
    let properties: [CFString: Any] = [
        kCGImagePropertyDPIWidth: dpi,
        kCGImagePropertyDPIHeight: dpi,
    ]
    CGImageDestinationAddImage(dest, image, properties as CFDictionary)
    guard CGImageDestinationFinalize(dest) else { throw NSError(domain: "make-dmg-background", code: 2) }
}

try FileManager.default.createDirectory(at: assetsDir, withIntermediateDirectories: true)
let png1x = assetsDir.appendingPathComponent("dmg-background.png")
let png2x = assetsDir.appendingPathComponent("dmg-background@2x.png")
let tiff = assetsDir.appendingPathComponent("dmg-background.tiff")
try writePNG(render(scale: 1), to: png1x, dpi: 72)
try writePNG(render(scale: 2), to: png2x, dpi: 144)

let tiffutil = Process()
tiffutil.executableURL = URL(fileURLWithPath: "/usr/bin/tiffutil")
tiffutil.arguments = ["-cathidpicheck", png1x.path, png2x.path, "-out", tiff.path]
try tiffutil.run()
tiffutil.waitUntilExit()
guard tiffutil.terminationStatus == 0 else {
    FileHandle.standardError.write("tiffutil failed\n".data(using: .utf8)!)
    exit(1)
}

print("Wrote \(png1x.path)")
print("Wrote \(png2x.path)")
print("Wrote \(tiff.path)")
