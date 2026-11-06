/*
 * SPDX-License-Identifier: Apache-2.0
 */
//
//  DrawdownData.swift
//  drawloom
//
//  Created by Kevin O'Brien on 3/4/24.
//
// Copyright 2024 Kevin O'Brien.
// =============================================================================
import Foundation
import SwiftData
import SwiftUI

@Model
class DrawdownData {
    // ── Existing BW drawloom fields ──────────────────────────────────
    var selectedFile: String = ""
    var timestamp: Date = Date()
    var pixels: [UInt8] = [UInt8](repeating: 0, count: 44000)
    var width: Int = 200
    var height: Int = 220
    var upsideDown: Bool = false
    var offset: Int = 1
    var imline: [[String]] = []
    var upline: [[String]] = []
    var downline: [[String]] = []
    var uStart: [[[Int]]] = []
    var uStop: [[[Int]]] = []
    var drawDownLoaded: Bool = false
    var currentLineNum: Int = 0
    var releaseLine: String = ""
    var drawLine: String = ""
    var utterancePosition: Int = 0
    var utteranceRawValue: Int = 1
    var floatOffset: CGFloat = 1.0
    var scale: CGFloat = 1.0

    // ── Color stepper fields ─────────────────────────────────────────
    /// true = color stepper mode
    var isColorMode: Bool = false

    /// Flattened RGBA pixels from the color image: [r,g,b,a, r,g,b,a, ...]
    /// width * height * 4 bytes
    var colorPixels: [UInt8] = []

    /// Unique quantized colors found in image.
    /// Stored as flat [r0,g0,b0, r1,g1,b1, ...], max 4 colors = 12 bytes
    var colorList: [UInt8] = []

    /// User-assigned names for each color, e.g. ["warp", "weft", "pattern"]
    var colorNames: [String] = []

    /// Number of unique colors (max 4)
    var numColors: Int = 0

    /// ESP32 hostname or IP address
    var bbHost: String = "192.168.86.244"

    /// ESP32 TCP port
    var bbPort: Int = 9000

    /// Current color pass index within current row (0-based)
    var currentColorPass: Int = 0

    /// Whether color naming has been completed for this image
    var colorNamingDone: Bool = false

    init() {}

    func display() { display(from: "") }

    func display(from: String) {
        print(from)
        print("{\(selectedFile), \(timestamp), \(width), \(height), \(offset), " +
              "\(currentLineNum), \(utterancePosition), \(scale), colorMode=\(isColorMode)}")
    }

    // ── Color helpers ────────────────────────────────────────────────

    /// Return color at index i as (r, g, b)
    func color(at i: Int) -> (UInt8, UInt8, UInt8) {
        guard i < numColors else { return (0, 0, 0) }
        let base = i * 3
        return (colorList[base], colorList[base+1], colorList[base+2])
    }

    /// Return color at index i as SwiftUI Color
    func swiftUIColor(at i: Int) -> Color {
        let (r, g, b) = color(at: i)
        return Color(red: Double(r)/255.0, green: Double(g)/255.0, blue: Double(b)/255.0)
    }

    /// Return name for color at index i
    func colorName(at i: Int) -> String {
        guard i < colorNames.count else { return "Color \(i+1)" }
        let name = colorNames[i]
        return name.isEmpty ? "Color \(i+1)" : name
    }

    /// Generate bit string for a given row and color index.
    /// Each column = 1 bit; '1' if that pixel matches the color.
    /// Applies offset: pixels 0..<offset are skipped.
    func bitString(row: Int, colorIndex: Int) -> String {
        guard isColorMode, !colorPixels.isEmpty else { return "" }

        let (cr, cg, cb) = color(at: colorIndex)
        let actualRow = upsideDown ? row : (height - 1 - row)
        var bits = ""

        let startCol = max(0, offset - 1)
        for col in startCol..<width {
            let pixelIndex = (actualRow * width + col) * 4
            guard pixelIndex + 2 < colorPixels.count else { bits += "0"; continue }
            let pr = colorPixels[pixelIndex]
            let pg = colorPixels[pixelIndex + 1]
            let pb = colorPixels[pixelIndex + 2]
            // Match with tolerance of 30 per channel
            let match = abs(Int(pr) - Int(cr)) < 30 &&
                        abs(Int(pg) - Int(cg)) < 30 &&
                        abs(Int(pb) - Int(cb)) < 30
            bits += match ? "1" : "0"
        }
        return bits
    }
}

