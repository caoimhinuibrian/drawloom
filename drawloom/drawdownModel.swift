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
//
// =============================================================================

import Foundation
import Speech
import SwiftUI
import SwiftData

class DrawdownModel: ObservableObject {
    var data:DrawdownData = DrawdownData()
    var image:DrawdownImage = DrawdownImage()
    private var viewables:DrawdownViewables?
    private var recognizer:SpeechRecognizer?
    private var speaker:Speaker = Speaker.shared
    private var synthesizer = AVSpeechSynthesizer()
    private var viewmodel:MyViewModel
    enum UtteranceType:Int {
        case Release = 1, Draw, Pulled, Empty
    }
    private var utteranceType:UtteranceType = UtteranceType.Release
    private var restart: () -> Void = {() in }
    
    init(offset:Int, viewables:DrawdownViewables,viewmodel:MyViewModel) {
        data.offset = offset
        self.viewables = viewables
        self.viewmodel = viewmodel
        utteranceType = UtteranceType.Release
    }
    
    init(drawdownData:DrawdownData, viewables:DrawdownViewables,viewmodel:MyViewModel) {
        /*
        let speechVoices = AVSpeechSynthesisVoice.speechVoices()
        speechVoices.forEach { (voice) in
          print("**********************************")
          print("Voice identifier: \(voice.identifier)")
          print("Voice language: \(voice.language)")
          print("Voice name: \(voice.name)")
          print("Voice quality: \(voice.quality.rawValue)") // Compact: 1 ; Enhanced: 2
        }*/
        data = drawdownData
        self.viewables=viewables
        self.viewmodel = viewmodel
        utteranceType = UtteranceType(rawValue: data.utteranceRawValue)!
    }
    
    private func setLineValues(pulls:String, up:String, down:String) {
        Task {
            viewables!.pulledLine=pulls
            data.releaseLine=up
            data.drawLine=down
        }
    }
    
    
    func setOffset(offset:Int) {
        let o = offset
        data.offset=offset
        //extractDrawPlan(width: data.width,height: data.height, pixels: data.pixels)
    }
    
    func move(delta:Int) {
        if (data.currentLineNum+delta<data.height) && (data.currentLineNum+delta>=0) {
            data.currentLineNum+=delta
            setCurrentLineValues()
            utteranceType = UtteranceType.Release
            data.utteranceRawValue = utteranceType.rawValue
            data.utterancePosition = 0
            data.display()
            updateImage()
        }
        speaker.speak(wordsToSpeak:"OK")
    }

    func notRecognized() {
        speaker.speak(wordsToSpeak:"I don't recognize that verb, sorry!")
    }
    
    func getUtterance() -> String {
        var utterance:String = ""
        var prefix:String = ""
        var ustart:[Int] = [0]
        var ustop:[Int] = [0]
        
        print("line \(data.currentLineNum)")
        switch(utteranceType) {
        case .Release:
            prefix = "Release "
            ustart = data.uStart[data.currentLineNum][UtteranceType.Release.rawValue-1]
            ustop = data.uStop[data.currentLineNum][UtteranceType.Release.rawValue-1]
        case .Draw:
            prefix = "Draw "
            ustart = data.uStart[data.currentLineNum][UtteranceType.Draw.rawValue-1]
            ustop = data.uStop[data.currentLineNum][UtteranceType.Draw.rawValue-1]
        case .Pulled:
            prefix = "Active cords  "
            ustart = data.uStart[data.currentLineNum][UtteranceType.Pulled.rawValue-1]
            ustop = data.uStop[data.currentLineNum][UtteranceType.Pulled.rawValue-1]
        case .Empty:
            ustart=[0]
            ustop=[0]
        }
        
        if data.utterancePosition <= ustart.count-1 {
            if ustart[data.utterancePosition]==ustop[data.utterancePosition] {
                utterance = String(ustart[data.utterancePosition]+data.offset)
            } else {
                utterance = String(ustart[data.utterancePosition]+data.offset) + " to " + String(ustop[data.utterancePosition]+data.offset)
            }
            utterance = prefix + utterance
            data.utterancePosition += 1
            data.display(from:"after update")
            if data.utterancePosition == ustart.count {
                data.utterancePosition -= 1
                utterance += " section is finished"            }
        }
        return utterance
    }
    

