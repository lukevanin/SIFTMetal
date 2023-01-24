//
//  SIFT.swift
//  SkyLight
//
//  Created by Luke Van In on 2022/12/18.
//

import Foundation
import OSLog
import Metal

import MetalShaders

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier!,
    category: "SIFT"
)


///
/// Performs the Scale Invariant Feature Transform (SIFT) on an image.
///
/// Extracts a set of robust feature descriptors for identifiable points on an image using the SIFT
/// algorithm[1]. Uses Metal compute shaders to execute tasks using GPU hardware.
///
/// This implementation is mostly based on the "Anatomy of the SIFT method"[2] paper and source code
/// published by the Image Processing Online (IPOL) Journal. The implementation has come notable
/// charactaristics not explicitly described in the paper. Their relevance toward the accuracy or correctness of
/// the implementation is not indicated.
/// - sRGB images are not converted to linear grayscale space for analysis. The SIFT analysis is performed
/// on the lograithmic (^2.2) color space.
/// - RGB colors are converted to grayscale using the ITU BT.709-5 (NTSC) color conversion formula.
/// - The convolution kernel used for Gaussian blur is centered symmetrically on pixels. This differers to the
/// positioning used by convolution kernels provided by Metal Performance Shaders. A custom convolution
/// kernel is used to provide similarity to the IPOL implementation.
///
/// Note: A novel method is used for matching SIFT descriptors, which is different to the methods used by
/// Lowe and IPOL. Our method matches descriptors using a trie structure with leaf nodes forming a linked
/// list. Construction of the trie takes O(n) time. Queries run in O(1) constant time.
///
/// [1]: https://www.cs.ubc.ca/~lowe/papers/ijcv04.pdf "Distinctive Image Features from Scale-Invariant Keypoints", Lowe, 2004
/// [2]: http://www.ipol.im/pub/art/2014/82/article.pdf "Anatomy of the SIFT Method", Rey-Otero & Delbracio, 2014
///
/// Additional references:
/// See: https://www.cs.ubc.ca/~lowe/keypoints/
/// See: https://en.wikipedia.org/wiki/Scale-invariant_feature_transform
/// See: https://docs.opencv.org/4.x/da/df5/tutorial_py_sift_intro.html
/// See: https://www.youtube.com/watch?v=4AvTMVD9ig0&t=232
/// See: https://www.youtube.com/watch?v=U0wqePj4Mx0
/// See: https://www.youtube.com/watch?v=ram-jbLJjFg&t=2s
/// See: https://www.youtube.com/watch?v=NPcMS49V5hg
/// See: https://github.com/robwhess/opensift
/// See: https://medium.com/jun94-devpblog/cv-13-scale-invariant-local-feature-extraction-3-sift-315b5de72d48
///
public final class SIFT {
    
    public struct Configuration {
        
        // Dimensions of the input image.
        var inputSize: IntegralSize
        
        // Threshold over the Difference of Gaussians response (value
        // relative to scales per octave = 3)
        var differenceOfGaussiansThreshold: Float = 0.0133

        // Threshold over the ratio of principal curvatures (edgeness).
        var edgeThreshold: Float = 10.0
        
        // Maximum number of consecutive unsuccessful interpolation.
        var maximumInterpolationIterations: Int = 5
        
        // Width of border in which to ignore keypoints
        var imageBorder: Int = 5
        
        // Sets how local is the analysis of the gradient distribution.
        var lambdaOrientation: Float = 1.5
        
        // Number of bins in the orientation histogram.
        var orientationBins: Int = 36
        
        // Threshold for considering local maxima in the orientation histogram.
        var orientationThreshold: Float = 0.8
        
        // Number of iterations used to smooth the orientation histogram
        var orientationSmoothingIterations: Int = 6
        
        // Number of normalized histograms in the normalized patch in the
        // descriptor. This must be a square integer number so that both x
        // and y axes have the same length.
        var descriptorHistogramsPerAxis: Int = 4
        
        // Number of bins in the descriptor histogram.
        var descriptorOrientationBins: Int = 8
        
        // How local the descriptor is (size of the descriptor).
        // Gaussian window of lambdaDescriptor * sigma
        // Descriptor patch width of 2 * lambdaDescriptor * sigma
        var lambdaDescriptor: Float = 6
        
