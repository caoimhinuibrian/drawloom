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
    @State var line = ""
    @State var spoken = "nothing yet"
    @State var progress = "uninitialized"
    @State var speechStatus = "not requested"
    @State private var document: InputDocument = InputDocument(input: "")
    @State private var isImporting: Bool = false
    @State private var isRecording = false
    @State private var recognizedText = ""
    @State private var speechEnabled: Bool = false
    @State private var recognizerTask:SFSpeechRecognitionTask?
    @StateObject var speechRecognizer:SpeechRecognizer = SpeechRecognizer()
    @StateObject var drawdownModel:DrawdownModel = DrawdownModel()
    @State private var img:UIImage = UIImage()
    @State private var scale: CGFloat = 6
    
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
            Text("Say 'hello' or 'goodbye'")
                .font(.title)
            
            Button(action: {
                recordButtonAction()
            }
            ) {
                Text(isRecording ? "Stop Recording" : "Start Recording")
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
                    speechRecognizer.startTranscribing()
                } catch {
                    // Handle failure.
                    print("Unable to read file contents")
                    print(error.localizedDescription)
                }
            }
            HStack {
                Button("Next") {
                    advance()
                    line = drawdownModel.pulledLine
                }
                Button("Previous") {
                    retreat()
                    line = drawdownModel.pulledLine
                }
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
