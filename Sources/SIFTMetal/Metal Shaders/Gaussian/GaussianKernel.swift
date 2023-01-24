//
//  SubtractKernel.swift
//  SkyLight
//
//  Created by Luke Van In on 2022/12/25.
//

import Foundation
import MetalPerformanceShaders


final class GaussianKernel {

    private var workingTexture: MTLTexture!
    
    private let device: MTLDevice
    private let convolutionX: Convolution1DKernel
    private let convolutionY: Convolution1DKernel

    init(device: MTLDevice, sigma s: Float) {
        let radius = Int(ceil(4 * s))
        let size = (radius * 2) + 1
        print("GaussianKernel sigma=\(s) radius=\(radius) size=\(size)")

        var weights = [Float]()
        var t = Float(0)
        let ss = s * s
        for k in -radius ... radius {
            let kk = Float(k * k)
            let w = exp(-0.5 * (kk / ss))
            weights.append(w)
            t += w
        }
        
        precondition(weights.count == size)
        precondition(weights[radius] == 1.0)
        
        // Normalize weights
        for i in 0 ..< size {
            weights[i] = weights[i] / t
        }
        
        precondition(abs(1 - weights.reduce(0, +)) < 0.001)
        
        self.device = device
        
        self.convolutionX = Convolution1DKernel(
            device: device,
            axis: .x,
            weights: weights
        )

        self.convolutionY = Convolution1DKernel(
            device: device,
            axis: .y,
            weights: weights
        )
    }
    
    func encode(
        commandBuffer: MTLCommandBuffer,
        inputTexture: MTLTexture,
        outputTexture: MTLTexture
    ) {
        precondition(inputTexture.width == outputTexture.width)
        precondition(inputTexture.height == outputTexture.height)
        precondition(inputTexture.pixelFormat == outputTexture.pixelFormat)

        if workingTexture?.width != inputTexture.width || workingTexture?.height != inputTexture.height {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: inputTexture.pixelFormat,
                width: inputTexture.width,
                height: inputTexture.height,
                mipmapped: false
            )
            descriptor.storageMode = .private
            descriptor.usage = [.shaderRead, .shaderWrite]
            workingTexture = device.makeTexture(descriptor: descriptor)
        }

        convolutionX.encode(
            commandBuffer: commandBuffer,
            inputTexture: inputTexture,
            outputTexture: workingTexture
        )
        
        convolutionY.encode(
            commandBuffer: commandBuffer,
            inputTexture: workingTexture,
            outputTexture: outputTexture
        )
    }
}
