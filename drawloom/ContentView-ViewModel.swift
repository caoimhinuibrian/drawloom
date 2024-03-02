//
//  ContentView-ViewModel.swift
//  drawloom
//
//  Created by Kevin O'Brien on 3/1/24.
//

import Foundation
import SwiftUI
import Speech

extension ContentView {
    @Observable
    class ViewModel {
        var line = ""
        var spoken = "nothing yet"
        var progress = "uninitialized"
        var speechStatus = "not requested"
        var document: InputDocument = InputDocument(input: "")
        var isImporting: Bool = false
        var isRecording = false
        var recognizedText = ""
        var speechEnabled: Bool = false
        var recognizerTask:SFSpeechRecognitionTask?
        var img:UIImage = UIImage()
        var scale: CGFloat = 6
        var offset: Int = 1
    }
}
