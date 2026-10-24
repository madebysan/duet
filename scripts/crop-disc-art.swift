#!/usr/bin/env swift
// Crops a generated top-down vinyl photo to a tight square around the disc and saves a 1024 px JPEG
// for MixLayer/Assets.xcassets/DiscArt. Usage: swift scripts/crop-disc-art.swift in.(png|jpg) out.jpg
// Convert .webp first: sips -s format png in.webp --out in.png
// usage: crop.swift in.png out.jpg  -> finds the disc against the light background, crops a square to it, saves 1024 JPEG
import AppKit

let args = CommandLine.arguments
let img = NSImage(contentsOfFile: args[1])!.cgImage(forProposedRect: nil, context: nil, hints: nil)!
let w = img.width, h = img.height
let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
let p = ctx.data!.assumingMemoryBound(to: UInt8.self)
func px(_ x: Int, _ y: Int) -> (Int, Int, Int) { let i = (y * w + x) * 4; return (Int(p[i]), Int(p[i+1]), Int(p[i+2])) }
let bg = px(4, 4)
func isDisc(_ x: Int, _ y: Int) -> Bool { let c = px(x, y); return abs(c.0 - bg.0) + abs(c.1 - bg.1) + abs(c.2 - bg.2) > 40 }
// scan the middle row and column for the first/last disc pixel
let midY = h / 2, midX = w / 2
var left = 0; while left < w && !isDisc(left, midY) { left += 1 }
var right = w - 1; while right > 0 && !isDisc(right, midY) { right -= 1 }
var top = 0; while top < h && !isDisc(midX, top) { top += 1 }
var bottom = h - 1; while bottom > 0 && !isDisc(midX, bottom) { bottom -= 1 }
let inset = 14 // trim the rim and any off-round edge
let side = min(right - left, bottom - top) - inset * 2
let cx = (left + right) / 2, cy = (top + bottom) / 2
print("bg \(bg) disc x \(left)-\(right) y \(top)-\(bottom) center (\(cx),\(cy)) side \(side)")
// CG image coordinates have origin top-left for cropping
let rect = CGRect(x: cx - side / 2, y: cy - side / 2, width: side, height: side)
let cropped = ctx.makeImage()!.cropping(to: rect)!
let out = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
out.interpolationQuality = .high
out.draw(cropped, in: CGRect(x: 0, y: 0, width: 1024, height: 1024))
let rep = NSBitmapImageRep(cgImage: out.makeImage()!)
try! rep.representation(using: .jpeg, properties: [.compressionFactor: 0.85])!.write(to: URL(fileURLWithPath: args[2]))
print("wrote \(args[2])")
