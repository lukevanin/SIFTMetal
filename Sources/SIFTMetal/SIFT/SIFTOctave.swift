//
//  SIFTOctave.swift
//  SkyLight
//
//  Created by Luke Van In on 2023/01/03.
//

import Foundation
import Metal

import MetalShaders


struct SIFTGradient {
    
    static let zero = SIFTGradient(orientation: 0, magnitude: 0)
    
    let orientation: Float
    let magnitude: Float
}

private let maximumNumberOfExtrema = 4096

private let maximumNumberOfKeypoints = 4096

private let maximumNumberOfDescriptors = 2048


final class SIFTOctave {
    
    let scale: DifferenceOfGaussians.Octave
    
//    let keypointTextures: MTLTexture
//    let keypointImages: [Image<Float>]

    let gradientTextures: MTLTexture

    private let device: MTLDevice
    private let extremaFunction: SIFTExtremaListFunction
    private let gradientFunction: SIFTGradientKernel
    private let interpolateFunction: SIFTInterpolateKernel
    private let orientationFunction: SIFTOrientationKernel
    private let descriptorFunction: SIFTDescriptorKernel
    
    private let extremaOutputBuffer: Buffer<SIFTExtremaResult>

    private let orientationInputBuffer: Buffer<SIFTOrientationKeypoint>
    private let orientationOutputBuffer: Buffer<SIFTOrientationResult>
    private let orientationParametersBuffer: Buffer<SIFTOrientationParameters>
    
    private let descriptorInputBuffer: Buffer<SIFTDescriptorInput>
    private let descriptorOutputBuffer: Buffer<SIFTDescriptorResult>
    private let descriptorParametersBuffer: Buffer<SIFTDescriptorParameters>

    private let interpolateInputBuffer: Buffer<SIFTInterpolateInputKeypoint>
    private let interpolateOutputBuffer: Buffer<SIFTInterpolateOutputKeypoint>
    private let interpolateParametersBuffer: Buffer<SIFTInterpolateParameters>

    init(
        device: MTLDevice,
        scale: DifferenceOfGaussians.Octave,
        gradientFunction: SIFTGradientKernel
    ) {
        self.device = device
        self.scale = scale
        self.gradientFunction = gradientFunction

//        let keypointTextures = {
//            let textureDescriptor: MTLTextureDescriptor = {
//                let descriptor = MTLTextureDescriptor()
//                descriptor.textureType = .type2DArray
//                descriptor.pixelFormat = .r32Float
//                descriptor.width = scale.size.width
//                descriptor.height = scale.size.height
//                descriptor.arrayLength = scale.numberOfScales
//                descriptor.mipmapLevelCount = 1
//                descriptor.usage = [.shaderRead, .shaderWrite]
//                descriptor.storageMode = .shared
//                return descriptor
//            }()
//            let texture = device.makeTexture(descriptor: textureDescriptor)!
//            texture.label = "siftKeypointExtremaTexture"
//            return texture
//        }()
//        self.keypointTextures = keypointTextures

        let gradientTextures = {
            let textureDescriptor: MTLTextureDescriptor = {
                let descriptor = MTLTextureDescriptor()
                descriptor.textureType = .type2DArray
                descriptor.pixelFormat = .rg32Float
                descriptor.width = scale.size.width
                descriptor.height = scale.size.height
                descriptor.arrayLength = scale.gaussianTextures.arrayLength
                descriptor.mipmapLevelCount = 1
                descriptor.usage = [.shaderRead, .shaderWrite]
                descriptor.storageMode = .shared
                return descriptor
            }()
            let texture = device.makeTexture(descriptor: textureDescriptor)!
            texture.label = "siftGradientTexture"
            return texture
        }()
        self.gradientTextures = gradientTextures
        
        self.extremaFunction = SIFTExtremaListFunction(
            device: device
        )
        
        self.interpolateFunction = SIFTInterpolateKernel(
            device: device
        )

        self.orientationFunction = SIFTOrientationKernel(
            device: device
        )

        self.descriptorFunction = SIFTDescriptorKernel(
            device: device
        )
        
        self.extremaOutputBuffer = Buffer<SIFTExtremaResult>(
            device: device,
            label: "siftExtremaOutputBuffer",
            capacity: maximumNumberOfExtrema
        )
        
        self.interpolateInputBuffer = Buffer<SIFTInterpolateInputKeypoint>(
            device: device,
            label: "siftInterpiolationInputBuffer",
            capacity: maximumNumberOfKeypoints
        )
        self.interpolateOutputBuffer = Buffer<SIFTInterpolateOutputKeypoint>(
            device: device,
            label: "siftInterpolationOutputBuffer",
            capacity: maximumNumberOfKeypoints
        )
        self.interpolateParametersBuffer = Buffer<SIFTInterpolateParameters>(
            device: device,
            label: "siftInterpolationParametersBuffer",
            capacity: 1
        )

        self.orientationInputBuffer = Buffer<SIFTOrientationKeypoint>(
            device: device,
            label: "siftOrientationInputBuffer",
            capacity: maximumNumberOfKeypoints
        )
        self.orientationOutputBuffer = Buffer<SIFTOrientationResult>(
            device: device,
            label: "siftOrientationOutputBuffer",
            capacity: maximumNumberOfKeypoints
        )
        self.orientationParametersBuffer = Buffer<SIFTOrientationParameters>(
            device: device,
            label: "siftOrientationParametersBuffer",
            capacity: 1
        )

        self.descriptorInputBuffer = Buffer<SIFTDescriptorInput>(
            device: device,
            label: "siftDescriptorsInputBuffer",
            capacity: maximumNumberOfDescriptors
        )
        self.descriptorOutputBuffer = Buffer<SIFTDescriptorResult>(
            device: device,
            label: "siftDescriptorsOutputBuffer",
            capacity: maximumNumberOfDescriptors
        )
        self.descriptorParametersBuffer = Buffer<SIFTDescriptorParameters>(
            device: device,
            label: "siftDescriptorsParametersBuffer",
            capacity: 1
        )
    }
    
