/*
 * SPDX-License-Identifier: Apache-2.0
 */
//
//  drawdownModel.swift
//  drawloom
//
//  Created by Kevin O'Brien on 2/26/24.
//
// Copyright 2024 Kevin O'Brien.
// =============================================================================

import Foundation
import Speech
import SwiftUI
import SwiftData

class DrawdownModel: ObservableObject {
    var data: DrawdownData = DrawdownData()
    var image: DrawdownImage = DrawdownImage()
    private var viewables: DrawdownViewables?
    private var recognizer: SpeechRecognizer?
    private var speaker: Speaker = Speaker.shared
    private var synthesizer = AVSpeechSynthesizer()
    private var viewmodel: MyViewModel
    private var stepperClient: StepperClient = StepperClient(host: "192.168.86.244")

    // ── State for color naming flow ──────────────────────────────────
    /// Index of color currently being named (-1 = not in naming mode)
    @Published var namingColorIndex: Int = -1
    /// Called when naming is complete
    var onNamingComplete: (() -> Void)?

    // ── State for execution flow ─────────────────────────────────────
    /// true when waiting for "Go please" to send next pass
    @Published var waitingForGo: Bool = false
    /// true when executing a pass
    @Published var executing: Bool = false

    // ── State notification posting ───────────────────────────────────
    private func postStateChange() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .colorModeStateChanged,
                object: nil,
                userInfo: [
                    "namingIndex": self.namingColorIndex,
                    "waitingForGo": self.waitingForGo,
                    "executing": self.executing
                ]
            )
        }
    }


    enum UtteranceType: Int {
        case Release = 1, Draw, Pulled, Empty
    }
    private var utteranceType: UtteranceType = .Release
    private var restart: () -> Void = {}

    init(offset: Int, viewables: DrawdownViewables, viewmodel: MyViewModel) {
        data.offset = offset
        self.viewables = viewables
        self.viewmodel = viewmodel
        utteranceType = .Release
    }

    init(drawdownData: DrawdownData, viewables: DrawdownViewables, viewmodel: MyViewModel) {
        data = drawdownData
        self.viewables = viewables
        self.viewmodel = viewmodel
        utteranceType = UtteranceType(rawValue: data.utteranceRawValue) ?? .Release
        stepperClient.setHost(data.bbHost, port: data.bbPort)
    }

    // ══════════════════════════════════════════════════════════════════
    // MARK: - Color image loading
    // ══════════════════════════════════════════════════════════════════

    func loadColorImage(selectedFile: URL) {
        data = DrawdownData()
        data.selectedFile = selectedFile.lastPathComponent
        data.isColorMode = true

        do {
            if selectedFile.startAccessingSecurityScopedResource() {
                guard let img = UIImage(data: try Data(contentsOf: selectedFile)) else { return }
                defer { selectedFile.stopAccessingSecurityScopedResource() }

                let (w, h, rgbaPixels) = img.rgbaPixelData()
                guard let pixels = rgbaPixels else { return }

                data.colorPixels = pixels
                data.width = w
                data.height = h

                // Also make grayscale for display
                let grayPixels = img.grayscalePixels(width: w, height: h)
                data.pixels = grayPixels

                // Extract unique colors
                extractColors()
                data.drawDownLoaded = true
                updateImage()
            }
        } catch {
            print("loadColorImage error: \(error)")
        }
    }

    /// Quantize image to up to 4 unique colors using simple clustering
    private func extractColors() {
        guard !data.colorPixels.isEmpty else { return }

        var colorCounts: [UInt32: Int] = [:]
        let w = data.width
        let h = data.height
        let pixels = data.colorPixels

        // Sample every pixel, quantize to 32-level buckets (8 bits → 3 bits per channel)
        for row in 0..<h {
            for col in 0..<w {
                let i = (row * w + col) * 4
                guard i + 2 < pixels.count else { continue }
                // Quantize: round to nearest 32
                let r = UInt32((pixels[i]   / 32) * 32)
                let g = UInt32((pixels[i+1] / 32) * 32)
                let b = UInt32((pixels[i+2] / 32) * 32)
                // Skip near-white (background)
                if r > 224 && g > 224 && b > 224 { continue }
                let key = (r << 16) | (g << 8) | b
                colorCounts[key, default: 0] += 1
            }
        }

        // Sort by frequency, take top 4
        let sorted = colorCounts.sorted { $0.value > $1.value }.prefix(4)

        var colorList: [UInt8] = []
        for (key, _) in sorted {
            let r = UInt8((key >> 16) & 0xFF)
            let g = UInt8((key >> 8) & 0xFF)
            let b = UInt8(key & 0xFF)
            colorList.append(contentsOf: [r, g, b])
        }

        data.colorList = colorList
        data.numColors = sorted.count
        data.colorNames = Array(repeating: "", count: data.numColors)
        data.colorNamingDone = false
        data.currentColorPass = 0

        print("Extracted \(data.numColors) colors")
    }

    // ══════════════════════════════════════════════════════════════════
    // MARK: - Color naming flow
    // ══════════════════════════════════════════════════════════════════

    /// Start the color naming sequence
    func startColorNaming(completion: @escaping () -> Void) {
        onNamingComplete = completion
        namingColorIndex = 0
        postStateChange()
        promptForColorName(index: 0)
    }

    private func promptForColorName(index: Int) {
        guard index < data.numColors else {
            // All colors named
            data.colorNamingDone = true
            namingColorIndex = -1
            postStateChange()
            speaker.speak(wordsToSpeak: "All colors named. Ready to weave.")
            onNamingComplete?()
            return
        }
        namingColorIndex = index
        postStateChange()
        speaker.speak(wordsToSpeak: "What should color \(index + 1) be called?")
    }

    /// Called when user speaks a color name
    func assignColorName(_ name: String) {
        guard namingColorIndex >= 0, namingColorIndex < data.numColors else { return }
        data.colorNames[namingColorIndex] = name
        speaker.speak(wordsToSpeak: "OK, I'll call this color \(name).")
        let next = namingColorIndex + 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.promptForColorName(index: next)
        }
    }

    // ══════════════════════════════════════════════════════════════════
    // MARK: - Color mode execution
    // ══════════════════════════════════════════════════════════════════

    /// Announce current row and first pass, then wait for Go
    func announceRow() {
        guard data.isColorMode else { return }
        let row = data.currentLineNum + 1
        let total = data.height
        let colorName = data.colorName(at: data.currentColorPass)
        speaker.speak(wordsToSpeak: "Row \(row) of \(total). \(colorName) pass ready.")
        waitingForGo = true
        postStateChange()
    }

    /// Execute the current color pass — called after "Go please"
    func executeCurrentPass() {
        guard data.isColorMode, waitingForGo else { return }
        waitingForGo = false
        executing = true
        postStateChange()

        let row = data.currentLineNum
        let colorIndex = data.currentColorPass
        let colorName = data.colorName(at: colorIndex)
        let bitStr = data.bitString(row: row, colorIndex: colorIndex)

        speaker.speak(wordsToSpeak: "Sending \(colorName) pass.")

        stepperClient.setHost(data.bbHost, port: data.bbPort)

        DispatchQueue.global(qos: .userInitiated).async {
            let success = self.stepperClient.sendSync(command: bitStr)
            DispatchQueue.main.async {
                self.executing = false
                self.postStateChange()
                if success {
                    self.advanceColorPass()
                } else {
                    self.speaker.speak(wordsToSpeak: "Connection failed. Please try again.")
                    self.waitingForGo = true
                    self.postStateChange()
                }
            }
        }
    }

    /// Move to next color pass, or next row if all colors done
    private func advanceColorPass() {
        let nextPass = data.currentColorPass + 1
        if nextPass < data.numColors {
            data.currentColorPass = nextPass
            let colorName = data.colorName(at: nextPass)
            speaker.speak(wordsToSpeak: "\(data.colorName(at: nextPass - 1)) pass complete. \(colorName) pass ready.")
            waitingForGo = true
            postStateChange()
        } else {
            // All passes for this row done
            data.currentColorPass = 0
            let row = data.currentLineNum + 1
            speaker.speak(wordsToSpeak: "Row \(row) complete. Say Next for next row.")
        }
    }

    // ══════════════════════════════════════════════════════════════════
    // MARK: - Voice commands
    // ══════════════════════════════════════════════════════════════════

    func sendVerb(verb: String) {
        // Color naming mode intercepts all speech
        if namingColorIndex >= 0 {
            assignColorName(verb)
            return
        }

        switch verb.lowercased() {
        case "help":
            speakHelpText()
        case "go":
            if data.isColorMode {
                executeCurrentPass()
            } else {
                sayNext()
            }
        case "next":
            move(delta: 1)
        case "previous":
            move(delta: -1)
        case "skip":
            move(delta: 10)
        case "draws", "draw":
            if !data.isColorMode { startDraws() }
        case "releases", "release":
            if !data.isColorMode { startReleases() }
        case "check":
            if !data.isColorMode { startCheck() }
        case "repeat":
            if data.isColorMode {
                announceRow()
            } else {
                data.utterancePosition -= 1
                data.display()
                sayNext()
            }
        default:
            notRecognized()
        }
    }

    // ══════════════════════════════════════════════════════════════════
    // MARK: - Navigation
    // ══════════════════════════════════════════════════════════════════

    func move(delta: Int) {
        let newLine = data.currentLineNum + delta
        guard newLine >= 0 && newLine < data.height else {
            speaker.speak(wordsToSpeak: "End of pattern.")
            return
        }
        data.currentLineNum = newLine
        data.currentColorPass = 0

        if data.isColorMode {
            updateImage()
            announceRow()
        } else {
            setCurrentLineValues()
            utteranceType = .Release
            data.utteranceRawValue = utteranceType.rawValue
            data.utterancePosition = 0
            data.display()
            updateImage()
            speaker.speak(wordsToSpeak: "OK")
        }
    }

    // ══════════════════════════════════════════════════════════════════
    // MARK: - BW drawloom methods (unchanged)
    // ══════════════════════════════════════════════════════════════════

    func notRecognized() {
        speaker.speak(wordsToSpeak: "I don't recognize that verb, sorry!")
    }

    func getUtterance() -> String {
        var utterance = ""
        var prefix = ""
        var ustart: [Int] = [0]
        var ustop: [Int] = [0]

        switch utteranceType {
        case .Release:
            prefix = "Release "
            ustart = data.uStart[data.currentLineNum][UtteranceType.Release.rawValue-1]
            ustop  = data.uStop[data.currentLineNum][UtteranceType.Release.rawValue-1]
        case .Draw:
            prefix = "Draw "
            ustart = data.uStart[data.currentLineNum][UtteranceType.Draw.rawValue-1]
            ustop  = data.uStop[data.currentLineNum][UtteranceType.Draw.rawValue-1]
        case .Pulled:
            prefix = "Active cords  "
            ustart = data.uStart[data.currentLineNum][UtteranceType.Pulled.rawValue-1]
            ustop  = data.uStop[data.currentLineNum][UtteranceType.Pulled.rawValue-1]
        case .Empty:
            ustart = [0]; ustop = [0]
        }

        if data.utterancePosition <= ustart.count - 1 {
            if ustart[data.utterancePosition] == ustop[data.utterancePosition] {
                utterance = String(ustart[data.utterancePosition] + data.offset)
            } else {
                utterance = String(ustart[data.utterancePosition] + data.offset) +
                            " to " + String(ustop[data.utterancePosition] + data.offset)
            }
            utterance = prefix + utterance
            data.utterancePosition += 1
            data.display(from: "after update")
            if data.utterancePosition == ustart.count {
                data.utterancePosition -= 1
                utterance += " section is finished"
            }
        }
        return utterance
    }

    func sayNext() {
        updateImage()
        let utterance = getUtterance()
        speaker.speak(wordsToSpeak: utterance)
    }

    func startDraws() {
        utteranceType = .Draw
        data.utterancePosition = 0
        data.utteranceRawValue = utteranceType.rawValue
        data.display(); updateImage()
        speaker.speak(wordsToSpeak: "OK")
    }

    func startReleases() {
        utteranceType = .Release
        data.utterancePosition = 0
        data.utteranceRawValue = utteranceType.rawValue
        data.display(); updateImage()
        speaker.speak(wordsToSpeak: "OK")
    }

    func startCheck() {
        utteranceType = .Pulled
        data.utterancePosition = 0
        data.utteranceRawValue = utteranceType.rawValue
        data.display(); updateImage()
        speaker.speak(wordsToSpeak: "OK")
    }

    func speakHelpText() {
        if data.isColorMode {
            speaker.speak(wordsToSpeak: "Commands are Go Next Previous Repeat and Help")
        } else {
            speaker.speak(wordsToSpeak: "Commands are Draws Releases Check Go Next Previous Repeat and Help")
        }
    }

    func setOffset(offset: Int) {
        data.offset = offset
    }

    private func setLineValues(pulls: String, up: String, down: String) {
        Task {
            viewables!.pulledLine = pulls
            data.releaseLine = up
            data.drawLine = down
        }
    }

    private func setCurrentLineValues() {
        var pulls = ""; var ups = ""; var downs = ""
        for s in data.imline[data.currentLineNum] { pulls += (s + ", ") }
        for s in data.upline[data.currentLineNum]  { ups   += (s + ", ") }
        for s in data.downline[data.currentLineNum] { downs += (s + ", ") }
        setLineValues(pulls: pulls, up: ups, down: downs)
    }

    private func buildTextRow(pick: [UInt8]) -> ([String], [Int], [Int]) {
        var col = 0; var line: [String] = []; var uStart: [Int] = []; var uStop: [Int] = []
        let width = pick.count
        while col < width {
            if pick[col] == 0 {
                let start = col; var stop = col
                while stop < width {
                    if stop == width - 1 { break }
                    if pick[stop+1] > 0 { break } else { stop += 1 }
                }
                col = stop + 1
                if start == stop {
                    line.append(String(start + data.offset))
                } else {
                    line.append(String(start + data.offset) + " to " + String(stop + data.offset))
                }
                uStart.append(start); uStop.append(stop)
            } else { col += 1 }
        }
        return (line, uStart, uStop)
    }

    func extractDrawPlan(width: Int, height: Int, pixels: [UInt8]) {
        var img_array = [[UInt8]](repeating: [UInt8](repeating: 0, count: width), count: height)
        var previous  = [UInt8](repeating: 255, count: width)
        var ups   = [[UInt8]](repeating: [UInt8](repeating: 255, count: width), count: height)
        var downs = [[UInt8]](repeating: [UInt8](repeating: 255, count: width), count: height)

        for row in 0..<height {
            for col in 0..<width {
                let colx = width - 1 - col
                if data.upsideDown {
                    img_array[row][col] = pixels[row * width + colx]
                } else {
                    img_array[row][col] = pixels[(height-1-row) * width + colx]
                }
            }
        }
        for row in 0..<height {
            for col in 0..<width {
                if img_array[row][col] != previous[col] {
                    if img_array[row][col] > 0 { ups[row][col] = 0 }
                    else                        { downs[row][col] = 0 }
                }
                previous[col] = img_array[row][col]
            }
        }
        data.imline = []; data.upline = []; data.downline = []
        data.uStart = []; data.uStop = []
        for row in 0..<height {
            data.imline.append([]); data.upline.append([]); data.downline.append([])
            data.uStart.append([[],[],[]]); data.uStop.append([[],[],[]])
            let im = buildTextRow(pick: img_array[row])
            data.imline[row] = im.0
            data.uStart[row][UtteranceType.Pulled.rawValue-1] = im.1
            data.uStop[row][UtteranceType.Pulled.rawValue-1]  = im.2
            let up = buildTextRow(pick: ups[row])
            data.upline[row] = up.0
            data.uStart[row][UtteranceType.Release.rawValue-1] = up.1
            data.uStop[row][UtteranceType.Release.rawValue-1]  = up.2
            let dn = buildTextRow(pick: downs[row])
            data.downline[row] = dn.0
            data.uStart[row][UtteranceType.Draw.rawValue-1] = dn.1
            data.uStop[row][UtteranceType.Draw.rawValue-1]  = dn.2
        }
    }

    func updateImage() {
        viewmodel.ddImage = image.updateImage(with: data)
    }

    func processBitmapBody(selectedFile: URL) {
        data = DrawdownData()
        data.selectedFile = selectedFile.lastPathComponent
        data.isColorMode = false
        do {
            if selectedFile.startAccessingSecurityScopedResource() {
                guard let img = UIImage(data: try Data(contentsOf: selectedFile)) else { return }
                defer { selectedFile.stopAccessingSecurityScopedResource() }
                let (w, h, pixels) = img.pixelData()
                guard let pixels = pixels else { return }
                extractDrawPlan(width: w, height: h, pixels: pixels)
                data.pixels = pixels; data.width = w; data.height = h
                updateImage(); data.drawDownLoaded = true
            }
        } catch { print("processBitmapBody error: \(error)") }
    }

    func loadDrawdown(selectedFile: URL) {
        // Auto-detect color vs BW based on image content
        if isColorImage(url: selectedFile) {
            loadColorImage(selectedFile: selectedFile)
        } else {
            processBitmapBody(selectedFile: selectedFile)
        }
    }

    /// Returns true if the image has significant color (not grayscale)
    private func isColorImage(url: URL) -> Bool {
        guard url.startAccessingSecurityScopedResource(),
              let img = try? UIImage(data: Data(contentsOf: url)) else { return false }
        defer { url.stopAccessingSecurityScopedResource() }
        guard let cgImage = img.cgImage else { return false }
        // Check if image has a color color space
        let colorSpace = cgImage.colorSpace
        let model = colorSpace?.model ?? .unknown
        return model == .rgb
    }

    private func setImg(_ img: UIImage) {
        viewables!.img = img
    }
}

