//
//  DifferenceOfGaussiansTests.swift
//  SkyLightTests
//
//  Created by Luke Van In on 2022/12/24.
//

import XCTest
import CoreImage
import CoreImage.CIFilterBuiltins
import MetalPerformanceShaders

@testable import SIFTMetal

/*

final class DifferenceOfGaussiansTests: SharedTestCase {
    
    
    func testComputeDifferenceOfGaussians() throws {
        
        let referenceGaussianImages = try loadScaleSpaceTextures(
            name: "scalespace_butterfly",
            extension: "png",
            octaves: 1,
            scalesPerOctave: 5
        )

        let inputTexture = try device.loadTexture(name: "butterfly", extension: "png", srgb: false)
        attachImage(
            name: "input",
            uiImage: ciContext.makeUIImage(
                ciImage: CIImage(
                    mtlTexture: inputTexture,
                    options: [
                        CIImageOption.colorSpace: CGColorSpace(name: CGColorSpace.genericGrayGamma2_2)!,
                    ]
                )!
                    .oriented(.downMirrored)
                    .smearColor()
            )
        )
        
        let configuration = DifferenceOfGaussians.Configuration(
            inputDimensions: IntegralSize(
                width: Int(inputTexture.width),
                height: Int(inputTexture.height)
            )
        )
        let subject = DifferenceOfGaussians(
            device: device,
            configuration: configuration
        )
        
        print("Encoding")
        let commandBuffer = commandQueue.makeCommandBuffer()!
        subject.encode(
            commandBuffer: commandBuffer,
            originalTexture: inputTexture
        )
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        print("Saving attachments")
        
        
        var resultGaussainImages = [MTLTexture]()
//        for (o, octave) in subject.octaves.enumerated() {
//            for (s, texture) in octave.gaussianTextures.enumerated() {
//                resultGaussainImages.append(texture)
//            }
//        }
        
        compare(
            referenceImages: referenceGaussianImages,
            testImages: resultGaussainImages
        )

        
//        attachImage(
//            name: "v(1, 0): luminosity",
//            uiImage: makeUIImage(
//                ciImage: smearColor(
//                    ciImage: makeCIImage(
//                        texture: subject.luminosityTexture
//                    )
//                ),
//                context: ciContext
//            )
//        )
        
//        attachImage(
//            name: "v(1, 0): scaled",
//            uiImage: makeUIImage(
//                ciImage: smearColor(
//                    ciImage: makeCIImage(
//                        texture: subject.scaledTexture
//                    )
//                ),
//                context: ciContext
//            )
//        )

//        attachImage(
//            name: "v(1, 0): seed",
//            uiImage: makeUIImage(
//                ciImage: smearColor(
//                    ciImage: makeCIImage(
//                        texture: subject.seedTexture
//                    )
//                ),
//                context: ciContext
//            )
//        )

//        for (o, octave) in subject.octaves.enumerated() {
//
//            for (s, texture) in octave.gaussianTextures.enumerated() {
//
//                attachImage(
//                    name: "v[\(o), \(s)]",
//                    uiImage: makeUIImage(
//                        ciImage: smearColor(
//                            ciImage: makeCIImage(
//                                texture: texture
//                            )
//                        ),
//                        context: ciContext
//                    )
//                )
//            }
//
//            for (s, texture) in octave.differenceTextures.enumerated() {
//
//                attachImage(
//                    name: "w[\(o), \(s)]",
//                    uiImage: makeUIImage(
//                        ciImage: mapColor(
//                            ciImage: normalizeColor(
//                                ciImage: smearColor(
//                                    ciImage: makeCIImage(
//                                        texture: texture
//                                    )
//                                )
//                            )
//                        ),
//                        context: ciContext
//                    )
//                )
//            }
//        }
    }
    
    private func compare(
        referenceImages: [CIImage],
        testImages testTextures: [MTLTexture]
    ) {
//        let referenceImages = referenceTextures.map {
//            CIImage(mtlTexture: $0)!.oriented(.downMirrored)
//        }
        
        let testImages = testTextures.map {
            let image = CIImage(
                mtlTexture: $0,
                options: [
                    CIImageOption.colorSpace: CGColorSpace(name: CGColorSpace.genericGrayGamma2_2)!,
                ]
            )!
            let outputImage = image
                .settingAlphaOne(in: image.extent)
                .oriented(.downMirrored)
                .smearColor()
            return outputImage
        }

        XCTAssert(referenceImages.count == referenceImages.count)

        let differenceFilter = CIFilter.colorAbsoluteDifference()
        
        let colorFilter = CIFilter.colorControls()
        colorFilter.brightness = 0.5
        colorFilter.contrast = 2.0
        colorFilter.saturation = 1

        let thresholdFilter = CIFilter.colorThreshold()
//        thresholdFilter.threshold = 0.005
        thresholdFilter.threshold = 0.005
        
        let clampFilter = CIFilter.colorClamp()
//        clampFilter.minComponents = CIVector(x: 0.005, y: 0.005, z: 0.005, w: 0)
//        clampFilter.maxComponents = CIVector(x: 0.995, y: 0.995, z: 0.995, w: 1)
        clampFilter.minComponents = CIVector(x: 0, y: 0, z: 0, w: 0)
        clampFilter.maxComponents = CIVector(x: 1, y: 1, z: 1, w: 1)

        for i in 0 ..< referenceImages.count {
            let referenceImage = referenceImages[i]
            let testImage = testImages[i]

            let scaledTestImage: CIImage
            
            if testImage.extent.size != referenceImage.extent.size {
                scaledTestImage = testImage.samplingNearest().transformed(
                    by: .identity.scaledBy(
                        x: referenceImage.extent.width / testImage.extent.width,
                        y: referenceImage.extent.height / testImage.extent.height
                    )
                )
            }
            else {
                scaledTestImage = testImage
            }
            
            clampFilter.inputImage = scaledTestImage
            differenceFilter.inputImage = clampFilter.outputImage

            clampFilter.inputImage = referenceImage
            differenceFilter.inputImage2 = clampFilter.outputImage
            
            colorFilter.inputImage = differenceFilter.outputImage
            
            thresholdFilter.inputImage = differenceFilter.outputImage

            let differenceImage = colorFilter.outputImage!
            let thresholdImage = thresholdFilter.outputImage!

            attachImage(
                name: "scalespace \(i): reference",
                uiImage: ciContext.makeUIImage(ciImage: referenceImage)
            )

            attachImage(
                name: "scalespace \(i): test",
                uiImage: ciContext.makeUIImage(ciImage: scaledTestImage)
            )

            attachImage(
                name: "scalespace \(i): difference",
                uiImage: ciContext.makeUIImage(ciImage: differenceImage)
            )

            attachImage(
                name: "scalespace \(i): threshold",
                uiImage: ciContext.makeUIImage(ciImage: thresholdImage)
            )
        }
    }
    
    private func loadScaleSpaceTextures(
        name: String,
        extension: String,
        octaves: Int,
        scalesPerOctave: Int,
        file: StaticString = #file,
        line: UInt = #line
    ) throws -> [CIImage] {
        var output = [CIImage]()
        for o in 0 ..< octaves {
            for s in 0 ..< scalesPerOctave {
                let octaveName = String(format: "%03d", o)
                let scaleName = String(format: "%03d", s)
                let filename = "\(name)_o\(octaveName)_s\(scaleName)"
                let image = try CIImage(name: filename, extension: `extension`)
//                let image = try device.loadTexture(name: filename, extension: `extension`)
                output.append(image)
            }
        }
        return output
    }
}
*/

