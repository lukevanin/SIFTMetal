//
//  SIFTKeypoint.swift
//  SkyLight
//
//  Created by Luke Van In on 2023/01/02.
//

import Foundation


public struct SIFTKeypoint {
    
    // Index of the level of the difference-of-gaussians pyramid.
    public var octave: Int
    
    // Index of the image in the octave.
    public var scale: Int
    
    //
    public var subScale: Float
    
    // Coordinate relative to the difference-of-gaussians image size.
    public var scaledCoordinate: SIMD2<Int>
    
    // Coordinate relative to the original image.
    public var absoluteCoordinate: SIMD2<Float>

    // Coordinate relative to the normal space (0...1, 0...1)
    public var normalizedCoordinate: SIMD2<Float>

    // "Blur"
    public var sigma: Float
    
    // Pixel color (intensity)
    public var value: Float
    
    public init(
        octave: Int,
        scale: Int,
        subScale: Float,
        scaledCoordinate: SIMD2<Int>,
        absoluteCoordinate: SIMD2<Float>,
        normalizedCoordinate: SIMD2<Float>,
        sigma: Float,
        value: Float
    ) {
        self.octave = octave
        self.scale = scale
        self.subScale = subScale
        self.scaledCoordinate = scaledCoordinate
        self.absoluteCoordinate = absoluteCoordinate
        self.normalizedCoordinate = normalizedCoordinate
        self.sigma = sigma
        self.value = value
    }

}