        public init(inputSize: IntegralSize) {
            self.inputSize = inputSize
        }
    }

    let configuration: Configuration
    let dog: DifferenceOfGaussians
    let octaves: [SIFTOctave]
    
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    
    public init(
        device: MTLDevice,
        configuration: Configuration
    ) {
        self.device = device
        
        let dog = DifferenceOfGaussians(
            device: device,
            configuration: DifferenceOfGaussians.Configuration(
                inputDimensions: configuration.inputSize
            )
        )
        let octaves: [SIFTOctave] = {
            let gradientFunction = SIFTGradientKernel(device: device)

            var octaves = [SIFTOctave]()
            for scale in dog.octaves {
                let octave = SIFTOctave(
                    device: device,
                    scale: scale,
                    gradientFunction: gradientFunction
                )
                octaves.append(octave)
            }
            return octaves
        }()
        
        self.commandQueue = device.makeCommandQueue()!
        self.configuration = configuration
        self.dog = dog
        self.octaves = octaves
    }

    // MARK: Keypoints
    
    public func getKeypoints(_ inputTexture: MTLTexture) -> [[SIFTKeypoint]] {
        findKeypoints(inputTexture: inputTexture)
        let keypointOctaves = getKeypointsFromOctaves()
        let interpolatedKeypoints = interpolateKeypoints(keypointOctaves: keypointOctaves)
        return interpolatedKeypoints
    }
    
    private func findKeypoints(inputTexture: MTLTexture) {
        measure(name: "findKeypoints") {
            capture(commandQueue: commandQueue, capture: false) {
                let commandBuffer = commandQueue.makeCommandBuffer()!
                commandBuffer.label = "siftKeypointsCommandBuffer"
                
                dog.encode(
                    commandBuffer: commandBuffer,
                    originalTexture: inputTexture
                )
                
                for octave in octaves {
                    octave.encode(
                        commandBuffer: commandBuffer
                    )
                }
                
                commandBuffer.commit()
                commandBuffer.waitUntilCompleted()
            }
        }
    }
    
    private func getKeypointsFromOctaves() -> [Buffer<SIFTExtremaResult>] {
        var output = [Buffer<SIFTExtremaResult>]()
        measure(name: "getKeypointsFromOctaves") {
            for octave in octaves {
                let keypoints = octave.getKeypoints()
                output.append(keypoints)
            }
        }
        let totalKeypoints = output.reduce(into: 0) { $0 += $1.count }
        logger.info("getKeypointsFromOctaves: Found \(totalKeypoints) keypoints")
        return output
    }
    
    private func interpolateKeypoints(keypointOctaves: [Buffer<SIFTExtremaResult>]) -> [[SIFTKeypoint]] {
        var output = [[SIFTKeypoint]]()
        measure(name: "interpolateKeypoints") {
            for o in 0 ..< keypointOctaves.count {
                let keypoints = keypointOctaves[o]
                output.append(octaves[o].interpolateKeypoints(
                    commandQueue: commandQueue,
                    keypoints: keypoints
                ))
            }
        }
        return output
    }

    
    // MARK: Descriptora
    
    public func getDescriptors(keypointOctaves: [[SIFTKeypoint]]) -> [[SIFTDescriptor]] {
        precondition(keypointOctaves.count == octaves.count)
        
        // Get all orientations for all keypoints.
        var orientationOctaves = [[SIFTKeypointOrientations]]()
        measure(name: "getDescriptors(orientations)") {
            for i in 0 ..< octaves.count {
                let octave = octaves[i]
                let keypoints = keypointOctaves[i]
                let orientationOctave = octave.getKeypointOrientations(
                    commandQueue: commandQueue,
                    keypoints: keypoints
                )
                orientationOctaves.append(orientationOctave)
            }
        }
        
        // Get descriptors for each orientation.
        var output: [[SIFTDescriptor]] = []
        measure(name: "getDescriptors(descriptors)") {
            for i in 0 ..< octaves.count {
                let octave = octaves[i]
                let orientationOctave = orientationOctaves[i]
                let descriptors = octave.getDescriptors(
                    commandQueue: commandQueue,
                    orientationOctave: orientationOctave
                )
                output.append(descriptors)
            }
        }
        return output
    }
}
