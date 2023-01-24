//
//  Extensions.swift
//  SkyLight
//
//  Created by Luke Van In on 2022/12/17.
//

import CoreGraphics
import simd


extension CGPoint {
    init(_ point: simd_float2) {
        self.init(x: CGFloat(point.x), y: CGFloat(point.y))
    }
}