    func sayNext() {
        updateImage()
        let utterance = getUtterance()
        speaker.speak(wordsToSpeak:utterance)
        //updateImage()
    }
    
    func startDraws() {
        utteranceType = UtteranceType.Draw
        data.utterancePosition = 0
        data.utteranceRawValue = utteranceType.rawValue
        data.display()
        updateImage()
        speaker.speak(wordsToSpeak:"OK")
    }
    
    func startReleases() {
        utteranceType = UtteranceType.Release
        data.utterancePosition = 0
        data.utteranceRawValue = utteranceType.rawValue
        data.display()
        updateImage()
        speaker.speak(wordsToSpeak:"OK")
    }
    
    func startCheck() {
        utteranceType = UtteranceType.Pulled
        data.utterancePosition = 0
        data.utteranceRawValue = utteranceType.rawValue
        data.display()
        updateImage()
        speaker.speak(wordsToSpeak:"OK")
    }
    
    func speakHelpText() {
        speaker.speak(wordsToSpeak:"Commands that you can use are Draws Releases Check Go Next Previous Repeat and Help")
    }
    
    func sendVerb(verb:String) {
        switch(verb) {
        case "Help","help":
            speakHelpText()
        case "Draws","draws","Draw","draw":
            startDraws()
        case "Releases","releases","Release","release":
            startReleases()
        case "Check","check":
            startCheck()
        case "Next","next":
            move(delta:1)
        case "Previous","previous":
            move(delta:-1)
        case "Skip","skip":
            move(delta:10)
        case "Go","go":
            sayNext()
        case "Repeat","repeat":
            data.utterancePosition-=1
            data.display()
            sayNext()
        default:
            notRecognized()
        }
    }
    
    private func setCurrentLineValues() {
        var pulls: String = ""
        var ups: String = ""
        var downs: String = ""
        for s in data.imline[data.currentLineNum] {
            pulls+=(s+", ")
        }
        for s in data.upline[data.currentLineNum] {
            ups+=(s+", ")
        }
        for s in data.downline[data.currentLineNum] {
            downs+=(s+", ")
        }
        setLineValues(pulls:pulls, up:ups, down:downs)
    }
    
