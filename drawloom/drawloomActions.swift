//
//  drawloomActions.swift
//  drawloom
//
//  Created by Kevin O'Brien on 2/20/24.
//

import Foundation

var lines: [String.SubSequence] = []
var lineCount: Int = 0
var current: Int = 0

func advance() {
    if current<lineCount-1 {
        current+=1
    }
}

func retreat() {
    if current>0 {
        current-=1
    }
}

func setContent(contents: String) {
    lines = contents.split(separator:"\n")
    lineCount = lines.count
}

/*
func loadFile() {

    let filename = "Text"

    guard let file = Bundle.main.url(forResource: filename, withExtension: "txt")
    else {
        fatalError("Couldn't find \(filename) in main bundle.")
    }

    do {

        let contents = try String(contentsOf: file, encoding: String.Encoding.utf8 )
        lines = contents.split(separator:"\n")
        lineCount = lines.count
        } catch {
        }
}
*/
