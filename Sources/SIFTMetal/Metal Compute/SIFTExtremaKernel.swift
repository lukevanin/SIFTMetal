//
//  SIFTExtremaKernel.swift
//  SkyLight
//
//  Created by Luke Van In on 2022/12/20.
//

import Foundation
import MetalPerformanceShaders


final class SIFTExtremaFunction {
    
    private let computePipelineState: MTLComputePipelineState
 
    init(device: MTLDevice) {
        let library = device.makeDefaultLibrary()!

        let function = library.makeFunction(name: "siftExtrema")!
        function.label = "siftExtremaFunction"

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
        precondition(inputTexture.arrayLength == outputTexture.arrayLength + 2)
        precondition(inputTexture.textureType == .type2DArray)
        precondition(inputTexture.pixelFormat == .r32Float)
        precondition(outputTexture.textureType == .type2DArray)
        precondition(outputTexture.pixelFormat == .rg32Float)
        
        let encoder = commandBuffer.makeComputeCommandEncoder()!
        encoder.label = "siftExtremaFunctionComputeEncoder"
        encoder.setComputePipelineState(computePipelineState)
        encoder.setTexture(outputTexture, index: 0)
        encoder.setTexture(inputTexture, index: 1)

        let threadsPerDimension = Int(cbrt(Float(computePipelineState.maxTotalThreadsPerThreadgroup)))
        let threadsPerThreadgroup = MTLSize(
            width: threadsPerDimension,
            height: threadsPerDimension,
            depth: threadsPerDimension
        )
        let threadsPerGrid = MTLSize(
            width: outputTexture.width - 2,
            height: outputTexture.height - 2,
            depth: outputTexture.arrayLength
        )
                
        encoder.dispatchThreads(
            threadsPerGrid,
            threadsPerThreadgroup: threadsPerThreadgroup
        )
        encoder.endEncoding()
    }
}
