//
//  GaussianDifferenceTests.swift
//  SkyLightTests
//
//  Created by Luke Van In on 2022/12/26.
//

import XCTest
import MetalPerformanceShaders

@testable import SIFTMetal

final class GaussianDifferenceTests: SharedTestCase {

    /*
    func testGaussianDifference() throws {
        let sourceTexture = try loadTexture(name: "butterfly", device: device)
        
//        let gaussian = MPSImageGaussianBlur(device: device, sigma: 2.5)
//        gaussian.edgeMode = .clamp
//        gaussian.offset = MPSOffset(x: 3, y: 3, z: 0)
        let gaussian = GaussianKernel(device: device, sigma: 2.5)
//        gaussian.edgeMode = .clamp
//        gaussian.offset = MPSOffset(x: 3, y: 3, z: 0)

        let subtract = MPSImageSubtract(device: device)
        
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .r32Float,
            width: sourceTexture.width,
            height: sourceTexture.height,
            mipmapped: false
        )
        textureDescriptor.usage = [.shaderRead, .shaderWrite]
        textureDescriptor.storageMode = .shared
        
        let inputTexture = device.makeTexture(descriptor: textureDescriptor)!
        let gaussianTexture = device.makeTexture(descriptor: textureDescriptor)!
//        let gaussian1Texture = device.makeTexture(descriptor: textureDescriptor)!
        let resultTexture = device.makeTexture(descriptor: textureDescriptor)!

        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        
        convertSRGBToLinearGrayscaleFunction.encode(
            commandBuffer: commandBuffer,
            sourceTexture: sourceTexture,
            destinationTexture: inputTexture
        )

        gaussian.encode(
            commandBuffer: commandBuffer,
            inputTexture: inputTexture,
            outputTexture: gaussianTexture
        )
        
        subtract.encode(
            commandBuffer: commandBuffer,
            primaryTexture: gaussianTexture,
            secondaryTexture: inputTexture,
            destinationTexture: resultTexture
        )

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        attachImage(
            name: "input",
            uiImage: makeUIImage(
                ciImage: smearColor(
                    ciImage: makeCIImage(
                        texture: inputTexture
                    )
                ),
                context: ciContext
            )
        )

        attachImage(
            name: "gaussian",
            uiImage: makeUIImage(
                ciImage: smearColor(
                    ciImage: makeCIImage(
                        texture: gaussianTexture
                    )
                ),
                context: ciContext
            )
        )

        attachImage(
            name: "result",
            uiImage: makeUIImage(
                ciImage: mapColor(
                    ciImage: smearColor(
                        ciImage: normalizeColor(
                            ciImage: makeCIImage(
                                texture: resultTexture
                            )
                        )
                    )
                ),
                context: ciContext
            )
        )
    }
     */
}