    func encode(commandBuffer: MTLCommandBuffer) {
        encodeExtrema(commandBuffer: commandBuffer)
        encodeGradients(commandBuffer: commandBuffer)
    }
    
    private func encodeExtrema(commandBuffer: MTLCommandBuffer) {
        extremaFunction.encode(
            commandBuffer: commandBuffer,
            inputTexture: scale.differenceTextures,
            outputBuffer: extremaOutputBuffer
        )
    }
    
    private func encodeGradients(commandBuffer: MTLCommandBuffer) {
        gradientFunction.encode(
            commandBuffer: commandBuffer,
            inputTexture: scale.gaussianTextures,
            outputTexture: gradientTextures
        )
    }
    
    func getKeypoints() -> Buffer<SIFTExtremaResult> {
        let numberOfKeypoints = extremaFunction.indexBuffer[0]
        extremaFunction.indexBuffer[0] = 0
        extremaOutputBuffer.allocate(Int(numberOfKeypoints))
        return extremaOutputBuffer
    }
    
    func interpolateKeypoints(commandQueue: MTLCommandQueue, keypoints: Buffer<SIFTExtremaResult>) -> [SIFTKeypoint] {
        let sigmaRatio = scale.sigmas[1] / scale.sigmas[0]
        
        interpolateInputBuffer.allocate(keypoints.count)
        interpolateOutputBuffer.allocate(keypoints.count)
        interpolateParametersBuffer.allocate(1)
        
        interpolateParametersBuffer[0] = SIFTInterpolateParameters(
            dogThreshold: 0.0133, // configuration.differenceOfGaussiansThreshold,
            maxIterations: 5, // Int32(configuration.maximumInterpolationIterations),
            maxOffset: 0.6,
            width: Int32(scale.size.width),
            height: Int32(scale.size.height),
            octaveDelta: scale.delta,
            edgeThreshold: 10.0, // configuration.edgeThreshold
            numberOfScales: Int32(scale.numberOfScales)
        )

        // Copy keypoints to metal buffer
        #warning("TODO: Copy buffer memory from extrema results, or just pass buffer directly")
        for j in 0 ..< keypoints.count {
            let keypoint = keypoints[j]
            interpolateInputBuffer[j] = SIFTInterpolateInputKeypoint(
                x: Int32(keypoint.x),
                y: Int32(keypoint.y),
                scale: Int32(keypoint.scale)
            )
        }
        
        //
        measure(name: "interpolateKeypoints") {
            let commandBuffer = commandQueue.makeCommandBuffer()!
            commandBuffer.label = "siftInterpolationCommandBuffer"
            
            interpolateFunction.encode(
                commandBuffer: commandBuffer,
                parameters: interpolateParametersBuffer,
                differenceTextures: scale.differenceTextures,
                inputKeypoints: interpolateInputBuffer,
                outputKeypoints: interpolateOutputBuffer
            )
            
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
        }        

        //
        var output = [SIFTKeypoint]()
        for k in 0 ..< interpolateOutputBuffer.count {
            let p = interpolateOutputBuffer[k]
            guard p.converged != 0 else {
//                print("octave \(scale.o) keypoint \(k) not converged \(p.alphaX) \(p.alphaY) \(p.alphaZ)")
                continue
            }
//            print("octave \(scale.o) keypoint \(k) converged \(p.alphaX) \(p.alphaY) \(p.alphaZ)")

            let keypoint = SIFTKeypoint(
                octave: scale.o,
                scale: Int(p.scale),
                subScale: p.subScale,
                scaledCoordinate: SIMD2<Int>(
                    x: Int(p.relativeX),
                    y: Int(p.relativeY)
                ),
                absoluteCoordinate: SIMD2<Float>(
                    x: p.absoluteX,
                    y: p.absoluteY
                ),
                sigma: scale.sigmas[Int(p.scale)] * pow(sigmaRatio, p.subScale),
                value: p.value
            )
            output.append(keypoint)
        }
        return output
    }
    
