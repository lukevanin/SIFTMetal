//
//  SIFTKeypoint.swift
//  SkyLight
//
//  Created by Luke Van In on 2023/01/02.
//

import Foundation


struct SIFTKeypoint {
    // Index of the level of the difference-of-gaussians pyramid.
    var octave: Int
    // Index of the image in the octave.
    var scale: Int
    //
    var subScale: Float
    // Coordinate relative to the difference-of-gaussians image size.
    var scaledCoordinate: SIMD2<Int>
    // Coordinate relative to the original image.
    var absoluteCoordinate: SIMD2<Float>
    // "Blur"
    var sigma: Float
    // Pixel color (intensity)
    var value: Float
}
