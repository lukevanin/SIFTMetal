//
//  CoreImageExtensions.swift
//  SkyLight
//
//  Created by Luke Van In on 2022/12/17.
//

import CoreImage
import CoreImage.CIFilterBuiltins
import simd


extension CIImage {
    public func perspectiveTransformed(by matrix: simd_float3x3) -> CIImage {
        let bounds = Quad(rect: extent).transformed(by: matrix)
        let filter = CIFilter.perspectiveTransform()
        filter.topLeft = CGPoint(bounds.topLeft)
        filter.topRight = CGPoint(bounds.topRight)
        filter.bottomRight = CGPoint(bounds.bottomRight)
        filter.bottomLeft = CGPoint(bounds.bottomLeft)
        filter.inputImage = self
        return filter.outputImage!
    }
    
    public func colorInverted() -> CIImage {
        let filter = CIFilter.colorInvert()
        filter.inputImage = self
        return filter.outputImage!
    }
}