    private func buildTextRow(pick: [UInt8]) -> ([String],[Int],[Int]) {
        var col:Int = 0
        var line:[String] = []
        var uStart:[Int] = []
        var uStop:[Int] = []
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
                    line.append(String(start+data.offset))
                    uStart.append(start)
                    uStop.append(start)
                } else {
                    line.append(String(start+data.offset)+" to "+String(stop+data.offset))
                    uStart.append(start)
                    uStop.append(stop)
                }
            } else {
                col+=1
            }
        }
        return (line,uStart,uStop)
    }
    
    func extractDrawPlan(width: Int, height: Int, pixels: [UInt8]) {
        var img_array: [[UInt8]] = [[UInt8]](repeating: [UInt8](repeating: 0, count: width), count: height)
        var previous: [UInt8] = [UInt8](repeating:255,count:width)
        var ups:   [[UInt8]] = [[UInt8]](repeating: [UInt8](repeating: 255, count: width), count: height)
        var downs: [[UInt8]] = [[UInt8]](repeating: [UInt8](repeating: 255, count: width), count: height)
        
        for row in 0...height-1 {
            for col in  0...width-1 {
                let colx = width-1-col // drawcords are numbered right to left
                if data.upsideDown {
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
            data.imline.append([])
            data.upline.append([])
            data.downline.append([])
            data.uStart.append([]) //row
            data.uStart[row].append([]) //utterance types
            data.uStart[row].append([])
            data.uStart[row].append([])
            data.uStop.append([]) //row
            data.uStop[row].append([]) //utterance types
            data.uStop[row].append([])
            data.uStop[row].append([])
            let imTuple = buildTextRow(pick: img_array[row])
            data.imline[row] = imTuple.0
            data.uStart[row][UtteranceType.Pulled.rawValue-1] = imTuple.1
            data.uStop[row][UtteranceType.Pulled.rawValue-1] = imTuple.2

            let upsTuple = buildTextRow(pick: ups[row])
            data.upline[row] = upsTuple.0
            data.uStart[row][UtteranceType.Release.rawValue-1] = upsTuple.1
            data.uStop[row][UtteranceType.Release.rawValue-1] = upsTuple.2

            let downsTuple = buildTextRow(pick: downs[row])
            data.downline[row] = downsTuple.0
            data.uStart[row][UtteranceType.Draw.rawValue-1] = downsTuple.1
            data.uStop[row][UtteranceType.Draw.rawValue-1] = downsTuple.2
        }

    }
    
    func getPixelColor(pixels:inout [UInt8],row:Int,col:Int,width:Int,lineNum:Int,flipped:Bool,height:Int) -> [UInt8] {
        var color:[UInt8] = [255,255,255] // default color is white
        var uc:[UInt8] = [192,224,255]
        
        var woven:Bool = (flipped && (row < lineNum)) || (!flipped && (row > lineNum))
        if pixels[row*width+col] == 0 {
            if woven {
                color[0]=0
                color[1]=0
                color[2]=0
            } else {
                color[0]=128
                color[1]=128
                color[2]=128
            }
        } else {
            if row == lineNum {
                color[0]=240
                color[1]=192
                color[2]=192
            }
        }
        return color
    }
    
    func updateImage() {
        viewmodel.ddImage = image.updateImage(with: data)
    }
    
    func processBitmapBody(selectedFile: URL) {
        data = DrawdownData()
        data.selectedFile = selectedFile.lastPathComponent
        do {
            if selectedFile.startAccessingSecurityScopedResource() {
                guard let img = UIImage(data: try Data(contentsOf: selectedFile)) else { return }
                defer { selectedFile.stopAccessingSecurityScopedResource() }
                let imageTuple = img.pixelData()
                let imageWidth = imageTuple.0
                let imageHeight = imageTuple.1
                let imageData = imageTuple.2!
                extractDrawPlan(width: imageWidth,height: imageHeight, pixels: imageData)
                data.pixels=imageData
                data.width=imageWidth
                data.height=imageHeight
                
                updateImage()
                data.drawDownLoaded = true
            } else {
                // Handle denied access
            }
        } catch {
            // Handle failure.
            print("Unable to read file contents")
            print(error.localizedDescription)
        }

    }

    func loadDrawdown(selectedFile: URL)  {
        processBitmapBody(selectedFile: selectedFile)
    }
    
    private func setImg(_ img:UIImage) {
        viewables!.img=img
    }
}

extension UIImage {
    func pixelData() -> (Int,Int,[UInt8]?) {
        let size = self.size
        let dataSize = size.width * size.height
        var pixelData = [UInt8](repeating: 0, count: Int(dataSize))
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let context = CGContext(data: &pixelData,
                                width: Int(size.width),
                                height: Int(size.height),
                                bitsPerComponent: 8,
                                bytesPerRow: Int(size.width),
                                space: colorSpace,
                                bitmapInfo: CGImageAlphaInfo.none.rawValue)
        guard let cgImage = self.cgImage else { return (0,0,nil) }
        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))

        return (Int(size.width),Int(size.height),pixelData)
    }
 }

extension UIImage { // monochrome
    convenience init?(pixels: [UInt8], width: Int, height: Int) {
        guard width > 0 && height > 0, pixels.count == width * height else { return nil }
        var data = pixels
        //guard let providerRef = CGDataProvider(data: Data(bytes: pixels, count: pixels.count) as CFData)
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
            shouldInterpolate: false,
            intent: .defaultIntent)
        else { return nil }
        self.init(cgImage: cgim)
    }
}

 extension UIImage { // color
     convenience init?(pixels: [[UInt8]], width: Int, height: Int) {
         guard width > 0 && height > 0, pixels.count == width * height else { return nil }
         var data = pixels
         var scale = 1
         var rgbdata = [UInt8](repeating: 0, count: width*height*3)

         for i in 0...width*height-1 {
             for j in 0...2 {
                 rgbdata[i*3+j]=pixels[i][j]
             }
         }
          guard let providerRef = CGDataProvider(data: Data(bytes: &rgbdata, count: rgbdata.count) as CFData)

         else { return nil }
         guard let cgim = CGImage(
             width: width,
             height: height,
             bitsPerComponent: 8,
             bitsPerPixel: 24,
             bytesPerRow: width*3,
             space: CGColorSpaceCreateDeviceRGB(),
             bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
             provider: providerRef,
             decode: nil,
             shouldInterpolate: false,
             intent: .defaultIntent)
         else { return nil }
         self.init(cgImage: cgim)
     }
 }
 
