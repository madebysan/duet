#!/usr/bin/env swift
// Renders placeholder artwork printed on Duet's built-in sound discs.
//
// Each image is a 512 px square JPEG that the app clips to the disc. They are
// deterministic placeholders: replace any of them by dropping a new image into
// MixLayer/Assets.xcassets/DiscArt/disc-<sound-id>.imageset/ with the same file name.
//
// Usage: swift scripts/generate-disc-art.swift [asset-catalog-folder] [--force]
// Existing images are kept unless --force is passed, so hand-replaced art is safe.

import AppKit
import CoreGraphics
import Foundation

let size = 512

struct RNG {
    var state: UInt64
    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 11) / Double(UInt64(1) << 53)
    }
    mutating func range(_ lo: Double, _ hi: Double) -> Double { lo + (hi - lo) * next() }
}

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        red: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func makeContext() -> CGContext {
    CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
}

func verticalGradient(_ ctx: CGContext, top: CGColor, bottom: CGColor) {
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [bottom, top] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size), options: [])
}

func diagonalGradient(_ ctx: CGContext, from: CGColor, to: CGColor) {
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [from, to] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size), end: CGPoint(x: size, y: 0), options: [])
}

func blob(_ ctx: CGContext, x: Double, y: Double, radius: Double, _ c: CGColor) {
    let clear = c.copy(alpha: 0)!
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [c, clear] as CFArray, locations: [0, 1])!
    let center = CGPoint(x: x, y: y)
    ctx.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
}

/// Adds film grain directly to the pixels. `strength` is the max per-channel offset (0-255).
func grain(_ ctx: CGContext, rng: inout RNG, strength: Double, mono: Bool = true) {
    guard let data = ctx.data?.assumingMemoryBound(to: UInt8.self) else { return }
    for i in 0..<(size * size) {
        let base = i * 4
        let shared = rng.range(-strength, strength)
        for channel in 0..<3 {
            let offset = mono ? shared : rng.range(-strength, strength)
            let value = Double(data[base + channel]) + offset
            data[base + channel] = UInt8(max(0, min(255, value)))
        }
    }
}

func save(_ ctx: CGContext, to url: URL) throws {
    let image = ctx.makeImage()!
    let rep = NSBitmapImageRep(cgImage: image)
    let data = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.82])!
    try data.write(to: url)
}

// MARK: - Designs

func rain(_ ctx: CGContext, _ rng: inout RNG) {
    verticalGradient(ctx, top: color(0x5E86B8), bottom: color(0x0E2440))
    blob(ctx, x: 360, y: 430, radius: 260, color(0xA9C8EE, 0.35))
    ctx.setLineCap(.round)
    for _ in 0..<260 {
        let x = rng.range(-80, Double(size) + 40)
        let y = rng.range(0, Double(size))
        let length = rng.range(18, 60)
        ctx.setStrokeColor(color(0xE6F0FF, CGFloat(rng.range(0.12, 0.45))))
        ctx.setLineWidth(CGFloat(rng.range(1, 2.4)))
        ctx.move(to: CGPoint(x: x, y: y))
        ctx.addLine(to: CGPoint(x: x + length * 0.35, y: y - length))
        ctx.strokePath()
    }
    for _ in 0..<40 {
        let r = rng.range(2, 6)
        ctx.setFillColor(color(0xFFFFFF, CGFloat(rng.range(0.15, 0.4))))
        ctx.fillEllipse(in: CGRect(x: rng.range(0, Double(size)), y: rng.range(0, Double(size)), width: r, height: r))
    }
    grain(ctx, rng: &rng, strength: 10)
}

