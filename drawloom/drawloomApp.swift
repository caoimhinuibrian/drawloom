//
//  drawloomApp.swift
//  drawloom
//
//  Created by Kevin O'Brien on 2/20/24.
//

import SwiftUI

@main
struct drawloomApp: App {
    var viewables:DrawdownViewables
    var drawdownModel:DrawdownModel
    
    init() {
        viewables = DrawdownViewables()
        drawdownModel = DrawdownModel(offset:1, viewables:viewables)
    }
    var body: some Scene {
        WindowGroup {
            ContentView(viewables:viewables,model:drawdownModel)
        }
    }
}
