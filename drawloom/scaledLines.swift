/*
 * SPDX-License-Identifier: Apache-2.0
 */
//
//  scaledLines.swift
//  drawloom
//
//  Created by Kevin O'Brien on 4/14/24.
//
//
// Copyright 2024 Kevin O'Brien.
//
// =============================================================================import Foundation

import Foundation
import SwiftUI


class ScaledLines {
    struct VerticalScale: Shape {
        var xpos:Double = 50
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: xpos, y: rect.minY))
            path.addLine(to: CGPoint(x: xpos, y:rect.maxY))
            path.stroke(.red)
            return path
        }
    }
}
