//
//  SIFTGradientKernel.swift
//  SkyLight
//
//  Created by Luke Van In on 2023/01/03.
//

import Foundation
import Metal

///
/// Computes the gradient orientation and magnitude for every pixel in the input image.
///
final class SIFTGradientKernel {
    
    private let computePipelineState: MTLComputePipelineState
 
    init(device: MTLDevice) {
        let library = device.makeDefaultLibrary()!

        let function = library.makeFunction(name: "siftGradient")!
        function.label = "siftGradientFunction"

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
        precondition(inputTexture.height == outputTexture.height)
        precondition(inputTexture.arrayLength == outputTexture.arrayLength)
        precondition(inputTexture.textureType == .type2DArray)
        precondition(inputTexture.pixelFormat == .r32Float)
        precondition(outputTexture.textureType == .type2DArray)
        precondition(outputTexture.pixelFormat == .rg32Float)

        let encoder = commandBuffer.makeComputeCommandEncoder()!
        encoder.label = "siftGradientComputeEncoder"
        encoder.setComputePipelineState(computePipelineState)
        encoder.setTexture(outputTexture, index: 0)
        encoder.setTexture(inputTexture, index: 1)

        // Set the compute kernel's threadgroup size of 16x16
        // TODO: Get threadgroup size from command buffer.
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
            depth: (outputTexture.arrayLength + threadgroupSize.depth - 1) / threadgroupSize.depth
        )
        encoder.dispatchThreadgroups(
            threadgroupCount,
            threadsPerThreadgroup: threadgroupSize
        )
        encoder.endEncoding()
    }
}
