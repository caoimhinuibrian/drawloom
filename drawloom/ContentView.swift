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
    @State var line = ""
    @State var spoken = "nothing yet"
    @State var progress = "uninitialized"
    @State var speechStatus = "not requested"
    @State var document: InputDocument = InputDocument(input: "")
    @State var isImporting: Bool = false
    @State var isRecording = false
    @State var recognizedText = ""
    @State var speechEnabled: Bool = false
    @State var recognizerTask:SFSpeechRecognitionTask?
    @State var img:UIImage = UIImage()
    @State var scale: CGFloat = 6
    @State var offset: Int = 1
    @State var floatOffset = 1.0

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
            Slider(
                value: $floatOffset,
                in: 1...100
            )
            {
                Text("Offset")
            } minimumValueLabel: {
                Text("0")
            } maximumValueLabel: {
                Text("100")
            } onEditingChanged: { editing in
                offset = Int(floatOffset)
                drawdownModel.setOffset(offset:offset)
            }.background(Color.yellow).frame(width:800)
            Text("Offset set to \(offset)")
            
            Slider(
                value: $scale,
                in: 1...20
            ) {
                Text("Scale")
            } minimumValueLabel: {
                Text("0")
            } maximumValueLabel: {
                Text("20")
            }.background(Color.red).frame(width:800)
            Text("Scale set to \(scale)")
            

            TextField("Offset Value", value: $offset, formatter: Self.formatter)
            
            /*Button(action: {
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
            */
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