func forest(_ ctx: CGContext, _ rng: inout RNG) {
    verticalGradient(ctx, top: color(0xCDE8D6), bottom: color(0x0B3B2C))
    blob(ctx, x: 256, y: 470, radius: 300, color(0xF4FFF6, 0.5))
    let layers: [(UInt32, Double, Double)] = [(0x6FA88E, 300, 0.75), (0x2F7558, 200, 0.85), (0x0F4433, 90, 1)]
    for (hex, baseline, alpha) in layers {
        ctx.setFillColor(color(hex, CGFloat(alpha)))
        ctx.fill(CGRect(x: 0, y: 0, width: Double(size), height: baseline))
        var x = rng.range(-30, 10)
        while x < Double(size) + 40 {
            let width = rng.range(40, 80)
            let height = rng.range(90, 190)
            ctx.move(to: CGPoint(x: x, y: baseline - 4))
            ctx.addLine(to: CGPoint(x: x + width / 2, y: baseline + height))
            ctx.addLine(to: CGPoint(x: x + width, y: baseline - 4))
            ctx.closePath()
            ctx.fillPath()
            x += width * rng.range(0.55, 0.85)
        }
    }
    grain(ctx, rng: &rng, strength: 9)
}

func ocean(_ ctx: CGContext, _ rng: inout RNG) {
    verticalGradient(ctx, top: color(0xBFE6EC), bottom: color(0x07294A))
    blob(ctx, x: 380, y: 450, radius: 200, color(0xFFF4DA, 0.55))
    let bands: [(UInt32, Double)] = [(0x5DB3C4, 330), (0x2E87A6, 260), (0x1A5F86, 190), (0x0E3F66, 120), (0x082C4D, 50)]
    for (index, band) in bands.enumerated() {
        let (hex, level) = band
        let amplitude = 10.0 + Double(index) * 3
        let wavelength = rng.range(140, 220)
        let phase = rng.range(0, .pi * 2)
        ctx.setFillColor(color(hex, 0.92))
        ctx.move(to: CGPoint(x: 0, y: 0))
        for x in stride(from: 0.0, through: Double(size), by: 4) {
            ctx.addLine(to: CGPoint(x: x, y: level + amplitude * sin(x / wavelength * .pi * 2 + phase)))
        }
        ctx.addLine(to: CGPoint(x: size, y: 0))
        ctx.closePath()
        ctx.fillPath()
    }
    grain(ctx, rng: &rng, strength: 8)
}

// MARK: - Main

let positional = CommandLine.arguments.dropFirst().filter { !$0.hasPrefix("--") }
let catalog = URL(fileURLWithPath: positional.first ?? "MixLayer/Assets.xcassets")
let folder = catalog.appendingPathComponent("DiscArt", isDirectory: true)
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
try #"{"info":{"author":"xcode","version":1},"properties":{"provides-namespace":false}}"#
    .write(to: folder.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)

let designs: [(String, (CGContext, inout RNG) -> Void)] = [
    // Same motif per category, different layout per disc.
    ("steady-rain", rain), ("porch-rain", rain), ("rain-on-leaves", rain), ("gentle-rain", rain),
    ("woodland", forest), ("blackbird", forest), ("forest-wind", forest),
    ("soft-surf", ocean), ("breakers", ocean), ("beach", ocean)
]
let force = CommandLine.arguments.contains("--force")

for (index, design) in designs.enumerated() {
    let (id, draw) = design
    var rng = RNG(state: 20261017 &+ UInt64(index) &* 7919)
    let ctx = makeContext()
    draw(ctx, &rng)

    let set = folder.appendingPathComponent("disc-\(id).imageset", isDirectory: true)
    if !force, FileManager.default.fileExists(atPath: set.path) {
        print("kept \(set.lastPathComponent) (use --force to overwrite)")
        continue
    }
    try FileManager.default.createDirectory(at: set, withIntermediateDirectories: true)
    let fileName = "disc-\(id).jpg"
    try save(ctx, to: set.appendingPathComponent(fileName))
    let contents = """
    {"images":[{"filename":"\(fileName)","idiom":"universal"}],"info":{"author":"xcode","version":1}}
    """
    try contents.write(to: set.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
    print("wrote \(set.lastPathComponent)/\(fileName)")
}
