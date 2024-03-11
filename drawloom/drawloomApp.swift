//
//  drawloomApp.swift
//  drawloom
//
//  Created by Kevin O'Brien on 2/20/24.
//

import SwiftUI
import SwiftData

@main
struct drawloomApp: App {
    // this hack prevents an uninitialized container
    let modelContainer: ModelContainer
    init() {
        do {
            modelContainer = try ModelContainer(for: DrawdownData.self)
        } catch {
            fatalError("could not initialize ModelContainer")
        }
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(modelContainer)
                //.modelContainer(for:DrawdownData.self)
        }
    }
}
