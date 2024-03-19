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

struct ContentView: View {
    @Environment(\.modelContext) var context
    var speechRecognizer:SpeechRecognizer = SpeechRecognizer()
    @State var data:DrawdownData? = nil
    @State var viewables:DrawdownViewables = DrawdownViewables()
    
    @State var drawdownModel:DrawdownModel?=nil
    @State var line = ""
    @State var isImporting: Bool = false
    @State var canChangeOffset:Bool = false
    @State var recognizedText = ""
    @State var speechEnabled: Bool = false
    @State var recognizerTask:SFSpeechRecognitionTask?
    @State var offset: Int = 1
    @State var floatOffset:CGFloat = 1.0
    @StateObject var model:MyViewModel = MyViewModel()
    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()
    
    init() {
    }
    
    func setState() {
        let vwables = DrawdownViewables()
        viewables = vwables
        if allDrawdowns.count > 0 {
            selectDrawdown(selected:allDrawdowns[0])
        } else {
            self.drawdownModel = DrawdownModel(offset:1, viewables:viewables,viewmodel:model)
        }
    }
    
    func deleteDrawdowns(_ indexSet: IndexSet) {
        for index in indexSet {
            let drawdown = allDrawdowns[index]
            context.delete(drawdown)
        }
    }
    
    func selectDrawdown(selected:DrawdownData) {
        print(selected.selectedFile)
        print("selected: \(selected)")
        selected.display()
        let viewables = DrawdownViewables()
        self.viewables = viewables
        self.drawdownModel = DrawdownModel(drawdownData:selected, viewables:viewables, viewmodel:model)
        data = selected
        print("data: \(data)")
        data!.display()
        data!.timestamp = Date()
        model.ddImage = makeImage(pixels: data!.pixels,width: data!.width,height: data!.height)!
        model.scale=data!.scale
        model.offset=data!.offset
        model.upsideDown = data!.upsideDown
        let o = data!.offset
        model.floatOffset=data!.floatOffset
        drawdownModel!.setOffset(offset:model.offset)
        speechRecognizer.setDrawdown(drawdown:drawdownModel!)
        speechRecognizer.setDelegate()
        speechRecognizer.startTranscribing()
    }
    
    func makeImage(pixels:[UInt8],width:Int, height:Int) -> UIImage? {
        let img = drawdownModel!.updateImage(width: width,height: height,imageData: pixels)
        return img
    }
    
    @Query(sort: \DrawdownData.timestamp, order: .reverse) var allDrawdowns: [DrawdownData]
    var body: some View {
        VStack {
            HStack {
                Spacer()
                Text("      DRAWDOWNS    ").font(.title)
                Spacer()
                NavigationStack {
                    List() {
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
                            model.upsideDown=data!.upsideDown
                            drawdownModel!.setOffset(offset:model.offset)
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
                Image(uiImage: model.ddImage)
                    .resizable()
                    .frame(width: model.ddImage.size.width, height: model.ddImage.size.height)

            }
            .border(.blue, width: 5)
            
            
            Group {
                if let d = data {
                    HStack {
                        Spacer()
                        Text("Flip Image:")
                        Toggle("Flip:",isOn: $model.upsideDown).labelsHidden()
                            .onChange(of:model.upsideDown) {
                                d.upsideDown = model.upsideDown
                                drawdownModel!.extractDrawPlan(width: d.width,height: d.height, pixels: d.pixels)
                                drawdownModel!.updateImage()
                            }
                    }


                    HStack {
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
                            if !editing {
                                d.floatOffset = model.floatOffset
                                d.offset = Int(model.floatOffset)
                                d.display()
                                data!.display()
                                model.offset = Int(model.floatOffset)
                                drawdownModel!.setOffset(offset:model.offset)
                                drawdownModel!.extractDrawPlan(width: d.width,height: d.height, pixels: d.pixels)
                            }
                        }
                        .background(Color.yellow).frame(width:800,alignment:.leading)
                        .disabled(!canChangeOffset)
                        .id(canChangeOffset)
                        Spacer()
                        Text("Enable:")
                        Toggle("Enable:",isOn: $canChangeOffset).labelsHidden()
                    }.frame(width:1100)
                    
                    Text("Offset set to \(Int(model.floatOffset))")
                    
                    HStack {
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
                            if !editing {
                                d.scale = model.scale
                                drawdownModel!.updateImage()
                            }
                        }
                        .background(Color.red).frame(width:800,alignment:.leading)
                    }.frame(width:1100,alignment:.leading)
                    
                    Text("Scale set to \(Int(data!.scale))")
                    
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
                Text(viewables.pulledLine)
            }
        }
    }
    
}
//#Preview {
//    ContentView()
//}
