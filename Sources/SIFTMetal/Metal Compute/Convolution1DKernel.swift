//
//  NearestNeighborScaleKernel.swift
//  SkyLight
//
//  Created by Luke Van In on 2022/12/25.
//

import Foundation
import MetalPerformanceShaders


final class Convolution1DKernel {
    
    enum Axis {
        case x
        case y
    }
    
    private let computePipelineState: MTLComputePipelineState
    private let weightsBuffer: MTLBuffer
    private let parametersBuffer: MTLBuffer
 
    init(device: MTLDevice, axis: Axis, weights: [Float]) {
        let library = try! device.makeDefaultLibrary(bundle: .metalShaders)

        let function: MTLFunction
        
        switch axis {
        case .x:
            function = library.makeFunction(name: "convolutionX")!
        case .y:
            function = library.makeFunction(name: "convolutionY")!
        }

        self.computePipelineState = try! device.makeComputePipelineState(
            function: function
        )
        
        var weights = weights
        var numberOfWeights: UInt32 = UInt32(weights.count)
        self.weightsBuffer = device.makeBuffer(
            bytes: &weights,
            length: MemoryLayout<Float>.stride * weights.count
        )!
        self.parametersBuffer = device.makeBuffer(
            bytes: &numberOfWeights,
            length: MemoryLayout<UInt32>.stride
        )!
    }
    
    func encode(
        commandBuffer: MTLCommandBuffer,
        inputTexture: MTLTexture,
        outputTexture: MTLTexture
    ) {
        precondition(inputTexture.width == outputTexture.width)
        precondition(inputTexture.height == outputTexture.height)

        let encoder = commandBuffer.makeComputeCommandEncoder()!
        encoder.setComputePipelineState(computePipelineState)
        encoder.setTexture(outputTexture, index: 0)
        encoder.setTexture(inputTexture, index: 1)
        encoder.setBuffer(weightsBuffer, offset: 0, index: 0)
        encoder.setBuffer(parametersBuffer, offset: 0, index: 1)

        // Set the compute kernel's threadgroup size of 16x16
        // TODO: Get threadgroup size from command buffer.
        let threadgroupSize = MTLSize(
            width: 16,
            height: 16,
            depth: 1
        )
        // Calculate the number of rows and columns of threadgroups given the width of the input image
        // Ensure that you cover the entire image (or more) so you process every pixel
        // Since we're only dealing with a 2D data set, set depth to 1
        let threadgroupCount = MTLSize(
            width: (outputTexture.width + threadgroupSize.width - 1) / threadgroupSize.width,
            height: (outputTexture.height + threadgroupSize.height - 1) / threadgroupSize.height,
            depth: 1
        )
        encoder.dispatchThreadgroups(
            threadgroupCount,
            threadsPerThreadgroup: threadgroupSize
        )
        encoder.endEncoding()
    }
}
