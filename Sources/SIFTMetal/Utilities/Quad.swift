//
//  Quad.swift
//  SkyLight
//
//  Created by Luke Van In on 2022/12/17.
//

import Foundation
import simd


struct Quad {
    var topLeft: simd_float2
    var topRight: simd_float2
    var bottomRight: simd_float2
    var bottomLeft: simd_float2

    var points: [simd_float2] {
        [topLeft, topRight, bottomRight, bottomLeft]
    }
    
    func transformed(by matrix: simd_float3x3) -> Quad {
        Quad(
            points: points
                .map { point in
                    simd_float3(point.x, point.y, 1)
                }
                .map { point in
                    matrix * point
                }
                .map { point in
                    simd_float2(point.x / point.z, point.y / point.z)
                }
        )
    }
}

extension Quad {
    init(rect: CGRect) {
        self.init(
            topLeft: simd_float2(Float(rect.minX), Float(rect.maxY)),
            topRight: simd_float2(Float(rect.maxX), Float(rect.maxY)),
            bottomRight: simd_float2(Float(rect.maxX), Float(rect.minY)),
            bottomLeft: simd_float2(Float(rect.minX), Float(rect.minY))
        )
    }
    
    init(points: [simd_float2]) {
        self.init(
            topLeft: points[0],
            topRight: points[1],
            bottomRight: points[2],
            bottomLeft: points[3]
        )
    }
}
