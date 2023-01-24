//
//  DifferenceOfGaussians.swift
//  SkyLight
//
//  Created by Luke Van In on 2022/12/20.
//

import Foundation
import OSLog
import Metal
import MetalPerformanceShaders


private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier!,
    category: "DifferenceOfGaussians"
)


public final class DifferenceOfGaussians {
    
    
    public struct Configuration {
        
        // Dimensions of the original image.
        var inputDimensions: IntegralSize
        
        // Blur level of v(1, 0) (seed image). Note that the blur level of
        // v(0, 0) will be higher.
        var sigmaMinimum: Float = 0.8
        
        // The sampling distance in image v(0, 1) (see image). The value 0.5
        // corresponds to a 2× interpolation.
        var deltaMinimum: Float = 0.5
        
        // Assumed blur level in uInput (input image).
        var sigmaInput: Float = 0.5
        
        // Number of octaves (limited by the image size )).
        // ⌊log2(min(w, h) / deltaMin / 12) + 1⌋
        var numberOfOctaves: Int = 5
        
        // Number of scales per octave.
        // Number of gaussians per octave = scales per octave + 3.
        // Number of differences per octave = scales per octave + 2
        var numberOfScalesPerOctave: Int = 3
        
        public init(inputDimensions: IntegralSize) {
            self.inputDimensions = inputDimensions
        }
    }
    
    
    final class Octave {
        
        let o: Int // octave
        let delta: Float // delta (pixel space, e.g. 0.5 = 2x)
        let numberOfScales: Int
        let sigmas: [Float]
        let size: IntegralSize
        
        let gaussianTextures: MTLTexture
        let differenceTextures: MTLTexture
        
        private let scaleFunction: NearestNeighborDownScaleKernel
        private let gaussianBlurFunctions: GaussianSeriesKernel
        private let subtractFunction: SubtractKernel
        
        init(
            device: MTLDevice,
            o: Int,
            delta: Float,
            size: IntegralSize,
            numberOfScales: Int,
            sigmas: [Float],
            scaleFunction: NearestNeighborDownScaleKernel,
            subtractFunction: SubtractKernel
        ) {

            let numberOfGaussians = numberOfScales + 3
            let numberOfDifferences = numberOfScales + 2

            self.o = o
            self.delta = delta
            self.size = size
            self.numberOfScales = numberOfScales
            self.sigmas = sigmas
            self.scaleFunction = scaleFunction
            self.subtractFunction = subtractFunction

            self.gaussianBlurFunctions = {
                var output = [Float]()
                for s in 1 ..< numberOfGaussians {
                    let sa = sigmas[s - 1]
                    let sb = sigmas[s]
                    let rho = sqrt((sb * sb) - (sa * sa)) / delta
                    // let offset = Int(floor(rho))
                    print(
                        "𝜌[\(s - 1) → \(s)]", "=", rho
                    )
                    output.append(rho)
                }
                let function = GaussianSeriesKernel(
                    device: device,
                    sigmas: output,
                    textureSize: size,
                    arrayLength: numberOfGaussians
                )
                return function
            }()
            
            let gaussianTextures = {
                let textureDescriptor: MTLTextureDescriptor = {
                    let descriptor = MTLTextureDescriptor()
                    descriptor.textureType = .type2DArray
                    descriptor.pixelFormat = .r32Float
                    descriptor.width = size.width
                    descriptor.height = size.height
                    descriptor.arrayLength = numberOfGaussians
                    descriptor.usage = [.shaderRead, .shaderWrite]
                    descriptor.storageMode = .shared
                    return descriptor
                }()
                let texture = device.makeTexture(descriptor: textureDescriptor)!
                texture.label = "gaussianTexture\(size.width)x\(size.height)"
                return texture
            }()
            self.gaussianTextures = gaussianTextures

            let differenceTextures = {
                let textureDescriptor: MTLTextureDescriptor = {
                    let descriptor = MTLTextureDescriptor()
                    descriptor.textureType = .type2DArray
                    descriptor.pixelFormat = .r32Float
                    descriptor.width = size.width
                    descriptor.height = size.height
                    descriptor.arrayLength = numberOfDifferences
                    descriptor.usage = [.shaderRead, .shaderWrite]
                    descriptor.storageMode = .shared
                    return descriptor
                }()
                let texture = device.makeTexture(descriptor: textureDescriptor)!
                texture.label = "differenceTexture\(size.width)x\(size.height)"
                return texture
            }()
            self.differenceTextures = differenceTextures
        }
        
