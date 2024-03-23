//
//  DrawdownImage.swift
//  drawloom
//
//  Created by Kevin O'Brien on 3/21/24.
//

import Foundation
import SwiftUI

class DrawdownImage {
    var pixels:[UInt8] // original pixels
    var height:Int //original height
    var width:Int //original width
    var scale:Int // current Scale
    var scaledPixels:[[UInt8]] = [[0]] // to stop complaints about calling doScaling
    var previousLine:Int = -1
    var previousULine:Int = -1
    var previousUType:Int = -1
    var previousUPos:Int = -1
    var hCursor:UIImage = UIImage(systemName:"circle.fill")!
    var hcPosition:Int = 0
    var vCursor:UIImage = UIImage(systemName:"circle.fill")!
    var vcPosition:Int = 0
    init() {
        pixels = [UInt8](repeating: 0, count: 44000)
        width=200
        height=220
        scale=1
        doScaling(scale:1)
    }
    
    init(imageData:[UInt8],width:Int,height:Int) {
        //var color:[UInt8]
        pixels=imageData
        self.width=width
        self.height=height
        scale=1
        doScaling(scale:1)
    }
    
    func scaleImage(scale:Int) {
        self.scale=scale
        doScaling(scale:scale)
    }
    
    private func doScaling(scale:Int) {
        var color:[UInt8]
        
        scaledPixels=[[UInt8]](repeating:[UInt8](repeating: 0, count: 3), count: width*height*scale*scale)
        for row in 0...height-1 {
            for col in 0...width-1 {
                let pc = pixels[row*width+col]
                color = [pc,pc,pc]
                for h in 0...scale-1 {
                    for w in 0...scale-1 {
                        for c in 0...2 {
                            scaledPixels[row*width*scale*scale+col*scale+h*width*scale+w][c]=color[c]
                        }
                    }
                }
            }
        }
        
    }
    
    func flipHCursor(color:[UInt8],data:DrawdownData, line:Int) {
        print("entered flipHCursorFast: \(NSDate().timeIntervalSince1970)")
        var pIndex:Int = line*width
        var sIndex:Int = pIndex*scale*scale
        var hIndex:Int
        var wIndex:Int
        var wInc:Int = width*scale
        for col in 0...width-1 {
            if pixels[pIndex] == 255 {
                hIndex = sIndex
                for h in 0...scale-1 {
                    wIndex = hIndex
                    for w in 0...scale-1 {
                        //for c in 0...2 {
                            //scaledPixels[line*width*scale*scale+col*scale+h*width*scale+w][c] = color[c]
                        scaledPixels[line*width*scale*scale+col*scale+h*width*scale+w][0] = color[0]
                        scaledPixels[line*width*scale*scale+col*scale+h*width*scale+w][1] = color[1]
                        scaledPixels[line*width*scale*scale+col*scale+h*width*scale+w][2] = color[2]
                        //}
                        wIndex += 1
                    }
                    hIndex += wInc
                }
            }
            pIndex += 1
            sIndex += scale
        }
        print("leaving flipHCursorFast: \(NSDate().timeIntervalSince1970)")
    }
    
    func flipHCursorSlow(color:[UInt8],data:DrawdownData, line:Int) {
        print("entered flipHCursor: \(NSDate().timeIntervalSince1970)")
        for col in 0...width-1 {
            if pixels[line*width+col] == 255 {
                for h in 0...scale-1 {
                    for w in 0...scale-1 {
                        for c in 0...2 {
                            scaledPixels[line*width*scale*scale+col*scale+h*width*scale+w][c] = color[c]
                        }
                    }
                }
            }
        }
        print("leaving flipHCursor: \(NSDate().timeIntervalSince1970)")
    }
    
    func updateHCursor(color:[UInt8],data:DrawdownData, line:Int) {
        var scaledPixels:[[UInt8]] = [[UInt8]](repeating:[UInt8](repeating: 0, count: 3), count: width*scale*scale)
        for col in 0...width-1 {
            if pixels[line*width+col] == 255 {
                for h in 0...scale-1 {
                    for w in 0...scale-1 {
                        for c in 0...2 {
                            scaledPixels[col*scale+h*width*scale+w][c] = color[c]
                        }
                    }
                }
            }
        }
        hcPosition = line*scale+scale/2
        hCursor = UIImage(pixels:scaledPixels,width:width*scale,height:scale)!
    }
    
