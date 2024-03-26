/*
 * SPDX-License-Identifier: Apache-2.0
 */
//
//  DrawdownData.swift
//  drawloom
//
//  Created by Kevin O'Brien on 3/4/24.
//
// Copyright 2024 Kevin O'Brien.
//
// =============================================================================
import Foundation
import SwiftData
import SwiftUI

@Model
class DrawdownData {
    var selectedFile:String = ""
    var timestamp:Date = Date()
    var pixels:[UInt8] = [UInt8](repeating: 0, count: 44000)
    var width:Int = 200
    var height:Int = 220
    var upsideDown:Bool = false
    var offset:Int = 1
    var imline:[[String]] = []
    var upline:[[String]] = []
    var downline:[[String]] = []
    var uStart:[[[Int]]] = []
    var uStop:[[[Int]]] = []
    /*
    var imStart:[[Int]] = [[]]
    var imStop:[[Int]] = [[]]
    var upsStart:[[Int]] = [[]]
    var upsStop:[[Int]] = [[]]
    var downsStart:[[Int]] = [[]]
    var downsStop:[[Int]] = [[]]*/
    var drawDownLoaded: Bool = false
    var currentLineNum: Int = 0
    var releaseLine:String = ""
    var drawLine:String = ""
    var utterancePosition:Int = 0
    var utteranceRawValue:Int = 1 //Release
    var floatOffset:CGFloat = 1.0
    var scale:CGFloat = 1.0
     
    init() {
        
    }
    
    func display() {
        display(from:"")
    }
    
    func display(from:String) {
        print(from)
        print("{\(selectedFile), \(timestamp), \(width), \(height), \(offset), \(currentLineNum), \(utterancePosition), \(scale) ")
    }
}