    func getKeypointOrientations(commandQueue: MTLCommandQueue, keypoints: [SIFTKeypoint]) -> [SIFTKeypointOrientations] {
        
        orientationInputBuffer.allocate(keypoints.count)
        orientationOutputBuffer.allocate(keypoints.count)
        orientationParametersBuffer.allocate(1)

        let parameters = SIFTOrientationParameters(
            delta: scale.delta,
            lambda: 1.5,
            orientationThreshold: 0.8
        )
        orientationParametersBuffer[0] = parameters

        let minX = Float(1)
        let minY = Float(1)
        let maxX = Float(scale.size.width - 2)
        let maxY = Float(scale.size.height - 2)

        // Copy keypoints to metal buffer
        var i = 0
        for k in 0 ..< keypoints.count {
            let keypoint = keypoints[k]
            let x = Float(keypoint.absoluteCoordinate.x) / parameters.delta
            let y = Float(keypoint.absoluteCoordinate.y) / parameters.delta
            let sigma = keypoint.sigma / parameters.delta
            let r = ceil(3 * parameters.lambda * sigma)

            // Reject keypoint outside of the image bounds
            if (floor(x - r) < minX) {
                continue
            }
            if (ceil(x + r) > maxX) {
                continue
            }
            if (floor(y - r) < minY) {
                continue
            }
            if (ceil(y + r) > maxY) {
                continue
            }

            orientationInputBuffer[i] = SIFTOrientationKeypoint(
                index: Int32(k),
                absoluteX: Int32(keypoint.absoluteCoordinate.x),
                absoluteY: Int32(keypoint.absoluteCoordinate.y),
                scale: Int32(keypoint.scale),
                sigma: keypoint.sigma
            )
            i += 1
        }
        let totalKeypoints = i
        
        guard totalKeypoints > 0 else {
            return []
        }
        
        //
        capture(commandQueue: commandQueue, capture: false) {
            let commandBuffer = commandQueue.makeCommandBuffer()!
            commandBuffer.label = "siftOrientationCommandBuffer"
            
            orientationFunction.encode(
                commandBuffer: commandBuffer,
                parameters: orientationParametersBuffer,
                gradientTextures: gradientTextures,
                inputKeypoints: orientationInputBuffer,
                outputKeypoints: orientationOutputBuffer
            )
            
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
        }

        //
        var output = [SIFTKeypointOrientations]()
        for k in 0 ..< totalKeypoints {
            var result = orientationOutputBuffer[k]
            let count = Int(result.count)
            var orientations = Array<Float>(repeating: 0, count: count)
            withUnsafePointer(to: &result.orientations) { p in
                let p = UnsafeRawPointer(p).assumingMemoryBound(to: Float.self)
                for i in 0 ..< count {
                    orientations[i] = p[i]
                }
            }
            let item = SIFTKeypointOrientations(
                keypoint: keypoints[Int(result.keypoint)],
                orientations: orientations
            )
            output.append(item)
        }
        return output
    }
    
