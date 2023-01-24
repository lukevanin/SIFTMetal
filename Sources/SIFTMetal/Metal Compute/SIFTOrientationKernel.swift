//
//  SIFTOrientationKernel.swift
//  SkyLight
//
//  Created by Luke Van In on 2022/12/25.
//

import Foundation
import MetalPerformanceShaders

import MetalShaders

final class SIFTOrientationKernel {

//    struct Parameters {
//        let delta: Float32
//        let lambda: Float32
//        let orientationThreshold: Float32
//    }
//
//    struct InputKeypoint {
//        let absoluteX: Int32
//        let absoluteY: Int32
//        let scale: Int32
//        let sigma: Float32
//    }
//
//    struct OutputKeypoint {
//        let count: Int32
//        let orientations: [Float32]
//    }
    
//    typealias Parameters = SIFTOrientationKeypoint
    
    private let maximumKeypoints = 4096
    
    private let computePipelineState: MTLComputePipelineState

    init(device: MTLDevice) {
        let library = try! device.makeDefaultLibrary(bundle: .metalShaders)

        let function = library.makeFunction(name: "siftOrientation")!
        function.label = "siftOrientation"
        
        self.computePipelineState = try! device.makeComputePipelineState(
            function: function
        )
    }
    
    func encode(
        commandBuffer: MTLCommandBuffer,
        parameters: Buffer<SIFTOrientationParameters>,
        gradientTextures: MTLTexture,
        inputKeypoints: Buffer<SIFTOrientationKeypoint>,
        outputKeypoints: Buffer<SIFTOrientationResult>
    ) {
        precondition(inputKeypoints.count == outputKeypoints.count)
        precondition(gradientTextures.textureType == .type2DArray)
        precondition(gradientTextures.pixelFormat == .rg32Float)
        
        let encoder = commandBuffer.makeComputeCommandEncoder()!
        encoder.label = "siftOrientationComputeEncoder"
        encoder.setComputePipelineState(computePipelineState)
        encoder.setBuffer(outputKeypoints.data, offset: 0, index: 0)
        encoder.setBuffer(inputKeypoints.data, offset: 0, index: 1)
        encoder.setBuffer(parameters.data, offset: 0, index: 2)
        encoder.setTexture(gradientTextures, index: 0)

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