        func encode(commandBuffer: MTLCommandBuffer, inputTexture: MTLTexture) {
            precondition(inputTexture.pixelFormat == .r32Float)
            encodeFirstGaussianTexture(
                commandBuffer: commandBuffer,
                inputTexture: inputTexture
            )
            encodeOtherGaussianTextures(commandBuffer: commandBuffer)
            encodeDifferenceTextures(commandBuffer: commandBuffer)
        }
        
        private func encodeFirstGaussianTexture(
            commandBuffer: MTLCommandBuffer,
            inputTexture: MTLTexture
        ) {
            #warning("TODO: Use nearest neighbor scaling")
            logger.info("Encoding gaussian v(\(self.o), 0)")
            let sourceSize = IntegralSize(
                width: inputTexture.width,
                height: inputTexture.height
            )
            let targetSize = IntegralSize(
                width: gaussianTextures.width,
                height: gaussianTextures.height
            )
            if sourceSize.width == targetSize.width && sourceSize.height == targetSize.height {
                logger.debug("Copy input texture from \(sourceSize.width)x\(sourceSize.height) to \(targetSize.width)x\(targetSize.height)")
                precondition(inputTexture.textureType == .type2D)
                let blitEncoder = commandBuffer.makeBlitCommandEncoder()!
//                blitEncoder.copy(from: inputTexture, to: gaussianTextures[0])
                blitEncoder.copy(
                    from: inputTexture,
                    sourceSlice: 0,
                    sourceLevel: 0,
                    to: gaussianTextures,
                    destinationSlice: 0,
                    destinationLevel: 0,
                    sliceCount: 1,
                    levelCount: 1
                )
                blitEncoder.endEncoding()
            }
            else {
                logger.debug("Scale input texture from \(sourceSize.width)x\(sourceSize.height) to \(targetSize.width)x\(targetSize.height)")
                precondition(inputTexture.textureType == .type2DArray)
                scaleFunction.encode(
                    commandBuffer: commandBuffer,
                    inputTexture: inputTexture,
                    inputSlice: numberOfScales,
                    outputTexture: gaussianTextures,
                    outputSlice: 0
                )
            }
        }
        
        private func encodeOtherGaussianTextures(commandBuffer: MTLCommandBuffer) {
            // logger.info("Encoding gaussian v(\(self.o), \(s)) = G𝜌[\(s - 1) → \(s)] v(\(self.o), \(s - 1))")
            gaussianBlurFunctions.encode(
                commandBuffer: commandBuffer,
                texture: gaussianTextures
            )
        }
        
        private func encodeDifferenceTextures(commandBuffer: MTLCommandBuffer) {
//                logger.info("Encoding difference w(\(self.o), \(i))")
            subtractFunction.encode(
                commandBuffer: commandBuffer,
                inputTexture: gaussianTextures,
                outputTexture: differenceTextures
            )
        }
    }
    
    
    let configuration: Configuration
    
    let luminosityTexture: MTLTexture
    let scaledTexture: MTLTexture
    let seedTexture: MTLTexture
    let octaves: [Octave]

    private let colorConversionFunction: ConvertSRGBToGrayscaleKernel
    private let bilinearScaleFunction: BilinearUpScaleKernel
    private let seedGaussianBlurFunction: GaussianKernel
    
    public init(device: MTLDevice, configuration: Configuration) {
        
        let seedSize = IntegralSize(
            width: Int(Float(configuration.inputDimensions.width) / configuration.deltaMinimum),
            height: Int(Float(configuration.inputDimensions.height) / configuration.deltaMinimum)
        )
        
        self.configuration = configuration

        #warning("FIXME: This currently works in gamma corrected space to match the reference implementation.")
        #warning("TODO: Convert image to linear space before processing. The image should be loaded with sRGB=true.")

        self.colorConversionFunction = {
            let function = ConvertSRGBToGrayscaleKernel(device: device)
            return function
        }()

        self.bilinearScaleFunction = {
            let function = BilinearUpScaleKernel(device: device)
            return function
        }()

        self.seedGaussianBlurFunction = {
            let i = configuration.sigmaMinimum * configuration.sigmaMinimum
            let j = configuration.sigmaInput * configuration.sigmaInput
            let k = sqrt(i - j) / configuration.deltaMinimum
            print("𝜎(1, 0)", "=", k)
            let function = GaussianKernel(device: device, sigma: k)
            return function
        }()

        let inputTextureDescriptor: MTLTextureDescriptor = {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .r32Float,
                width: configuration.inputDimensions.width,
                height: configuration.inputDimensions.height,
                mipmapped: false
            )
            descriptor.usage = [.shaderRead, .shaderWrite]
            descriptor.storageMode = .shared
            return descriptor
        }()

