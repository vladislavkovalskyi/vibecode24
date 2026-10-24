#!/usr/bin/env swift
// Draws the Vibecode24 app icon and writes:
//   Assets/AppIcon.icns   (every size rendered natively from vectors, via iconutil)
//   docs/assets/icon.png  (512 px, for the README)
//
// Usage: swift scripts/make-icon.swift
//        ICON_PREVIEW_DIR=/some/dir swift scripts/make-icon.swift   (also writes loose PNGs)
//
// The drawing: a closed MacBook in three-quarter view on a warm near-black body,
// with a small amber standby LED lit on its front edge ("awake while closed").

import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// MARK: - Paths

let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
let repoRoot = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
let assetsDir = repoRoot.appendingPathComponent("Assets")
let docsAssetsDir = repoRoot.appendingPathComponent("docs/assets")

// MARK: - Colours

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

func mix(_ a: UInt32, _ b: UInt32, _ t: CGFloat) -> CGColor {
    func ch(_ v: UInt32, _ s: UInt32) -> CGFloat { CGFloat((v >> s) & 0xFF) / 255 }
    let t = max(0, min(1, t))
    return CGColor(
        colorSpace: sRGB,
        components: [
            ch(a, 16) + (ch(b, 16) - ch(a, 16)) * t,
            ch(a, 8) + (ch(b, 8) - ch(a, 8)) * t,
            ch(a, 0) + (ch(b, 0) - ch(a, 0)) * t,
            1,
        ])!
}

let bodyTop: UInt32 = 0x1D1914
let bodyBottom: UInt32 = 0x100D0A
let lidBack: UInt32 = 0xEFE9DD  // warm off-white aluminium, far edge
let lidFront: UInt32 = 0xD9D1C3  // a touch darker towards the viewer
let wallLight: UInt32 = 0x9A9184  // side wall facing the light
let wallDark: UInt32 = 0x4A443C  // side wall turned away
let seamColor: UInt32 = 0x1A1612
let ledCore: UInt32 = 0xFFD27A
let ledAmber: UInt32 = 0xFFB020

// MARK: - Tiny 3D helper

struct V3 {
    var x, y, z: CGFloat
    static func + (a: V3, b: V3) -> V3 { V3(x: a.x + b.x, y: a.y + b.y, z: a.z + b.z) }
    static func - (a: V3, b: V3) -> V3 { V3(x: a.x - b.x, y: a.y - b.y, z: a.z - b.z) }
    static func * (a: V3, s: CGFloat) -> V3 { V3(x: a.x * s, y: a.y * s, z: a.z * s) }
    func dot(_ b: V3) -> CGFloat { x * b.x + y * b.y + z * b.z }
    var normalized: V3 {
        let l = (x * x + y * y + z * z).squareRoot()
        return V3(x: x / l, y: y / l, z: z / l)
    }
}

/// Orients the model (yaw around the vertical axis, then pitch towards the viewer)
/// and projects it with a gentle perspective.
struct Camera {
    var yaw: CGFloat
    var pitch: CGFloat
    var distance: CGFloat

    func view(_ p: V3) -> V3 {
        let ca = cos(yaw), sa = sin(yaw)
        let x1 = p.x * ca + p.z * sa
        let z1 = -p.x * sa + p.z * ca
        let cp = cos(pitch), sp = sin(pitch)
        let y2 = p.y * cp - z1 * sp
        let z2 = p.y * sp + z1 * cp
        return V3(x: x1, y: y2, z: z2)
    }

    func project(_ p: V3) -> CGPoint {
        let v = view(p)
        let k = distance / (distance - v.z)
        return CGPoint(x: v.x * k, y: v.y * k)
    }

    /// True when a surface at `p` with world normal `n` faces the camera.
    func faces(_ p: V3, normal n: V3) -> Bool {
        let vp = view(p)
        let vn = view(n)
        let toCamera = V3(x: -vp.x, y: -vp.y, z: distance - vp.z)
        return vn.dot(toCamera) > 0
    }
}

// MARK: - Shapes

