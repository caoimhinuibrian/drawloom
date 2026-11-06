/*
 * SPDX-License-Identifier: Apache-2.0
 */
//
//  ContentView.swift
//  drawloom
//
//  Created by Kevin O'Brien on 2/20/24.
//
// Copyright 2024 Kevin O'Brien.
// =============================================================================

import SwiftUI
import Speech
import SwiftData
import Combine

struct ExecuteCode: View {
    init(_ codeToExec: () -> ()) { codeToExec() }
    var body: some View { EmptyView() }
}

struct DrawdownView: View {
    var drawdown: DrawdownData
    var body: some View { VStack { Text(drawdown.selectedFile) } }
}

// ── Settings Sheet ───────────────────────────────────────────────
struct SettingsView: View {
    @Binding var host: String
    @Binding var port: String
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("ESP32 / BBB Connection") {
                    LabeledContent("Hostname / IP") {
                        TextField("192.168.86.244", text: $host)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                    }
                    LabeledContent("Port") {
                        TextField("9000", text: $port)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// ── Color swatch row for naming ──────────────────────────────────
struct ColorNamingView: View {
    var data: DrawdownData
    var namingIndex: Int

    var body: some View {
        VStack(spacing: 12) {
            Text("Color Naming")
                .font(.headline)
            HStack(spacing: 16) {
                ForEach(0..<data.numColors, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 8)
                        .fill(data.swiftUIColor(at: i))
                        .frame(width: 60, height: 60)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(i == namingIndex ? Color.blue : Color.clear, lineWidth: 3)
                        )
                    VStack {
                        Text(i == namingIndex ? "Listening..." : data.colorName(at: i))
                            .font(.caption)
                    }
                }
            }
            if namingIndex >= 0 && namingIndex < data.numColors {
                Text("Say the name for the highlighted color")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// ── Color mode status bar ────────────────────────────────────────
struct ColorStatusView: View {
    var data: DrawdownData
    var waiting: Bool
    var executing: Bool

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading) {
                Text("Row \(data.currentLineNum + 1) of \(data.height)")
                    .font(.headline)
                Text("Pass: \(data.colorName(at: data.currentColorPass))")
                    .font(.subheadline)
                    .foregroundColor(data.swiftUIColor(at: data.currentColorPass))
            }
            Spacer()
            // Color pass indicators
            HStack(spacing: 8) {
                ForEach(0..<data.numColors, id: \.self) { i in
                    Circle()
                        .fill(data.swiftUIColor(at: i))
                        .frame(width: 20, height: 20)
                        .opacity(i == data.currentColorPass ? 1.0 : 0.3)
                }
            }
            Spacer()
            if executing {
                ProgressView()
            } else if waiting {
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// ── Main Content View ────────────────────────────────────────────
struct ContentView: View {
    @Environment(\.modelContext) var context
    var speechRecognizer: SpeechRecognizer = SpeechRecognizer()

    @State var data: DrawdownData? = nil
    @State var viewables: DrawdownViewables = DrawdownViewables()
    @State var drawdownModel: DrawdownModel? = nil
    @State var line = ""
    @State var isImporting: Bool = false
    @State var canChangeOffset: Bool = false
    @State var recognizedText = ""
    @State var speechEnabled: Bool = false
    @State var offset: Int = 1
    @State var floatOffset: CGFloat = 1.0
    @State var scale: Int = 1
    @StateObject var model: MyViewModel = MyViewModel()

    // Color mode state
    @State var namingColorIndex: Int = -1
    @State var waitingForGo: Bool = false
    @State var executing: Bool = false

    // Settings
    @State var showSettings: Bool = false
    @State var settingsHost: String = "192.168.86.244"
    @State var settingsPort: String = "9000"

    private static let formatter: NumberFormatter = {
        let f = NumberFormatter(); f.numberStyle = .decimal; return f
    }()

    init() {}

    func setState() {
        let vwables = DrawdownViewables()
        viewables = vwables
        if allDrawdowns.count > 0 {
            selectDrawdown(selected: allDrawdowns[0])
        } else {
            self.drawdownModel = DrawdownModel(offset: 1, viewables: viewables, viewmodel: model)
        }
    }

    func deleteDrawdowns(_ indexSet: IndexSet) {
        for index in indexSet {
            context.delete(allDrawdowns[index])
        }
    }

    func selectDrawdown(selected: DrawdownData) {
        selected.display()
        let vwables = DrawdownViewables()
        self.viewables = vwables
        self.drawdownModel = DrawdownModel(drawdownData: selected, viewables: vwables, viewmodel: model)
        data = selected
        data!.timestamp = Date()
        settingsHost = data!.bbHost
        settingsPort = String(data!.bbPort)

        model.ddImage = makeImage(pixels: data!.pixels, width: data!.width, height: data!.height)
        model.scale = data!.scale
        model.offset = data!.offset
        model.floatOffset = data!.floatOffset
        model.upsideDown = data!.upsideDown
        drawdownModel!.setOffset(offset: model.offset)
        speechRecognizer.setDrawdown(drawdown: drawdownModel!)
        speechRecognizer.setDelegate()
        speechRecognizer.startTranscribing()

        // Restore color mode state
        if selected.isColorMode {
            namingColorIndex = selected.colorNamingDone ? -1 : 0
        }
    }

    func makeImage(pixels: [UInt8], width: Int, height: Int) -> UIImage? {
        model.image = DrawdownImage(imageData: pixels, width: width, height: height)
        let img = model.image.updateImage(with: data!)
        drawdownModel!.image = model.image
        return img
    }

    func applySettings() {
        guard let d = data  else { return }
        d.bbHost = settingsHost
        d.bbPort = Int(settingsPort) ?? 9000
    }

    @Query(sort: \DrawdownData.timestamp, order: .reverse) var allDrawdowns: [DrawdownData]

    var body: some View {
        VStack {
            // ── Header ──────────────────────────────────────────────
            HStack {
                Spacer()
                Text("DRAWDOWNS").font(.title)
                Spacer()
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gear")
                }
                .padding(.trailing)

                NavigationStack {
                    List {
                        ForEach(allDrawdowns) { drawdown in
                            VStack {
                                HStack {
                                    if drawdown.isColorMode {
                                        Image(systemName: "photo").foregroundColor(.blue)
                                    }
                                    Text(drawdown.selectedFile)
                                        .onTapGesture { selectDrawdown(selected: drawdown) }
                                }
                            }
                        }
                        .onDelete(perform: deleteDrawdowns)
                    }
                    .frame(minWidth: 100, maxWidth: 500, minHeight: 50, maxHeight: 200)
                    .toolbar {
                        EditButton()
                        Button {
                            isImporting = true
                        } label: {
                            Image(systemName: "plus.square")
                        }
                    }
                    .fileImporter(
                        isPresented: $isImporting,
                        allowedContentTypes: [.image],
                        allowsMultipleSelection: false
                    ) { result in
                        do {
                            guard let selectedFile = try result.get().first else { return }
                            drawdownModel!.loadDrawdown(selectedFile: selectedFile)
                            data = drawdownModel!.data
                            context.insert(data!)
                            model.ddImage = makeImage(pixels: data!.pixels,
                                                      width: data!.width, height: data!.height)
                            model.scale = data!.scale
                            model.offset = data!.offset
                            model.floatOffset = data!.floatOffset
                            model.upsideDown = data!.upsideDown
                            drawdownModel!.setOffset(offset: model.offset)
                            speechRecognizer.setDrawdown(drawdown: drawdownModel!)
                            speechRecognizer.setDelegate()
                            speechRecognizer.startTranscribing()

                            // Start color naming if new color image
                            if data!.isColorMode && !data!.colorNamingDone {
                                drawdownModel!.startColorNaming {
                                    self.namingColorIndex = -1
                                    self.drawdownModel!.announceRow()
                                }
                                namingColorIndex = 0
                            }
                        } catch {
                            print("Unable to read file: \(error)")
                        }
                    }
                }
                .navigationTitle("All Drawdowns")
                .frame(minHeight: 50, maxHeight: 200)
                .onAppear { setState() }
                Spacer()
            }

            // ── Image display ────────────────────────────────────────
            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                ZStack {
                    if let ddImage = model.ddImage {
                        Image(uiImage: ddImage)
                            .resizable()
                            .interpolation(.none)
                            .frame(width: ddImage.size.width * CGFloat(scale),
                                   height: ddImage.size.height * CGFloat(scale))
                        if let hCursor = model.image.hCursor {
                            VStack {
                                Image(uiImage: hCursor)
                                    .resizable().opacity(0.5).scaledToFit()
                            }
                            .position(x: CGFloat(scale) * ddImage.size.width / 2,
                                      y: CGFloat(scale * model.image.hcPosition))
                        }
                        if let vCursor = model.image.vCursor {
                            VStack {
                                Image(uiImage: vCursor)
                                    .resizable().opacity(0.75).scaledToFit()
                            }
                            .position(x: CGFloat(model.image.vcPosition) * CGFloat(scale),
                                      y: CGFloat(scale) * ddImage.size.height / 2)
                        }
                    }
                }
            }
            .border(.blue, width: 5)
            .frame(maxWidth: .infinity)
            .padding()

            // ── Color mode UI ────────────────────────────────────────
            if let d = data, d.isColorMode {
                // Color naming
                if namingColorIndex >= 0 {
                    ColorNamingView(data: d, namingIndex: namingColorIndex)
                        .padding(.horizontal)
                }

                // Execution status
                ColorStatusView(data: d, waiting: waitingForGo, executing: executing)
                    .padding(.horizontal)

                // Manual buttons
                HStack(spacing: 20) {
                    Button {
                        drawdownModel!.move(delta: -1)
                    } label: {
                        Label("Previous", systemImage: "chevron.left")
                    }
                    .disabled(executing)

                    Button {
                        drawdownModel!.executeCurrentPass()
                    } label: {
                        Label("Go", systemImage: "play.fill")
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(waitingForGo ? Color.green : Color.gray)
                            .cornerRadius(10)
                    }
                    .disabled(!waitingForGo || executing)

                    Button {
                        drawdownModel!.move(delta: 1)
                    } label: {
                        Label("Next", systemImage: "chevron.right")
                    }
                    .disabled(executing)
                }
                .padding()

                HStack {
                    Text("Verb: \(speechRecognizer.verb)")
                }

            } else {
                // ── BW drawloom UI (unchanged) ───────────────────────
                Group {
                    if let d = data {
                        HStack {
                            Spacer()
                            Button {
                                model.upsideDown = true
                                d.upsideDown = model.upsideDown
                                drawdownModel!.extractDrawPlan(width: d.width, height: d.height, pixels: d.pixels)
                                drawdownModel!.updateImage()
                            } label: {
                                Image(systemName: "repeat.circle")
                            }
                            Text("Flip Image:")
                        }
                        .frame(maxWidth: .infinity).padding()

                        HStack {
                            Slider(value: $model.floatOffset, in: 1...100) {
                                Text("Offset")
                            } minimumValueLabel: { Text("1") } maximumValueLabel: { Text("100") }
                            onEditingChanged: { editing in
                                if !editing {
                                    d.floatOffset = model.floatOffset
                                    d.offset = Int(model.floatOffset)
                                    model.offset = Int(model.floatOffset)
                                    drawdownModel!.setOffset(offset: model.offset)
                                }
                            }
                            .background(Color.yellow).frame(width: 800, alignment: .leading)
                            .disabled(!canChangeOffset).id(canChangeOffset)
                            Spacer()
                            Text("Enable:")
                            Toggle("Enable:", isOn: $canChangeOffset).labelsHidden()
                        }
                        .frame(maxWidth: .infinity).padding()
                        Text("Offset set to \(Int(model.floatOffset))")

                        HStack {
                            Slider(value: $model.scale, in: 1...10, step: 1) {
                                Text("Scale")
                            } minimumValueLabel: { Text("2") } maximumValueLabel: { Text("20") }
                            onEditingChanged: { editing in
                                if !editing {
                                    d.scale = model.scale
                                    self.scale = Int(d.scale)
                                    drawdownModel!.updateImage()
                                }
                            }
                            .background(Color.red).frame(width: 800, alignment: .leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading).padding()
                        Text("Scale set to \(Int(2 * data!.scale))")
                    }
                }

                HStack {
                    Button("Next") {
                        drawdownModel!.move(delta: 1)
                        line = "PULLED: " + viewables.pulledLine
                    }
                    Button("Previous") {
                        drawdownModel!.move(delta: -1)
                        line = "PULLED: " + viewables.pulledLine
                    }
                    Text(line).font(.title)
                }
                HStack {
                    Text("Verb: \(speechRecognizer.verb)")
                    Text(viewables.pulledLine)
                }
            }
        }
        .sheet(isPresented: $showSettings, onDismiss: applySettings) {
            SettingsView(host: $settingsHost, port: $settingsPort)
        }
        // Sync color mode published state from model
        .onReceive(NotificationCenter.default.publisher(for: .colorModeStateChanged)) { note in
            if let info = note.userInfo {
                namingColorIndex = info["namingIndex"] as? Int ?? -1
                waitingForGo     = info["waitingForGo"] as? Bool ?? false
                executing        = info["executing"] as? Bool ?? false
            }
        }
    }
}

extension Notification.Name {
    static let colorModeStateChanged = Notification.Name("colorModeStateChanged")
}

