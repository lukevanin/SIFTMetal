//
//  Math.swift
//  SkyLight
//
//  Created by Luke Van In on 2022/12/18.
//

import Foundation


struct IntegralSize {
    var width: Int
    var height: Int
}


func modulus(_ x: Float, _ y: Float) -> Float {
    var z: Float = x
    var n: Int = 0
    if (z < 0) {
        n = Int(((-z) / y) + 1)
        z += Float(n) * y
    }
    n = Int(z / y)
    z -= Float(n) * y
    return z
}
