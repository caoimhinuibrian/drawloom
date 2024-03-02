//
//  ContentView.swift
//  drawloom
//
//  Created by Kevin O'Brien on 2/20/24.
//

//import Foundation
//import AVFoundation
import SwiftUI
import Speech

//var line = "first line"
struct ContentView: View {
    @StateObject var speechRecognizer:SpeechRecognizer = SpeechRecognizer()
    @StateObject var drawdownModel:DrawdownModel
    @State private var viewModel = ViewModel()
    
    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()

    init() {
        _drawdownModel = StateObject(wrappedValue: DrawdownModel(offset:1))
    }
    
    var body: some View {
        VStack {
            ScrollView([.horizontal, .vertical], showsIndicators: false) {
                Image(uiImage: drawdownModel.img)
                    .resizable()
                    .frame(width: drawdownModel.img.size.width, height: drawdownModel.img.size.height)
                    .scaleEffect(self.scale)
                    .frame (
                        width: drawdownModel.img.size.width * self.scale,
                        height: drawdownModel.img.size.height * self.scale
                        )
                    

                
            }
            
            TextField("Offset Value", value: $viewModel.offset, formatter: Self.formatter)
            
            Button(action: {
                recordButtonAction()
            }
            ) {
                Text($viewModel.isRecording ? "Stop Recording" : "Start Recording")
            }
            //.onAppear() {
            //    setupSpeech()
            //}
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .clipShape(Capsule())
            
            Text("Current Verb is \(speechRecognizer.verb)")
            Text(recognizedText)
                .font(.title)
            HStack {
                Button(action: { isImporting = true}, label: {
                    Text("Load File")
                })
                //Text(document.input)
            }
            .padding()
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [.image],
                //allowedContentTypes: [.plainText],
                allowsMultipleSelection: false
            ) { result in
                do {
                    guard let selectedFile: URL = try result.get().first else { return }
                    //drawdownModel.setRecognizer(recognizer: speechRecognizer)
                    drawdownModel.loadDrawdown(selectedFile: selectedFile)
                    speechRecognizer.setDrawdown(drawdown:drawdownModel)
                    speechRecognizer.setDelegate()
                    speechRecognizer.startTranscribing()
                } catch {
                    // Handle failure.
                    print("Unable to read file contents")
                    print(error.localizedDescription)
                }
            }
            HStack {
                Button("Next") {
                    Task {
                        await drawdownModel.move(delta:1)
                        line = "PULLED: "+drawdownModel.pulledLine
                    }
                }
                Button("Previous") {
                    Task {
                        await drawdownModel.move(delta:-1)
                        line = "PULLED: "+drawdownModel.pulledLine
                    }
                }
                Text(line).font(.title)
            }
            .padding()
            VStack {
                Text(drawdownModel.pulledLine)
                Text(spoken)
                Text(progress)
                Text(speechStatus)
            }
            .padding()
        }
    }
    

    @MainActor func recordButtonAction() {
         if isRecording {
            print("stop record button pressed")
            isRecording = false
            speechRecognizer.resetTranscript()
        } else {
            print("record button pushed")
            isRecording = true
            speechRecognizer.startTranscribing()
            spoken = speechRecognizer.getTranscript()
        }
    }

}
//#Preview {
//    ContentView()
//}
