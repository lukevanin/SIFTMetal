//
//  ImageConversion.swift
//  SkyLight
//
//  Created by Luke Van In on 2022/12/18.
//

import Foundation
import CoreImage
import CoreVideo
import Metal


public final class ImageConversion {
    
    private let ciContext: CIContext
    
    public init(device: MTLDevice, colorSpace: CGColorSpace) {
        self.ciContext = CIContext(
            mtlDevice: device,
            options: [
                .useSoftwareRenderer: false,
                .outputColorSpace: colorSpace,
                .workingColorSpace: colorSpace,
            ]
        )
    }

    public func makeCGImage(_ input: CVImageBuffer) -> CGImage {
        let ciImage = CIImage(
            cvPixelBuffer: input,
            options: [.applyOrientationProperty: true]
        )
        return makeCGImage(ciImage)
    }
    
    public func makeCGImage(_ input: MTLTexture) -> CGImage {
        let ciImage = CIImage(mtlTexture: input)!
        return makeCGImage(ciImage)
    }
    
    public func makeCGImage(_ input: CIImage) -> CGImage {
        let output = input.transformed(by: input.orientationTransform(for: .downMirrored))
        return ciContext.createCGImage(output, from: output.extent)!
    }

}