        let seedTextureDescriptor: MTLTextureDescriptor = {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .r32Float,
                width: seedSize.width,
                height: seedSize.height,
                mipmapped: false
            )
            descriptor.usage = [.shaderRead, .shaderWrite]
            descriptor.storageMode = .shared
            return descriptor
        }()

        self.luminosityTexture = {
            let texture = device.makeTexture(
                descriptor: inputTextureDescriptor
            )!
            return texture
        }()

        self.scaledTexture = {
            let texture = device.makeTexture(
                descriptor: seedTextureDescriptor
            )!
            return texture
        }()

        self.seedTexture = {
            let texture = device.makeTexture(
                descriptor: seedTextureDescriptor
            )!
            return texture
        }()
        
        self.octaves = {
            
            let scaleFunction = NearestNeighborDownScaleKernel(device: device)
            let subtractFunction = SubtractKernel(device: device)

            var octaves = [Octave]()
            for o in 0 ..< configuration.numberOfOctaves {
                let delta = configuration.deltaMinimum * pow(2, Float(o))
                let size = IntegralSize(
                    width: Int(Float(configuration.inputDimensions.width) / delta),
                    height: Int(Float(configuration.inputDimensions.height) / delta)
                )
                var sigmas = [Float]()
                for s in 0 ..< configuration.numberOfScalesPerOctave + 3 {
                    let h = delta / configuration.deltaMinimum
                    let i = Float(s) / Float(configuration.numberOfScalesPerOctave)
                    let j = pow(2, i)
                    let sigma = h * configuration.sigmaMinimum * j
                    sigmas.append(sigma)
                }
                print("octave", o, "dimensions", "=", size, "delta", "=", delta, "sigmas", "=", sigmas)
                let octave = Octave(
                    device: device,
                    o: o,
                    delta: delta,
                    size: size,
                    numberOfScales: configuration.numberOfScalesPerOctave,
                    sigmas: sigmas,
                    scaleFunction: scaleFunction,
                    subtractFunction: subtractFunction
                )
                octaves.append(octave)
            }
            return octaves
        }()
    }
    
    public func encode(
        commandBuffer: MTLCommandBuffer,
        originalTexture: MTLTexture
    ) {
        encodeSeedTexture(
            commandBuffer: commandBuffer,
            inputTexture: originalTexture
        )
        encodeOctaves(commandBuffer: commandBuffer)
    }
    
    private func encodeSeedTexture(
        commandBuffer: MTLCommandBuffer,
        inputTexture: MTLTexture
    ) {
        let inputSize = IntegralSize(
            width: inputTexture.width,
            height: inputTexture.height
        )
        let outputSize = IntegralSize(
            width: scaledTexture.width,
            height: scaledTexture.height
        )

        logger.debug("v(1, 0) Convert texture to grayscale")
        colorConversionFunction.encode(
            commandBuffer: commandBuffer,
            inputTexture: inputTexture,
            outputTexture: luminosityTexture
        )

        logger.debug("v(1, 0) Scale texture from \(inputSize.width)x\(inputSize.height) to \(outputSize.width)x\(outputSize.height)")
        bilinearScaleFunction.encode(
            commandBuffer: commandBuffer,
            inputTexture: luminosityTexture,
            outputTexture: scaledTexture
        )
        logger.debug("v(1, 0) Blur texture")
        seedGaussianBlurFunction.encode(
            commandBuffer: commandBuffer,
            inputTexture: scaledTexture,
            outputTexture: seedTexture
        )
    }

    private func encodeOctaves(commandBuffer: MTLCommandBuffer) {
        logger.debug("Encode octave 0")
        octaves[0].encode(
            commandBuffer: commandBuffer,
            inputTexture: seedTexture
        )
        
        for i in 1 ..< octaves.count {
            logger.debug("Encode octave \(i)")
            octaves[i].encode(
                commandBuffer: commandBuffer,
//                inputTexture: octaves[i - 1].gaussianTextures[configuration.numberOfScalesPerOctave]
                inputTexture: octaves[i - 1].gaussianTextures
            )
        }
    }
}