// ══════════════════════════════════════════════════════════════════
// MARK: - UIImage extensions
// ══════════════════════════════════════════════════════════════════

extension UIImage {
    /// Returns (width, height, grayscale pixels)
    func pixelData() -> (Int, Int, [UInt8]?) {
        let size = self.size
        var pixelData = [UInt8](repeating: 0, count: Int(size.width * size.height))
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let context = CGContext(data: &pixelData,
                                width: Int(size.width), height: Int(size.height),
                                bitsPerComponent: 8, bytesPerRow: Int(size.width),
                                space: colorSpace,
                                bitmapInfo: CGImageAlphaInfo.none.rawValue)
        guard let cgImage = self.cgImage else { return (0, 0, nil) }
        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        return (Int(size.width), Int(size.height), pixelData)
    }

    /// Returns (width, height, RGBA pixels)
    func rgbaPixelData() -> (Int, Int, [UInt8]?) {
        let size = self.size
        let w = Int(size.width); let h = Int(size.height)
        var pixelData = [UInt8](repeating: 0, count: w * h * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: &pixelData,
                                width: w, height: h,
                                bitsPerComponent: 8, bytesPerRow: w * 4,
                                space: colorSpace,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let cgImage = self.cgImage else { return (0, 0, nil) }
        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        return (w, h, pixelData)
    }

    /// Returns grayscale pixels from an already-loaded image
    func grayscalePixels(width: Int, height: Int) -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: width * height)
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let context = CGContext(data: &pixels,
                                width: width, height: height,
                                bitsPerComponent: 8, bytesPerRow: width,
                                space: colorSpace,
                                bitmapInfo: CGImageAlphaInfo.none.rawValue)
        if let cg = self.cgImage {
            context?.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        return pixels
    }
}