/// Rounded square with continuous ("squircle") corners, like the macOS icon grid shape.
/// Each corner is a superellipse quadrant that meets the straight edges with zero
/// curvature; `radius` is the equivalent circular corner radius.
func squirclePath(in rect: CGRect, radius r: CGFloat) -> CGPath {
    let extent = min(r * 1.528665, rect.width / 2, rect.height / 2)
    // Exponent chosen so the 45-degree point matches a circular corner of radius r.
    let n = -1 / log2(1 - r * (1 - 1 / CGFloat(2).squareRoot()) / extent)
    let path = CGMutablePath()
    // Corner centres and the quadrant each one covers (angles in radians).
    let corners: [(c: CGPoint, start: CGFloat)] = [
        (CGPoint(x: rect.maxX - extent, y: rect.maxY - extent), 0),
        (CGPoint(x: rect.minX + extent, y: rect.maxY - extent), .pi / 2),
        (CGPoint(x: rect.minX + extent, y: rect.minY + extent), .pi),
        (CGPoint(x: rect.maxX - extent, y: rect.minY + extent), 3 * .pi / 2),
    ]
    let steps = 90
    var first = true
    for corner in corners {
        for i in 0...steps {
            let t = corner.start + CGFloat(i) / CGFloat(steps) * (.pi / 2)
            let c = cos(t), s = sin(t)
            let x = corner.c.x + extent * (c < 0 ? -1 : 1) * pow(abs(c), 2 / n)
            let y = corner.c.y + extent * (s < 0 ? -1 : 1) * pow(abs(s), 2 / n)
            if first { path.move(to: CGPoint(x: x, y: y)); first = false } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
    }
    path.closeSubpath()
    return path
}

/// Outline of the laptop footprint (a rounded rectangle in the x/z plane), with the
/// outward normal of each sample. +z is the front edge, +x the right side.
func footprint(width w: CGFloat, depth d: CGFloat, radius r: CGFloat, perCorner: Int = 24)
    -> [(p: V3, n: V3)]
{
    var out: [(p: V3, n: V3)] = []
    let corners: [(cx: CGFloat, cz: CGFloat, start: CGFloat)] = [
        (w / 2 - r, d / 2 - r, 0),  // front right
        (-w / 2 + r, d / 2 - r, .pi / 2),  // front left
        (-w / 2 + r, -d / 2 + r, .pi),  // back left
        (w / 2 - r, -d / 2 + r, 3 * .pi / 2),  // back right
    ]
    for c in corners {
        for i in 0...perCorner {
            let t = c.start + CGFloat(i) / CGFloat(perCorner) * (.pi / 2)
            let n = V3(x: cos(t), y: 0, z: sin(t))
            out.append((V3(x: c.cx + r * n.x, y: 0, z: c.cz + r * n.z), n))
        }
    }
    return out
}

func orderedRun(_ segments: [Int], count: Int) -> [Int] {
    // Visible wall segments form one contiguous run around a convex footprint.
    let set = Set(segments)
    guard let start = segments.first(where: { !set.contains(($0 - 1 + count) % count) }) else {
        return segments
    }
    var run: [Int] = []
    var i = start
    while set.contains(i) && run.count < count {
        run.append(i)
        i = (i + 1) % count
    }
    return run
}

func convexHull(_ points: [CGPoint]) -> [CGPoint] {
    let pts = points.sorted { $0.x == $1.x ? $0.y < $1.y : $0.x < $1.x }
    func cross(_ o: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
        (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)
    }
    var lower: [CGPoint] = []
    for p in pts {
        while lower.count >= 2 && cross(lower[lower.count - 2], lower[lower.count - 1], p) <= 0 {
            lower.removeLast()
        }
        lower.append(p)
    }
    var upper: [CGPoint] = []
    for p in pts.reversed() {
        while upper.count >= 2 && cross(upper[upper.count - 2], upper[upper.count - 1], p) <= 0 {
            upper.removeLast()
        }
        upper.append(p)
    }
    return Array(lower.dropLast() + upper.dropLast())
}

// MARK: - Icon drawing

struct Style {
    var thickness: CGFloat  // laptop thickness relative to its width
    var ledLength: CGFloat  // LED length relative to the laptop width
    var ledHeight: CGFloat  // LED height relative to the thickness
    var details: Bool  // thumb scoop and chamfer highlight
}

func drawIcon(in ctx: CGContext, size: CGFloat, style: Style) {
    let s = size / 1024
    ctx.saveGState()
    ctx.scaleBy(x: s, y: s)
    ctx.setShouldAntialias(true)
    ctx.interpolationQuality = .high

    // Body: 824 pt continuous-corner square on the 1024 grid, with a soft shadow.
    let bodyRect = CGRect(x: 100, y: 100, width: 824, height: 824)
    let body = squirclePath(in: bodyRect, radius: 185.4)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 22, color: rgb(0x000000, 0.42))
    ctx.addPath(body)
    ctx.setFillColor(rgb(bodyBottom))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(body)
    ctx.clip()
    let bodyGradient = CGGradient(
        colorsSpace: sRGB, colors: [rgb(bodyTop), rgb(bodyBottom)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(
        bodyGradient, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])

    // A hairline of light along the upper rim, fading out towards the middle.
    ctx.addPath(body)
    ctx.setLineWidth(3)
    ctx.replacePathWithStrokedPath()
    ctx.clip()
    let rim = CGGradient(
        colorsSpace: sRGB,
        colors: [rgb(0xFFF4E0, 0.16), rgb(0xFFF4E0, 0.0)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(
        rim, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 480), options: [])
    ctx.restoreGState()

    // Laptop model, in units of its width.
    let W: CGFloat = 1.0
    let D: CGFloat = 0.70
    let H: CGFloat = style.thickness
    let radius: CGFloat = 0.045
    let camera = Camera(yaw: -0.42, pitch: 0.50, distance: 4.0)
    let outline = footprint(width: W, depth: D, radius: radius)

    // Fit the projected model into the body, centred.
    var minX = CGFloat.infinity, maxX = -CGFloat.infinity
    var minY = CGFloat.infinity, maxY = -CGFloat.infinity
    for o in outline {
        for y in [0, H] {
            let p = camera.project(V3(x: o.p.x, y: y, z: o.p.z))
            minX = min(minX, p.x); maxX = max(maxX, p.x)
            minY = min(minY, p.y); maxY = max(maxY, p.y)
        }
    }
    let targetWidth: CGFloat = style.details ? 680 : 720
    let k = targetWidth / (maxX - minX)
    let centre = CGPoint(x: 512, y: 500)
    let ox = centre.x - (minX + maxX) / 2 * k
    let oy = centre.y - (minY + maxY) / 2 * k
    func P(_ v: V3) -> CGPoint {
        let p = camera.project(v)
        return CGPoint(x: ox + p.x * k, y: oy + p.y * k)
    }

    let light = V3(x: -0.35, y: 0.55, z: 0.75).normalized

    // Silhouette: casts the shadow and sits under the facets so no seams show between them.
    let silhouette = CGMutablePath()
    do {
        var pts: [CGPoint] = []
        for o in outline { pts.append(P(V3(x: o.p.x, y: 0, z: o.p.z))) }
        for o in outline { pts.append(P(V3(x: o.p.x, y: H, z: o.p.z))) }
        silhouette.addLines(between: convexHull(pts))
        silhouette.closeSubpath()
    }
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 34, color: rgb(0x000000, 0.75))
    ctx.addPath(silhouette)
    ctx.setFillColor(rgb(wallDark))
    ctx.fillPath()
    ctx.restoreGState()

    // Side walls, one facet per outline segment, shaded by how they face the light.
    var visibleSegments: [Int] = []
    for i in 0..<outline.count {
        let a = outline[i], b = outline[(i + 1) % outline.count]
        let n = (a.n + b.n).normalized
        let mid = V3(x: (a.p.x + b.p.x) / 2, y: H / 2, z: (a.p.z + b.p.z) / 2)
        guard camera.faces(mid, normal: n) else { continue }
        visibleSegments.append(i)
        let vn = camera.view(n).normalized
        let lambert = max(0, vn.dot(light))
        let colour = mix(wallDark, wallLight, pow(lambert, 1.4))
        let quad = CGMutablePath()
        quad.addLines(between: [
            P(V3(x: a.p.x, y: 0, z: a.p.z)), P(V3(x: b.p.x, y: 0, z: b.p.z)),
            P(V3(x: b.p.x, y: H, z: b.p.z)), P(V3(x: a.p.x, y: H, z: a.p.z)),
        ])
        quad.closeSubpath()
        ctx.addPath(quad)
        ctx.setFillColor(colour)
        ctx.setStrokeColor(colour)
        ctx.setLineWidth(1.2)
        ctx.drawPath(using: .fillStroke)
    }
    let run = orderedRun(visibleSegments, count: outline.count)
    let runPoints = run.isEmpty ? [] : run + [(run.last! + 1) % outline.count]

    func polyline(atHeight y: CGFloat) -> CGPath {
        let path = CGMutablePath()
        for (j, i) in runPoints.enumerated() {
            let o = outline[i]
            let p = P(V3(x: o.p.x, y: y, z: o.p.z))
            if j == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        return path
    }

    // Seam between the closed lid and the base, just under the middle of the wall.
    let seamY = H * 0.46
    ctx.addPath(polyline(atHeight: seamY))
    ctx.setStrokeColor(rgb(seamColor, 0.9))
    ctx.setLineWidth(style.details ? 3.2 : 5)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.strokePath()

    if style.details {
        // Thumb scoop in the middle of the front edge.
        let scoop = CGMutablePath()
        let half: CGFloat = 0.075
        let depth = H * 0.30
        let steps = 24
        for j in 0...steps {
            let t = CGFloat(j) / CGFloat(steps)
            let p = P(V3(x: -half + 2 * half * t, y: seamY - depth * sin(t * .pi), z: D / 2 + 0.0005))
            if j == 0 { scoop.move(to: p) } else { scoop.addLine(to: p) }
        }
        scoop.closeSubpath()
        ctx.addPath(scoop)
        ctx.setFillColor(rgb(seamColor, 0.55))
        ctx.fillPath()
    }

    // Lid: the top face, a soft back-to-front tonal shift.
    let top = CGMutablePath()
    top.addLines(between: outline.map { P(V3(x: $0.p.x, y: H, z: $0.p.z)) })
    top.closeSubpath()
    ctx.saveGState()
    ctx.addPath(top)
    ctx.clip()
    let lidGradient = CGGradient(
        colorsSpace: sRGB, colors: [rgb(lidBack), rgb(lidFront)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(
        lidGradient,
        start: P(V3(x: -0.2, y: H, z: -D / 2)), end: P(V3(x: 0.2, y: H, z: D / 2)),
        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    ctx.restoreGState()

    if style.details {
        // Polished chamfer: a bright line along the visible front edges of the lid.
        ctx.addPath(polyline(atHeight: H))
        ctx.setStrokeColor(rgb(0xFFFCF5, 0.85))
        ctx.setLineWidth(2.4)
        ctx.strokePath()
    }

    // Standby LED: a short pill on the front of the base, right of centre, drawn in the
    // plane of the front face so it follows the perspective.
    let ledX: CGFloat = 0.30
    let ledHalfLen = style.ledLength / 2
    let ledHalfH = H * style.ledHeight / 2
    let ledY = seamY * 0.5
    let zFront = D / 2 + 0.001
    let ledPath = CGMutablePath()
    do {
        let steps = 16
        var pts: [CGPoint] = []
        for j in 0...steps {  // right cap
            let t = -CGFloat.pi / 2 + CGFloat(j) / CGFloat(steps) * .pi
            pts.append(P(V3(
                x: ledX + ledHalfLen - ledHalfH + ledHalfH * cos(t), y: ledY + ledHalfH * sin(t), z: zFront)))
        }
        for j in 0...steps {  // left cap
            let t = CGFloat.pi / 2 + CGFloat(j) / CGFloat(steps) * .pi
            pts.append(P(V3(
                x: ledX - ledHalfLen + ledHalfH + ledHalfH * cos(t), y: ledY + ledHalfH * sin(t), z: zFront)))
        }
        ledPath.addLines(between: pts)
        ledPath.closeSubpath()
    }
    let ledLeft = P(V3(x: ledX - ledHalfLen, y: ledY, z: zFront))
    let ledRight = P(V3(x: ledX + ledHalfLen, y: ledY, z: zFront))
    let ledScreenLen = hypot(ledRight.x - ledLeft.x, ledRight.y - ledLeft.y)

    // The LED, with a tight glow that hugs the pill and stays smaller than the LED itself.
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: ledScreenLen * 0.22, color: rgb(ledAmber, 0.9))
    ctx.addPath(ledPath)
    ctx.setFillColor(rgb(ledAmber))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(ledPath)
    ctx.clip()
    let ledBox = ledPath.boundingBox
    let ledGradient = CGGradient(
        colorsSpace: sRGB, colors: [rgb(ledCore), rgb(ledAmber)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(
        ledGradient, start: CGPoint(x: ledBox.midX, y: ledBox.maxY),
        end: CGPoint(x: ledBox.midX, y: ledBox.minY), options: [])
    ctx.restoreGState()

    ctx.restoreGState()
}

// MARK: - Rendering

func render(pixels: Int) -> CGImage {
    let ctx = CGContext(
        data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
        space: sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    // Small sizes get a thicker slab, a larger LED and fewer details so they still read.
    let style: Style
    switch pixels {
    case ..<24: style = Style(thickness: 0.15, ledLength: 0.30, ledHeight: 0.52, details: false)
    case ..<48: style = Style(thickness: 0.12, ledLength: 0.24, ledHeight: 0.44, details: false)
    case ..<160: style = Style(thickness: 0.095, ledLength: 0.17, ledHeight: 0.34, details: true)
    default: style = Style(thickness: 0.085, ledLength: 0.115, ledHeight: 0.30, details: true)
    }
    drawIcon(in: ctx, size: CGFloat(pixels), style: style)
    return ctx.makeImage()!
}

func writePNG(_ image: CGImage, to url: URL) throws {
    guard
        let dest = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { throw NSError(domain: "make-icon", code: 1) }
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else { throw NSError(domain: "make-icon", code: 2) }
}

let fm = FileManager.default
try fm.createDirectory(at: assetsDir, withIntermediateDirectories: true)
try fm.createDirectory(at: docsAssetsDir, withIntermediateDirectories: true)

let iconset = fm.temporaryDirectory.appendingPathComponent("Vibecode24-\(UUID().uuidString).iconset")
try fm.createDirectory(at: iconset, withIntermediateDirectories: true)
defer { try? fm.removeItem(at: iconset) }

let entries: [(name: String, pixels: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for e in entries {
    try writePNG(render(pixels: e.pixels), to: iconset.appendingPathComponent("\(e.name).png"))
}

let icns = assetsDir.appendingPathComponent("AppIcon.icns")
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", icns.path]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else {
    FileHandle.standardError.write("iconutil failed\n".data(using: .utf8)!)
    exit(1)
}

let readmeIcon = docsAssetsDir.appendingPathComponent("icon.png")
try writePNG(render(pixels: 512), to: readmeIcon)

if let previewDir = ProcessInfo.processInfo.environment["ICON_PREVIEW_DIR"] {
    let dir = URL(fileURLWithPath: previewDir)
    try fm.createDirectory(at: dir, withIntermediateDirectories: true)
    for px in [16, 32, 64, 128, 256, 1024] {
        try writePNG(render(pixels: px), to: dir.appendingPathComponent("icon-\(px).png"))
    }
}

print("Wrote \(icns.path)")
print("Wrote \(readmeIcon.path)")