    func getDescriptors(commandQueue: MTLCommandQueue, orientationOctave: [SIFTKeypointOrientations]) -> [SIFTDescriptor] {
        
        let descriptorCount = orientationOctave.reduce(into: 0) { $0 += $1.orientations.count }

        guard descriptorCount > 0 else {
            return []
        }
        
        descriptorInputBuffer.allocate(descriptorCount)
        descriptorOutputBuffer.allocate(descriptorCount)
        descriptorParametersBuffer.allocate(1)
        
        let parameters = SIFTDescriptorParameters(
            delta: scale.delta,
            scalesPerOctave: 3,
            width: Int32(scale.size.width),
            height: Int32(scale.size.height)
        )
        descriptorParametersBuffer[0] = parameters

//        let minX = 1
//        let minY = 1
//        let maxX = scale.size.width - 2
//        let maxY = scale.size.height - 2

        // Copy keypoints to metal buffer
        var i = 0
        for k in 0 ..< orientationOctave.count {
            let item = orientationOctave[k]
            let keypoint = item.keypoint
            for orientation in item.orientations {
                descriptorInputBuffer[i] = SIFTDescriptorInput(
                    keypoint: Int32(k),
                    absoluteX: Int32(keypoint.absoluteCoordinate.x),
                    absoluteY: Int32(keypoint.absoluteCoordinate.y),
                    scale: Int32(keypoint.scale),
                    subScale: keypoint.subScale,
                    theta: orientation
                )
                i += 1
            }
            #warning("TODO: Discard keypoint if it is too close to the boundary")
//            let x = Int((Float(keypoint.absoluteCoordinate.x) / parameters.delta).rounded())
//            let y = Int((Float(keypoint.absoluteCoordinate.y) / parameters.delta).rounded())
//            let sigma = keypoint.sigma / parameters.delta
//            let r = Int(ceil(3 * parameters.lambda * sigma))
//
//            // Reject keypoint outside of the image bounds
//            if ((x - r) < minX) {
//                continue
//            }
//            if ((x + r) > maxX) {
//                continue
//            }
//            if ((y - r) < minY) {
//                continue
//            }
//            if ((y + r) > maxY) {
//                continue
//            }
        }
        
        //
//        let captureDescriptor = MTLCaptureDescriptor()
//        captureDescriptor.captureObject = commandQueue
//        captureDescriptor.destination = .developerTools
//        let captureManager = MTLCaptureManager.shared()
//        try! captureManager.startCapture(with: captureDescriptor)

        let commandBuffer = commandQueue.makeCommandBuffer()!
        commandBuffer.label = "siftDescriptorsCommandBuffer"
        
        descriptorFunction.encode(
            commandBuffer: commandBuffer,
            parameters: descriptorParametersBuffer,
            gradientTextures: gradientTextures,
            inputKeypoints: descriptorInputBuffer,
            outputDescriptors: descriptorOutputBuffer
        )
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        let elapsedTime = commandBuffer.gpuEndTime - commandBuffer.gpuStartTime
//        print("getDescriptors: Command buffer \(String(format: "%0.4f", elapsedTime)) seconds")

        //
        let numberOfFeatures = 128
        var output = [SIFTDescriptor]()
        for k in 0 ..< descriptorCount {
            var result = descriptorOutputBuffer[k]
            let keypoint = orientationOctave[Int(result.keypoint)].keypoint
            let theta = result.theta
            var features = Array<Int>(repeating: 0, count: numberOfFeatures)
            withUnsafePointer(to: &result.features) { p in
                let p = UnsafeRawPointer(p).assumingMemoryBound(to: Int32.self)
                for i in 0 ..< numberOfFeatures {
                    features[i] = Int(p[i])
                }
            }
            let descriptor = SIFTDescriptor(
                keypoint: keypoint,
                theta: theta,
                features: IntVector(features)
            )
            output.append(descriptor)
        }
//        print("getDescriptors: \(output.count) descriptors")
        return output
    }
}
