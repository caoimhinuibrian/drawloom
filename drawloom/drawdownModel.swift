//
//  drawdownModel.swift
//  drawloom
//
//  Created by Kevin O'Brien on 2/26/24.
//

import Foundation
import Speech
import SwiftUI
import SwiftData

//@Model
actor DrawdownModel: ObservableObject {
    private var viewables:DrawdownViewables
    private var pixels:[UInt8]?
    private var recognizer:SpeechRecognizer?
    private var width:Int = 0
    private var height:Int = 0
    private var upsideDown:Bool = false
    private var offset:Int
    private var imline:[[String]] = []
    private var upline:[[String]] = []
    private var downline:[[String]] = []
    private var drawDownLoaded: Bool = false
    private var currentLineNum: Int = 0
    private var releaseLine:String = ""
    private var drawLine:String = ""
    private var speaker:Speaker = Speaker.shared
    private var synthesizer = AVSpeechSynthesizer()
    private var utterancePosition:Int = 0
    enum UtteranceType:Int {
        case Release = 1, Draw, Pulled, Empty
    }
    private var utteranceType:UtteranceType = UtteranceType.Release
    private var restart: () -> Void = {() in }
    
    init(offset:Int, viewables:DrawdownViewables) {
        self.offset = offset
        self.viewables = viewables
    }
    
    private func setLineValues(pulls:String, up:String, down:String) {
        Task {
            viewables.pulledLine=pulls
            self.releaseLine=up
            self.drawLine=down
        }
    }
    
    
    nonisolated func setOffset(offset:Int) {
        Task {
            await setOffsetActually(offset:offset)
        }
    }
    
    func setOffsetActually(offset:Int) {
        self.offset=offset
    }
    
    nonisolated func setRecognizer(recognizer:SpeechRecognizer) {
        Task {
            await actualSetRecognizer(recognizer:recognizer)
        }
    }
    
    func actualSetRecognizer(recognizer:SpeechRecognizer) {
        self.recognizer=recognizer
    }
    
    func move(delta:Int) {
        if (currentLineNum+delta<height) && (currentLineNum+delta>=0) {
            currentLineNum+=delta
            updateImage(width:width,height:height,imageData:pixels!)
            setCurrentLineValues()
        }
        speaker.speak(wordsToSpeak:"OK")
    }

    func checkUtteranceStatus() -> (String, [String]) {
        var prefix:String = ""
        var range:[String] = []
        switch(utteranceType) {
        case .Release:
            prefix = "Release"
            range = upline[currentLineNum]
        case .Draw:
            prefix = "Draw"
            range = downline[currentLineNum]
        case .Pulled:
            prefix = "Pulled"
            range = imline[currentLineNum]
        case .Empty:
            prefix = "End of pick"
            range = [""]
        }
        if (utterancePosition >= range.count) && (utteranceType != .Empty)  {
            utteranceType = UtteranceType(rawValue: utteranceType.rawValue+1)!
            utterancePosition = 0
            switch(utteranceType) {
            case .Release:
                prefix = "Release"
                range = upline[currentLineNum]
            case .Draw:
                prefix = "Draw"
                range = downline[currentLineNum]
            case .Pulled:
                prefix = "Pulled"
                range = imline[currentLineNum]
            case .Empty:
                prefix = "End of pick"
                range = [""]
            }
        }
        return(prefix,range)
    }
    
    func sayNext() {
        var prefix:String = ""
        var range:[String] = []
        (prefix,range) = checkUtteranceStatus()
        let wordsToSpeak:String = prefix+range[utterancePosition]
        speaker.speak(wordsToSpeak:wordsToSpeak)
        
        /*
        let utterance = AVSpeechUtterance(string: wordsToSpeak)
        // Configure the utterance.
        utterance.rate = 0.57
        utterance.pitchMultiplier = 0.8
        utterance.postUtteranceDelay = 0.2
        utterance.volume = 0.8


        // Retrieve the Irish voice.
        let voice = AVSpeechSynthesisVoice(language: "en-IE")


        // Assign the voice to the utterance.
        utterance.voice = voice
        // Create a speech synthesizer.


        // Tell the synthesizer to speak the utterance.
        synthesizer.speak(utterance)
         */
        utterancePosition+=1
    }
    
    nonisolated func sendVerb(verb:String) {
        //self.restart = restart
        switch(verb) {
        case "Next","next":
            Task {
                await move(delta:1)
            }
        case "Previous","previous":
            Task {
                await move(delta:-1)
            }
        case "Skip","skip":
            Task {
                await move(delta:10)
            }
        case "Go","go":
            Task {
                await sayNext()
            }

        default: break
        }
    }
    
    private func setCurrentLineValues() {
        var pulls: String = ""
        var ups: String = ""
        var downs: String = ""
        for s in imline[currentLineNum] {
            pulls+=(s+", ")
        }
        for s in upline[currentLineNum] {
            ups+=(s+", ")
        }
        for s in downline[currentLineNum] {
            downs+=(s+", ")
        }
        setLineValues(pulls:pulls, up:ups, down:downs)
    }
    
    private func buildTextRow(pick: [UInt8], offset: Int) -> [String] {
        var col:Int = 0
        var line:[String] = []
        let width = pick.count
        
        while col < width {
            if pick[col]==0 {
                let start: Int = col
                var stop: Int  = col
                while stop < width {
                    if stop == width-1 {
                        break
                    }
                    if pick[stop+1] > 0 {
                        break
                    } else {
                        stop+=1
                    }
                }
                col = stop+1
                if start==stop {
                    line.append(String(start+offset))
                } else {
                    line.append(String(start+offset)+" to "+String(stop+offset))
                }
            } else {
                col+=1
            }
        }
        return line
    }
    
    private func extractDrawPlan(width: Int, height: Int, pixels: [UInt8], offset: Int = 1) {
        var img_array: [[UInt8]] = [[UInt8]](repeating: [UInt8](repeating: 0, count: width), count: height)
        var previous: [UInt8] = [UInt8](repeating:255,count:width)
        var ups:   [[UInt8]] = [[UInt8]](repeating: [UInt8](repeating: 255, count: width), count: height)
        var downs: [[UInt8]] = [[UInt8]](repeating: [UInt8](repeating: 255, count: width), count: height)
        
        for row in 0...height-1 {
            for col in  0...width-1 {
                let colx = width-1-col // drawcords are numbered right to left
                if upsideDown {
                    img_array[row][col] = pixels[row*width+colx]
                } else {
                    let urow = height-1-row // weave from bottom up
                    img_array[row][col] = pixels[urow*width+colx]
                }
            }
        }

        for row in 0...height-1 {
            for col in 0...width-1 {
                if img_array[row][col] != previous[col] {
                    if img_array[row][col]>0 {
                        ups[row][col] = 0
                    } else {
                        downs[row][col] = 0
                    }
                }
                previous[col] = img_array[row][col]
            }
        }

        for row in 0...height-1 {
            imline.append([])
            upline.append([])
            downline.append([])

            imline[row] = buildTextRow(pick: img_array[row], offset: offset)
            upline[row] = buildTextRow(pick: ups[row], offset: offset)
            downline[row] = buildTextRow(pick: downs[row], offset: offset)
        }

    }
    func updateImage(width:Int,height:Int,imageData: [UInt8]) {
        let lineNum = upsideDown ? currentLineNum : height-currentLineNum-1
        let startPos = lineNum*width
        let endPos = startPos+width-1
        var pixels = imageData
        for index in startPos...endPos {
            if pixels[index] == 255 {
                pixels[index]=128
            }
        }
        setImg(UIImage(pixels: pixels,width: width,height: height)!)
    }
    
    
    func processBitmapBody(selectedFile: URL) {
        do {
            if selectedFile.startAccessingSecurityScopedResource() {
                guard let img = UIImage(data: try Data(contentsOf: selectedFile)) else { return }
                defer { selectedFile.stopAccessingSecurityScopedResource() }
                let imageTuple = img.pixelData()
                let imageWidth = imageTuple.0
                let imageHeight = imageTuple.1
                let imageData = imageTuple.2!
                extractDrawPlan(width: imageWidth,height: imageHeight, pixels: imageData)
                self.pixels=imageData
                self.width=imageWidth
                self.height=imageHeight
                updateImage(width:imageWidth,height:imageHeight,imageData:imageData)
                drawDownLoaded = true
            } else {
                // Handle denied access
            }
        } catch {
            // Handle failure.
            print("Unable to read file contents")
            print(error.localizedDescription)
        }

    }

    nonisolated func loadDrawdown(selectedFile: URL)  {
        Task {
            await processBitmapBody(selectedFile: selectedFile)
        }
    }
    
    nonisolated private func setImg(_ img:UIImage) {
        Task { @MainActor in
            await viewables.img=img
        }
    }
}

