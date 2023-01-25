//
//  KeypointTests.swift
//  SkyLightTests
//
//  Created by Luke Van In on 2022/12/26.
//

import XCTest

@testable import SIFTMetal


final class KeypointTests: SharedTestCase {
    
    func testKeypoints() throws {
        
        let inputTexture = try device.loadTexture(name: "butterfly", extension: "png", srgb: false)
        let configuration = SIFT.Configuration(
            inputSize: IntegralSize(
                width: inputTexture.width,
                height: inputTexture.height
            )
        )
        let subject = SIFT(device: device, configuration: configuration)
        let octaveKeypoints = subject.getKeypoints(inputTexture)
        let keypoints = Array(octaveKeypoints.joined())
        print("Found", keypoints.count, "keypoints")

//        let referenceKeypoints: [SIFTKeypoint] = []
        let referenceImage: CGImage = {
            let originalImage = CIImage(
                mtlTexture: inputTexture,
                options: [
                    CIImageOption.colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                ]
            )!
                .oriented(.downMirrored)
                .smearColor()
            let cgImage = ciContext.makeCGImage(ciImage: originalImage)
            return cgImage
        }()

//        let referenceKeypoints = try loadKeypoints(filename: "extra_DoGSoftThresh_butterfly")
//        let referenceKeypoints = try loadKeypoints(filename: "extra_ExtrInterp_butterfly")
//        let referenceKeypoints = try loadKeypoints(filename: "extra_DoGThresh_butterfly")
        let referenceKeypoints = try loadKeypoints(filename: "extra_OnEdgeResp_butterfly")
//        let referenceKeypoints = try loadKeypoints(filename: "extra_FarFromBorder_butterfly")
//        let referenceImage = UIImage(named: "butterfly-keypoints-raw")!.cgImage!
//        for i in 0 ..< keypoints.count {
//            var keypoint = keypoints[i]
//            keypoint.x = Float(inputTexture.width) - keypoint.x
//            keypoint.y = Float(inputTexture.height) - keypoint.y
//            keypoints[i] = keypoint
//        }

        let renderer = SIFTRenderer()
        attachImage(
            name: "keypoints",
            uiImage: renderer.drawKeypoints(
                sourceImage: referenceImage,
                referenceKeypoints: referenceKeypoints,
                foundKeypoints: keypoints
            )
        )

//        for (scale, octave) in subject.octaves.enumerated() {
//
//            for (index, texture) in octave.keypointTextures.enumerated() {
//                
//                attachImage(
//                    name: "keypoints(\(scale), \(index))",
//                    uiImage: ciContext.makeUIImage(
//                        ciImage: CIImage(
//                            mtlTexture: texture,
//                            options: [
//                                .colorSpace: CGColorSpace(name: CGColorSpace.genericGrayGamma2_2)!
//                            ]
//                        )!
//                            .oriented(.downMirrored)
//                            .smearColor()
//                    )
//                )
//            }
//
//        }
        
    }
    
    
    private func loadKeypoints(filename: String, extension: String = "txt") throws -> [SIFTKeypoint] {
        var keypoints = [SIFTKeypoint]()
        
        let fileURL = bundle.url(forResource: filename, withExtension: `extension`)!
        let data = try Data(contentsOf: fileURL)
        let string = String(data: data, encoding: .utf8)!
        let lines = string.split(separator: "\n")
        
        for line in lines {
            let components = line.split(separator: " ")
            let y = Float(components[0])!
            let x = Float(components[1])!
            let s = Float(components[2])!
            let keypoint = SIFTKeypoint(
                octave: 0,
                scale: 0,
                subScale: 0,
                scaledCoordinate: .zero,
                absoluteCoordinate: SIMD2<Float>(x: x, y: y),
                sigma: s,
                value: 0
            )
            keypoints.append(keypoint)
        }
        
        return keypoints
    }
    
}