extension UIImage {
    convenience init?(pixels: [UInt8], width: Int, height: Int) {
        guard width > 0 && height > 0, pixels.count == width * height else { return nil }
        var data = pixels
        guard let providerRef = CGDataProvider(data: Data(bytes: &data, count: data.count) as CFData)
        else { return nil }
        guard let cgim = CGImage(width: width, height: height,
                                 bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: width,
                                 space: CGColorSpaceCreateDeviceGray(),
                                 bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                                 provider: providerRef, decode: nil,
                                 shouldInterpolate: false, intent: .defaultIntent)
        else { return nil }
        self.init(cgImage: cgim)
    }
}

extension UIImage {
    convenience init?(pixels: [[UInt8]], width: Int, height: Int) {
        guard width > 0 && height > 0, pixels.count == width * height else { return nil }
        var rgbdata = [UInt8](repeating: 0, count: width * height * 3)
        for i in 0..<width*height {
            for j in 0..<3 { rgbdata[i*3+j] = pixels[i][j] }
        }
        guard let providerRef = CGDataProvider(data: Data(bytes: &rgbdata, count: rgbdata.count) as CFData)
        else { return nil }
        guard let cgim = CGImage(width: width, height: height,
                                 bitsPerComponent: 8, bitsPerPixel: 24, bytesPerRow: width*3,
                                 space: CGColorSpaceCreateDeviceRGB(),
                                 bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                                 provider: providerRef, decode: nil,
                                 shouldInterpolate: false, intent: .defaultIntent)
        else { return nil }
        self.init(cgImage: cgim)
    }
}

