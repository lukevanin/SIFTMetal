//
//  Math.swift
//  SkyLight
//
//  Created by Luke Van In on 2022/12/18.
//

import Foundation


public struct IntegralSize {
    public var width: Int
    public var height: Int
    
    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
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
