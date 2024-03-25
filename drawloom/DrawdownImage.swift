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
    var scaledPixels:[UInt8] = [] // to stop complaints about calling doScaling
    var hCursor:UIImage = UIImage(systemName:"circle.fill")!
    var hcPosition:Int = 0
    var vCursor:UIImage = UIImage(systemName:"circle.fill")!
    var vcPosition:CGFloat = 0
    var previousLine:Int = -1
    init() {
        pixels = [UInt8](repeating: 0, count: 44000)
        width=200
        height=220
        scale=1
        doScaling(scale:2)
    }
    
    init(imageData:[UInt8],width:Int,height:Int) {
        //var color:[UInt8]
        pixels=imageData
        self.width=width
        self.height=height
        scale=1
        doScaling(scale:2)
    }
    
    private func doScaling(scale:Int) {
        scaledPixels=[UInt8](repeating:0, count: width*height*scale*scale)
        for row in 0...height-1 {
            for col in 0...width-1 {
                for h in 0...scale-1 {
                    for w in 0...scale-1 {
                        scaledPixels[row*width*scale*scale+col*scale+h*width*scale+w]=pixels[row*width+col]
                    }
                }
            }
        }
        
    }
   
    func updateHCursor(color:[UInt8],data:DrawdownData, line:Int) {
        var pixels:[[UInt8]] = [[UInt8]](repeating:[UInt8](repeating: 0, count: 3), count: width)
        for col in 0...width-1 {
            for c in 0...2 {
                pixels[col][c] = color[c]
            }
        }
        hcPosition = 2*line+1
        hCursor = UIImage(pixels:pixels,width:width,height:1)!
    }
  
    func updateVCursor(color:[UInt8],data:DrawdownData, line:Int,uType:Int,uPos:Int) {
        var scaledPixels:[[UInt8]] = [[]]
        var uWidth:Int = 1
        vCursor = UIImage(pixels:[[UInt8]](repeating:[UInt8](repeating:255,count:3),count:height),width:1,height:height)!
        if uType < DrawdownModel.UtteranceType.Empty.rawValue {
            let urv = uType-1
            let usp = data.uStart
            let urow = data.upsideDown ? line : height-line-1
            if usp[urow][urv].count > 0 {
                let uStartPos = data.uStart[urow][urv][uPos]
                let uStopPos = data.uStop[urow][urv][uPos]
                uWidth = 1+uStopPos-uStartPos
                //if uWidth%2 == 0 {
                //    uWidth+=1
                //}
                let uwf:CGFloat = CGFloat(uWidth)/2.0
                let stop:CGFloat = CGFloat(width-1-uStopPos)
                //vcPosition = 2*(width-1-uStopPos+uWidth/2)+1
                vcPosition = 2.0*(stop+uwf)

                print("updateVcursor: uStartPos=\(uStartPos) uStopPos=\(uStopPos) uWidth=\(uWidth) vcPosition=\(vcPosition)")
                scaledPixels = [[UInt8]](repeating:[UInt8](repeating: 0, count: 3), count: uWidth*height)
                for col in 0...uWidth-1 {
                    for row in 0...height-1 {
                                    for c in 0...2 {
                                        scaledPixels[row*uWidth+col][c] = color[c]
                                    }

                    }
                }
                vCursor = UIImage(pixels:scaledPixels,width:uWidth,height:height)!
            }
        }
    }
    
    func updateImage(with:DrawdownData) -> UIImage {
        let data = with
        let line = data.upsideDown ? data.currentLineNum : height-data.currentLineNum-1
        if line != previousLine {
            updateHCursor(color:[240,192,192], data:data,line:line)
            previousLine=line
        }
        
        let uc:[UInt8] = [192,224,255]
        let urv = data.utteranceRawValue-1
        updateVCursor(color: [192,uc[urv],240], data: data, line: line, uType: data.utteranceRawValue, uPos: data.utterancePosition)

        let image = UIImage(pixels: scaledPixels,width: width*2,height: height*2)!
        return image
    }
    
}
