//
//  SubtractKernel.swift
//  SkyLight
//
//  Created by Luke Van In on 2022/12/25.
//

import Foundation
import MetalPerformanceShaders


final class SubtractKernel {
    
    private let computePipelineState: MTLComputePipelineState
 
    init(device: MTLDevice) {
        let library = try! device.makeDefaultLibrary(bundle: .metalShaders)

        let function = library.makeFunction(name: "subtract")!
        function.label = "subtractFunction"

        self.computePipelineState = try! device.makeComputePipelineState(
            function: function
        )
    }
    
    func encode(
        commandBuffer: MTLCommandBuffer,
        inputTexture: MTLTexture,
        outputTexture: MTLTexture
    ) {
        precondition(inputTexture.width == outputTexture.width)
        precondition(inputTexture.width == outputTexture.width)
        precondition(inputTexture.arrayLength == outputTexture.arrayLength + 1)
        precondition(inputTexture.textureType == .type2DArray)
        precondition(inputTexture.pixelFormat == .r32Float)
        precondition(outputTexture.textureType == .type2DArray)
        precondition(outputTexture.pixelFormat == .r32Float)

        let encoder = commandBuffer.makeComputeCommandEncoder()!
        encoder.label = "subtractFunctionComputeEncoder"
        encoder.setComputePipelineState(computePipelineState)
        encoder.setTexture(outputTexture, index: 0)
        encoder.setTexture(inputTexture, index: 1)

        // Set the compute kernel's threadgroup size of 16x16
        // TODO: Ger threadgroup size from command buffer.
        let threadgroupSize = MTLSize(
            width: 8,
            height: 8,
            depth: 8
        )
        // Calculate the number of rows and columns of threadgroups given the width of the input image
        // Ensure that you cover the entire image (or more) so you process every pixel
        // Since we're only dealing with a 2D data set, set depth to 1
        let threadgroupCount = MTLSize(
            width: (outputTexture.width + threadgroupSize.width - 1) / threadgroupSize.width,
            height: (outputTexture.height + threadgroupSize.height - 1) / threadgroupSize.height,
            depth: (outputTexture.arrayLength + threadgroupSize.depth - 1)
        )
        encoder.dispatchThreadgroups(
            threadgroupCount,
            threadsPerThreadgroup: threadgroupSize
        )
        encoder.endEncoding()
    }
}