    func flipVCursor(color:[UInt8],data:DrawdownData, line:Int,uType:Int,uPos:Int) {
        print("entered flipVCursor: \(NSDate().timeIntervalSince1970)")
        if uType < DrawdownModel.UtteranceType.Empty.rawValue {
            let urv = uType-1
            let up = uPos
            let usp = data.uStart
            let urow = data.upsideDown ? line : height-line-1
            if usp[urow][urv].count > 0 {
                let uStartPos = data.uStart[urow][urv][uPos]
                let uStopPos = data.uStop[urow][urv][uPos]
                for col in width-uStopPos-1...width-uStartPos-1 {
                    for row in 0...height-1 {
                        if pixels[row*width+col] != 0 {
                            for h in 0...scale-1 {
                                for w in 0...scale-1 {
                                    for c in 0...2 {
                                        scaledPixels[row*width*scale*scale+col*scale+h*width*scale+w][c] = color[c]
                                    }
                                }
                            }

                        }
                    }
                }
            }
        }
        print("leaving flipVCursor: \(NSDate().timeIntervalSince1970)")
    }
  
    func updateVCursor(color:[UInt8],data:DrawdownData, line:Int,uType:Int,uPos:Int) {
        var scaledPixels:[[UInt8]] = [[]]
        var uWidth:Int = 1
        //var scaledPixels:[[UInt8]] = [[UInt8]](repeating:[UInt8](repeating: 0, count: 3), count: height*scale*scale)
        if uType < DrawdownModel.UtteranceType.Empty.rawValue {
            let urv = uType-1
            let up = uPos
            let usp = data.uStart
            let urow = data.upsideDown ? line : height-line-1
            if usp[urow][urv].count > 0 {
                let uStartPos = data.uStart[urow][urv][uPos]
                let uStopPos = data.uStop[urow][urv][uPos]
                uWidth = 1+uStopPos-uStartPos
                vcPosition = scale*(width-uStartPos-1-uWidth/2)
                scaledPixels = [[UInt8]](repeating:[UInt8](repeating: 0, count: 3), count: uWidth*height*scale*scale)
                for col in 0...uWidth-1 {
                    for row in 0...height-1 {
                        if pixels[row*width+col] != 0 {
                            for h in 0...scale-1 {
                                for w in 0...scale-1 {
                                    for c in 0...2 {
                                        scaledPixels[row*uWidth*scale*scale+col*scale+h*uWidth*scale+w][c] = color[c]
                                    }
                                }
                            }

                        }
                    }
                }
            }
        }
        //vcPosition = line*scale+scale/2
        vCursor = UIImage(pixels:scaledPixels,width:uWidth*scale,height:height*scale)!
    }
    
    func updateImage(with:DrawdownData) -> UIImage {
        let data = with
        var color:[UInt8] = [255,255,255]
        let newScale = Int(data.scale)
        if scale != newScale {
            print("scaling image: \(NSDate().timeIntervalSince1970)")
            scaleImage(scale:newScale)
            print("finished scaling: \(NSDate().timeIntervalSince1970)")
        }
        
        let line = data.upsideDown ? data.currentLineNum : height-data.currentLineNum-1
        if line != previousLine {
            updateHCursor(color:[240,192,192], data:data,line:line)
            /*if previousLine >= 0 {
                flipHCursor(color:[255,255,255], data:data, line:previousLine)
            }
            previousLine = line
            flipHCursor(color:[240,192,192], data:data,line:line)*/
        }
        
        //let startPos = line*width
        //let endPos = startPos+width-1
        let uc:[UInt8] = [192,224,255]
        let urv = data.utteranceRawValue-1
        /*
        if previousUPos >= 0 {
            flipVCursor(color: [255,255,255], data: data, line: previousULine, uType: previousUType, uPos: previousUPos)
        }
        previousUType = data.utteranceRawValue
        previousUPos=data.utterancePosition
        previousULine=line*/
        //flipVCursor(color: [192,uc[urv],240], data: data, line: line, uType: data.utteranceRawValue, uPos: data.utterancePosition)
        updateVCursor(color: [192,uc[urv],240], data: data, line: line, uType: data.utteranceRawValue, uPos: data.utterancePosition)

        let image = UIImage(pixels: scaledPixels,width: width*scale,height: height*scale)!
        return image
    }
    
}
