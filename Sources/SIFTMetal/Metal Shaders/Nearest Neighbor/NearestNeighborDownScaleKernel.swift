//
//  NearestNeighborScaleKernel.swift
//  SkyLight
//
//  Created by Luke Van In on 2022/12/25.
//

import Foundation
import MetalPerformanceShaders


final class NearestNeighborDownScaleKernel {
    
    private let computePipelineState: MTLComputePipelineState
    private let parametersBuffer: MTLBuffer
 
    init(device: MTLDevice) {
        let library = device.makeDefaultLibrary()!

        let function = library.makeFunction(name: "nearestNeighborDownScale")!

        self.computePipelineState = try! device.makeComputePipelineState(
            function: function
        )
        self.parametersBuffer = device.makeBuffer(
            length: MemoryLayout<NearestNeighborScaleParameters>.stride
        )!
    }
    
    func encode(
        commandBuffer: MTLCommandBuffer,
        inputTexture: MTLTexture,
        inputSlice: Int,
        outputTexture: MTLTexture,
        outputSlice: Int
    ) {
        precondition((inputTexture.width / 2) == outputTexture.width)
        precondition((inputTexture.height / 2) == outputTexture.height)
        precondition(inputTexture.textureType == .type2DArray)
        precondition(inputTexture.pixelFormat == .r32Float)
        precondition(outputTexture.textureType == .type2DArray)
        precondition(outputTexture.pixelFormat == .r32Float)
        
        let p = parametersBuffer.contents().assumingMemoryBound(to: NearestNeighborScaleParameters.self)
        p[0] = NearestNeighborScaleParameters(
            inputSlice: Int32(inputSlice),
            outputSlice: Int32(outputSlice)
        )

        let encoder = commandBuffer.makeComputeCommandEncoder()!
        encoder.setComputePipelineState(computePipelineState)
        encoder.setTexture(outputTexture, index: 0)
        encoder.setTexture(inputTexture, index: 1)
        encoder.setBuffer(parametersBuffer, offset: 0, index: 0)

        // Set the compute kernel's threadgroup size of 16x16
        // TODO: Ger threadgroup size from command buffer.
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
