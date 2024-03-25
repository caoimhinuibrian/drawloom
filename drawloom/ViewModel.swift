//
//  ViewModel.swift
//  drawloom
//
//  Created by Kevin O'Brien on 3/7/24.
//

import Foundation
import SwiftUI

class MyViewModel: ObservableObject {
    var ddImage:UIImage=UIImage(pixels:[UInt8](repeating:0,count:44000), width:200, height:220)!
    var image:DrawdownImage=DrawdownImage(imageData:[UInt8](repeating: 0, count: 44000), width:200, height:220)
    var scale: CGFloat = 1
    var offset: Int = 1
    var floatOffset: CGFloat = 1.0
    var upsideDown:Bool = false
    func setImage(image:UIImage) {
        ddImage = image
    }
}
