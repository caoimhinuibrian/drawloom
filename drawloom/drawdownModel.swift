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

class DrawdownModel: ObservableObject {
    var data:DrawdownData = DrawdownData()
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
        data.offset=offset
    }
    
    func move(delta:Int) {
        if (data.currentLineNum+delta<data.height) && (data.currentLineNum+delta>=0) {
            data.currentLineNum+=delta
            updateImage(width:data.width,height:data.height,imageData:data.pixels)
            setCurrentLineValues()
            utteranceType = UtteranceType.Release
            data.utteranceRawValue = utteranceType.rawValue
        }
        speaker.speak(wordsToSpeak:"OK")
    }

    func notRecognized() {
        speaker.speak(wordsToSpeak:"I don't recognize that verb, sorry!")
    }
    
    func checkUtteranceStatus() -> (String, [String]) {
        var prefix:String = ""
        var range:[String] = []
        switch(utteranceType) {
        case .Release:
            prefix = "Release"
            range = data.upline[data.currentLineNum]
        case .Draw:
            prefix = "Draw"
            range = data.downline[data.currentLineNum]
        case .Pulled:
            prefix = "Pulled"
            range = data.imline[data.currentLineNum]
        case .Empty:
            prefix = "End of pick"
            range = [""]
            data.utterancePosition = 0
        }
        while(data.utterancePosition >= range.count) && (utteranceType != .Empty)  {
            utteranceType = UtteranceType(rawValue: utteranceType.rawValue+1)!
            data.utteranceRawValue = utteranceType.rawValue
            data.utterancePosition = 0
            switch(utteranceType) {
            case .Release:
                prefix = "Release"
                range = data.upline[data.currentLineNum]
            case .Draw:
                prefix = "Draw"
                range = data.downline[data.currentLineNum]
            case .Pulled:
                prefix = "Pulled"
                range = data.imline[data.currentLineNum]
            case .Empty:
                prefix = "End of pick"
                range = [""]
                data.utterancePosition = 0
            }
        }
        return(prefix,range)
    }
    
    func sayNext() {
        var prefix:String = ""
        var range:[String] = []
        (prefix,range) = checkUtteranceStatus()
        print("utterancePosition \(data.utterancePosition)  size of range \(range.count)")
        let wordsToSpeak:String = prefix+range[data.utterancePosition]
        speaker.speak(wordsToSpeak:wordsToSpeak)
        data.utterancePosition+=1
    }
    
    func sendVerb(verb:String) {
        switch(verb) {
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

            data.imline[row] = buildTextRow(pick: img_array[row], offset: offset)
            data.upline[row] = buildTextRow(pick: ups[row], offset: offset)
            data.downline[row] = buildTextRow(pick: downs[row], offset: offset)
        }

    }
    func updateImage(width:Int,height:Int,imageData: [UInt8]) -> UIImage {
        let lineNum = data.upsideDown ? data.currentLineNum : height-data.currentLineNum-1
        let startPos = lineNum*width
        let endPos = startPos+width-1
        var pixels = imageData
        let wd = data.width
        let hd = data.height
        let sd = data.scale
        print("scale is \(sd)")
        for index in 0...pixels.count-1 {
            if pixels[index] == 128 {
                pixels[index]=255
            }
        }
        
        for index in startPos...endPos {
            if pixels[index] == 255 {
                pixels[index]=128
            }
        }
        let scale = Int(data.scale)
        var scaledPixels:[UInt8] = [UInt8](repeating: 0, count: data.width*data.height*scale*scale)

        for row in 0...data.height-1 {
            for col in 0...data.width-1 {
                for h in 0...scale-1 {
                    for w in 0...scale-1 {
                        scaledPixels[row*width*scale*scale+col*scale+h*width*scale+w]=pixels[row*width+col]
                    }
                }
            }
        }
         
        setImg(UIImage(pixels: pixels,width: width,height: height)!)
        viewmodel.ddImage = UIImage(pixels: scaledPixels,width: width*scale,height: height*scale)!
        data.pixels = pixels
        data.width = width
        data.height = height
        return viewmodel.ddImage
    }
    
    func updateImage() {
        updateImage(width:data.width,height:data.height,imageData:data.pixels) 
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
                updateImage(width:imageWidth,height:imageHeight,imageData:imageData)
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
