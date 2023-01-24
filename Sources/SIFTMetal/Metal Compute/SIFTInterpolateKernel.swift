//
//  SIFTInterpolateKernel.swift
//  SkyLight
//
//  Created by Luke Van In on 2022/12/25.
//

import Foundation
import MetalPerformanceShaders

import MetalShaders

final class SIFTInterpolateKernel {
    
    private let maximumKeypoints = 4096
    
    private let computePipelineState: MTLComputePipelineState
//    private let differenceTextureArray: MTLTexture

    init(device: MTLDevice) {
        let library = try! device.makeDefaultLibrary(bundle: .metalShaders)

        let function = library.makeFunction(name: "siftInterpolate")!
        
//        let descriptor = MTLTextureDescriptor()
//        descriptor.textureType = .type2DArray
//        descriptor.pixelFormat = .r32Float
//        descriptor.width = textureSize.width
//        descriptor.height = textureSize.height
//        descriptor.arrayLength = numberOfTextures
//        descriptor.mipmapLevelCount = 0
//        descriptor.storageMode = .shared
//        descriptor.usage = [.shaderRead, .shaderWrite]
        
        self.computePipelineState = try! device.makeComputePipelineState(
            function: function
        )
//        self.differenceTextureArray = device.makeTexture(descriptor: descriptor)!
    }
    
    func encode(
        commandBuffer: MTLCommandBuffer,
        parameters: Buffer<SIFTInterpolateParameters>,
        differenceTextures: MTLTexture,
        inputKeypoints: Buffer<SIFTInterpolateInputKeypoint>,
        outputKeypoints: Buffer<SIFTInterpolateOutputKeypoint>
    ) {
        precondition(inputKeypoints.count == outputKeypoints.count)
        precondition(differenceTextures.textureType == .type2DArray)
        precondition(differenceTextures.pixelFormat == .r32Float)
        
        let encoder = commandBuffer.makeComputeCommandEncoder()!
        encoder.setComputePipelineState(computePipelineState)
        encoder.setBuffer(outputKeypoints.data, offset: 0, index: 0)
        encoder.setBuffer(inputKeypoints.data, offset: 0, index: 1)
        encoder.setBuffer(parameters.data, offset: 0, index: 2)
        encoder.setTexture(differenceTextures, index: 0)

        let threadsPerThreadgroup = MTLSize(
            width: computePipelineState.maxTotalThreadsPerThreadgroup,
            height: 1,
            depth: 1
        )
        let threadsPerGrid = MTLSize(
            width: outputKeypoints.count,
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

