//
//  NearestNeighborScaleKernel.swift
//  SkyLight
//
//  Created by Luke Van In on 2022/12/25.
//

import Foundation
import MetalPerformanceShaders


final class ConvolutionSeriesKernel {
    
    enum Axis {
        case x
        case y
    }
    
    private let computePipelineState: MTLComputePipelineState
    private let parametersBuffer: MTLBuffer
 
    init(device: MTLDevice, axis: Axis, inputDepth: Int, outputDepth: Int, weights: [Float]) {
        let library = device.makeDefaultLibrary()!

        let function: MTLFunction
        
        switch axis {
        case .x:
            function = library.makeFunction(name: "convolutionSeriesX")!
            function.label = "convolutionSeriesXFunction"
        case .y:
            function = library.makeFunction(name: "convolutionSeriesY")!
            function.label = "convolutionSeriesYFunction"
        }

        self.computePipelineState = try! device.makeComputePipelineState(
            function: function
        )
        
        var weights = weights
        var parameters = ConvolutionParameters()
        parameters.inputDepth = Int32(inputDepth)
        parameters.outputDepth = Int32(outputDepth)
        parameters.count = Int32(weights.count)
        withUnsafeMutablePointer(to: &parameters.weights) { p in
            let p = UnsafeMutableRawPointer(p).assumingMemoryBound(to: Float.self)
            p.assign(from: &weights, count: weights.count)
        }
        self.parametersBuffer = device.makeBuffer(
            bytes: &parameters,
            length: MemoryLayout<ConvolutionParameters>.stride
        )!
    }
    
    func encode(
        commandBuffer: MTLCommandBuffer,
        inputTexture: MTLTexture,
        outputTexture: MTLTexture
    ) {
        precondition(inputTexture.width == outputTexture.width)
        precondition(inputTexture.height == outputTexture.height)
        // precondition(inputTexture.arrayLength == outputTexture.arrayLength)
        precondition(inputTexture.textureType == .type2DArray)
        precondition(inputTexture.pixelFormat == .r32Float)
        precondition(outputTexture.textureType == .type2DArray)
        precondition(outputTexture.pixelFormat == .r32Float)

        let encoder = commandBuffer.makeComputeCommandEncoder()!
        encoder.label = "convolutionSeriesComputeEncoder"
        encoder.setComputePipelineState(computePipelineState)
        encoder.setTexture(outputTexture, index: 0)
        encoder.setTexture(inputTexture, index: 1)
        encoder.setBuffer(parametersBuffer, offset: 0, index: 0)

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
//        encoder.dispatchThreads(<#T##threadsPerGrid: MTLSize##MTLSize#>, threadsPerThreadgroup: <#T##MTLSize#>)
        encoder.endEncoding()
    }
}
