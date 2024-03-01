//
//  Speaker.swift
//  drawloom
//
//  Created by Kevin O'Brien on 2/29/24.
//

import Foundation
import Speech

final class Speaker: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = Speaker()
    
    private var synthesizer = AVSpeechSynthesizer()
    private var delegateExists:Bool = false
    private var isFinishedSpeaking:Bool = true
    private var restart: () -> Void = {() in }

    
    func setDelegate(restart: @escaping () -> Void) {
        self.restart=restart
        synthesizer.delegate = self
        delegateExists=true
    }
    
    func speak(wordsToSpeak:String) {
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
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        restart()
    }
    
}
