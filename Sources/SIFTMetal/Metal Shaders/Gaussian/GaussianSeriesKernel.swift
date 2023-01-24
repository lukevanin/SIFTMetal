//
//  SubtractKernel.swift
//  SkyLight
//
//  Created by Luke Van In on 2022/12/25.
//

import Foundation
import MetalPerformanceShaders


final class GaussianSeriesKernel {

    private let device: MTLDevice
    private let count: Int
    private let convolutionX: [ConvolutionSeriesKernel]
    private let convolutionY: [ConvolutionSeriesKernel]
    private let workingTexture: MTLTexture

    init(device: MTLDevice, sigmas: [Float], textureSize: IntegralSize, arrayLength: Int) {
        
        let count = sigmas.count

        var convolutionsX = [ConvolutionSeriesKernel]()
        var convolutionsY = [ConvolutionSeriesKernel]()
        
        for i in 0 ..< count {
            let s = sigmas[i]
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
            
            let convolutionX = ConvolutionSeriesKernel(
                device: device,
                axis: .x,
                inputDepth: i,
                outputDepth: 0,
                weights: weights
            )
            convolutionsX.append(convolutionX)

            let convolutionY = ConvolutionSeriesKernel(
                device: device,
                axis: .y,
                inputDepth: 0,
                outputDepth: i + 1,
                weights: weights
            )
            convolutionsY.append(convolutionY)

        }
        
        self.device = device
        self.count = count
        self.convolutionX = convolutionsX
        self.convolutionY = convolutionsY

        self.workingTexture = {
            let descriptor = MTLTextureDescriptor()
            descriptor.textureType = .type2DArray
            descriptor.pixelFormat = .r32Float
            descriptor.width = textureSize.width
            descriptor.height = textureSize.height
            descriptor.arrayLength = 1
            descriptor.mipmapLevelCount = 1
            descriptor.storageMode = .private
            descriptor.usage = [.shaderRead, .shaderWrite]
            return device.makeTexture(descriptor: descriptor)!
        }()
    }
    
    func encode(
        commandBuffer: MTLCommandBuffer,
        texture: MTLTexture
    ) {
//        precondition(inputTexture.width == workingTexture.width)
//        precondition(inputTexture.height == workingTexture.height)
//        precondition(outputTexture.width == workingTexture.width)
//        precondition(outputTexture.height == workingTexture.height)
//        precondition(inputTexture.pixelFormat == .r32Float)
//        precondition(inputTexture.textureType == .type2DArray)
//        precondition(inputTexture.arrayLength == workingTexture.arrayLength)
//        precondition(outputTexture.pixelFormat == .r32Float)
//        precondition(outputTexture.textureType == .type2DArray)
//        precondition(outputTexture.arrayLength == workingTexture.arrayLength)

        for i in 0 ..< count {
            convolutionX[i].encode(
                commandBuffer: commandBuffer,
                inputTexture: texture,
                outputTexture: workingTexture
            )
            convolutionY[i].encode(
                commandBuffer: commandBuffer,
                inputTexture: workingTexture,
                outputTexture: texture
            )
        }
    }
}