extension UIImage {
    func pixelData() -> (Int,Int,[UInt8]?) {
        //func pixelData() -> [[UInt8]]? {
        let size = self.size
        let dataSize = size.width * size.height
        var pixelData = [UInt8](repeating: 0, count: Int(dataSize))
        //var pixelData: [[UInt8]]
        //pixelData = Array(repeating: Array(repeating: 0, count: Int(size.width)), count: Int(size.height))
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let context = CGContext(data: &pixelData,
                                width: Int(size.width),
                                height: Int(size.height),
                                bitsPerComponent: 8,
                                bytesPerRow: Int(size.width),
                                space: colorSpace,
                                //bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
                                bitmapInfo: CGImageAlphaInfo.none.rawValue)
        guard let cgImage = self.cgImage else { return (0,0,nil) }
        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))

        return (Int(size.width),Int(size.height),pixelData)
    }
 }

extension UIImage {
    convenience init?(pixels: [UInt8], width: Int, height: Int) {
        guard width > 0 && height > 0, pixels.count == width * height else { return nil }
        var data = pixels
        guard let providerRef = CGDataProvider(data: Data(bytes: &data, count: data.count) as CFData)
            else { return nil }
        guard let cgim = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: providerRef,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent)
        else { return nil }
        self.init(cgImage: cgim)
    }
}
