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
import SwiftData

struct ExecuteCode : View {
    init( _ codeToExec: () -> () ) {
        codeToExec()
    }
    
    var body: some View {
        EmptyView()
    }
}

struct DrawdownView:View {
    var drawdown:DrawdownData
    init(drawdown:DrawdownData) {
        self.drawdown=drawdown
    }
    var body: some View {
        VStack {
            Text(drawdown.selectedFile)
        }
    }
}

struct MyImage:View {
    var data:DrawdownData
    var p:[UInt8]
    var h:Int
    var w:Int
    var unused:Int
    init(data:DrawdownData) {
        self.data=data
        p=data.pixels
        h=data.height
        w=data.width
        unused=0
    }
    var body: some View {
        let _ =  Self._printChanges()
        VStack {
            ScrollView([.horizontal, .vertical]/*, showsIndicators: false*/) {
                Image(uiImage: UIImage(pixels: data.pixels,width: data.width,height: data.height)!)
                    .resizable()
                    .frame(width: CGFloat(data.width), height: CGFloat(data.height))
                    .frame (
                        width: CGFloat(data.width),
                        height: CGFloat(data.height)
                        )
            }
            .border(.red, width: 5)
}
    }
}

//var line = "first line"
struct ContentView: View {
    @Environment(\.modelContext) var context
    var speechRecognizer:SpeechRecognizer = SpeechRecognizer()
    @State var data:DrawdownData? = nil
    @State var viewables:DrawdownViewables = DrawdownViewables()
    
    @State var drawdownModel:DrawdownModel?=nil
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
    @State var scale: CGFloat = 1
    @State var offset: Int = 1
    @State var floatOffset:CGFloat = 1.0
    @StateObject var model:MyViewModel = MyViewModel()
    @State var w:Int=2
    @State var h:Int=8
    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()
    
    init() {
    }
    
    func setState() {
        if allDrawdowns.count > 0 {
            selectDrawdown(selected:allDrawdowns[0])
        }
        let vwables = DrawdownViewables()
        let model = DrawdownModel(offset:1, viewables:viewables,viewmodel:model)
        self.drawdownModel = model
        viewables = vwables
    }
    
    func deleteDrawdowns(_ indexSet: IndexSet) {
        for index in indexSet {
            let drawdown = allDrawdowns[index]
            context.delete(drawdown)
        }
    }
    
    func selectDrawdown(selected:DrawdownData) {
        print(selected.selectedFile)
        let viewables = DrawdownViewables()
        self.viewables = viewables
        self.drawdownModel = DrawdownModel(drawdownData:selected, viewables:viewables, viewmodel:model)
        data = selected
        data!.timestamp = Date()
        model.ddImage = makeImage(pixels: data!.pixels,width: data!.width,height: data!.height)!
        model.scale=data!.scale
        self.scale = model.scale
        model.offset=data!.offset
        model.floatOffset=data!.floatOffset
        drawdownModel!.setOffset(offset:model.offset)
        w = data!.width
        h = data!.height
        speechRecognizer.setDrawdown(drawdown:drawdownModel!)
        speechRecognizer.setDelegate()
        speechRecognizer.startTranscribing()
    }
    
    func makeImage(pixels:[UInt8],width:Int, height:Int) -> UIImage? {
        let img = UIImage(pixels: pixels,width: width,height: height)
        return img
    }
    
    @Query(sort: \DrawdownData.timestamp, order: .reverse) var allDrawdowns: [DrawdownData]
    //@Query var allDrawdowns: [DrawdownData]
    var body: some View {
        VStack {
            HStack {
                Spacer()
                Text("      DRAWDOWNS    ").font(.title)
                Spacer()
                NavigationStack {
                    List() {
                        //}
                        ForEach(allDrawdowns) { drawdown in
                            VStack {
                                Text(drawdown.selectedFile).onTapGesture {selectDrawdown(selected:drawdown)}
                            }
                        }
                        .onDelete(perform: deleteDrawdowns)
                    }
                    .frame(minWidth: 100, maxWidth: 500, minHeight: 50, maxHeight: 200)
                    .toolbar{
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
                        //allowedContentTypes: [.plainText],
                        allowsMultipleSelection: false
                    ) { result in
                        do {
                            guard let selectedFile: URL = try result.get().first else { return }
                            drawdownModel!.loadDrawdown(selectedFile: selectedFile)
                            data=drawdownModel!.data
                            context.insert(data!)
                            model.ddImage = makeImage(pixels: data!.pixels,width: data!.width,height: data!.height)!
                            model.scale=data!.scale
                            model.offset=data!.offset
                            model.floatOffset=data!.floatOffset
                            drawdownModel!.setOffset(offset:model.offset)
                            
                            w = data!.width
                            h = data!.height
                            speechRecognizer.setDrawdown(drawdown:drawdownModel!)
                            speechRecognizer.setDelegate()
                            speechRecognizer.startTranscribing()
                        } catch {
                            // Handle failure.
                            print("Unable to read file contents")
                            print(error.localizedDescription)
                        }
                    }
                    
                }
                .navigationTitle("All Drawdowns")
                .frame(minHeight: 50, maxHeight: 200)
                .onAppear{setState()}
                Spacer()
            }
            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                //                    VStack(alignment: .leading) {
                Image(uiImage: model.ddImage)
                    .resizable()
                    .frame(width: model.ddImage.size.width * self.scale, height: model.ddImage.size.height * self.scale)
                //                            .scaleEffect(self.scale)
                //                    }
                //                .border(.red, width: 2)
                //                Image(uiImage: model.ddImage)
                //                    .resizable()
                //                    .frame(width: 200,height: 220)
                //                    .scaleEffect(self.scale)
                /*
                 .frame (
                 width: CGFloat(w) * self.scale,
                 height: CGFloat(h) * self.scale
                 )
                 */
            }
            .border(.blue, width: 5)
            
            
            Group {
                if let d = data {
                    Slider(
                        value: $model.floatOffset,
                        in: 1...100
                    )
                    {
                        Text("Offset")
                    } minimumValueLabel: {
                        Text("0")
                    } maximumValueLabel: {
                        Text("100")
                    } onEditingChanged: { editing in
                        data!.floatOffset = model.floatOffset
                        data!.offset = Int(model.floatOffset)
                        model.offset = Int(model.floatOffset)
                        drawdownModel!.setOffset(offset:offset)
                    }.background(Color.yellow).frame(width:800)
                    Text("Offset set to \(Int(model.floatOffset))")
                    
                    Slider(
                        value: $model.scale,
                        in: 1...20
                    ) {
                        Text("Scale")
                    } minimumValueLabel: {
                        Text("0")
                    } maximumValueLabel: {
                        Text("20")
                    } onEditingChanged: { editing in
                        data!.scale = model.scale
                        self.scale = model.scale
                    }
                    .background(Color.red).frame(width:800)
                    Text("Scale set to \(model.scale)")
                }
            }
            
            HStack {
                Button("Next") {
                    drawdownModel!.move(delta:1)
                    line = "PULLED: "+viewables.pulledLine
                }
                Button("Previous") {
                    drawdownModel!.move(delta:-1)
                    line = "PULLED: "+viewables.pulledLine
                }
                Text(line).font(.title)
            }
            HStack {
                Text("Verb: \(speechRecognizer.verb)")
                //Text(recognizedText)
                //    .font(.title)
                Text(viewables.pulledLine)
            }
        }
    }
    
}
//#Preview {
//    ContentView()
//}
