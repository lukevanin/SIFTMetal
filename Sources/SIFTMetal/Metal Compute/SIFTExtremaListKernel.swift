//
//  SIFTExtremaKernel.swift
//  SkyLight
//
//  Created by Luke Van In on 2022/12/20.
//

import Foundation
import MetalPerformanceShaders

import MetalShaders

final class SIFTExtremaListFunction {
    
    private let computePipelineState: MTLComputePipelineState
    
    let indexBuffer: Buffer<Int32>
    
    init(device: MTLDevice) {
        let library = try! device.makeDefaultLibrary(bundle: .metalShaders)

        let function = library.makeFunction(name: "siftExtremaList")!
        function.label = "siftExtremaListFunction"

        self.computePipelineState = try! device.makeComputePipelineState(
            function: function
        )
        self.indexBuffer = Buffer<Int32>(
            device: device,
            label: "siftExtremaListIndex",
            capacity: 1
        )
        self.indexBuffer.allocate(1)
        indexBuffer[0] = 0
    }
    
    func encode(
        commandBuffer: MTLCommandBuffer,
        inputTexture: MTLTexture,
        outputBuffer: Buffer<SIFTExtremaResult>
    ) {
        precondition(inputTexture.textureType == .type2DArray)
        precondition(inputTexture.pixelFormat == .r32Float)
                
        let encoder = commandBuffer.makeComputeCommandEncoder()!
        encoder.label = "siftExtremaListFunctionComputeEncoder"
        encoder.setComputePipelineState(computePipelineState)
        encoder.setBuffer(outputBuffer.data, offset: 0, index: 0)
        encoder.setBuffer(indexBuffer.data, offset: 0, index: 1)
        encoder.setTexture(inputTexture, index: 0)
        
        let threadsPerDimension = Int(cbrt(Float(computePipelineState.maxTotalThreadsPerThreadgroup)))
        let threadsPerThreadgroup = MTLSize(
            width: threadsPerDimension,
            height: threadsPerDimension,
            depth: threadsPerDimension
        )
        let threadsPerGrid = MTLSize(
            width: inputTexture.width - 2,
            height: inputTexture.height - 2,
            depth: inputTexture.arrayLength - 2
        )
                
        encoder.dispatchThreads(
            threadsPerGrid,
            threadsPerThreadgroup: threadsPerThreadgroup
        )
        encoder.endEncoding()
    }
}
