//
//  SIFTOrientationKernel.swift
//  SkyLight
//
//  Created by Luke Van In on 2022/12/25.
//

import Foundation
import MetalPerformanceShaders

final class SIFTDescriptorKernel {

    private let maximumKeypoints = 4096
    
    private let computePipelineState: MTLComputePipelineState

    init(device: MTLDevice) {
        let library = device.makeDefaultLibrary()!
        
        let function = library.makeFunction(name: "siftDescriptors")!
        
        self.computePipelineState = try! device.makeComputePipelineState(
            function: function
        )
    }
    
    func encode(
        commandBuffer: MTLCommandBuffer,
        parameters: Buffer<SIFTDescriptorParameters>,
        gradientTextures: MTLTexture,
        inputKeypoints: Buffer<SIFTDescriptorInput>,
        outputDescriptors: Buffer<SIFTDescriptorResult>
    ) {
        precondition(inputKeypoints.count == outputDescriptors.count)
        precondition(gradientTextures.textureType == .type2DArray)
        precondition(gradientTextures.pixelFormat == .rg32Float)

        let encoder = commandBuffer.makeComputeCommandEncoder()!
        encoder.setComputePipelineState(computePipelineState)
        encoder.setBuffer(outputDescriptors.data, offset: 0, index: 0)
        encoder.setBuffer(inputKeypoints.data, offset: 0, index: 1)
        encoder.setBuffer(parameters.data, offset: 0, index: 2)
        encoder.setTexture(gradientTextures, index: 0)

        let threadsPerThreadgroup = MTLSize(
            width: computePipelineState.maxTotalThreadsPerThreadgroup,
            height: 1,
            depth: 1
        )
        let threadsPerGrid = MTLSize(
            width: outputDescriptors.count,
            height: 1,
            depth: 1
        )
                
        encoder.dispatchThreads(
            threadsPerGrid,
            threadsPerThreadgroup: threadsPerThreadgroup
        )
        encoder.endEncoding()
    }
}

