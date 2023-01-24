//
//  DescriptorTests.swift
//  SkyLightTests
//
//  Created by Luke Van In on 2022/12/26.
//

import XCTest
import simd

@testable import SIFTMetal


final class DescriptorTests: SharedTestCase {
    
    func testDescriptors() throws {
        
        let inputTexture = try device.loadTexture(name: "butterfly", extension: "png", srgb: false)
        let configuration = SIFT.Configuration(
            inputSize: IntegralSize(
                width: inputTexture.width,
                height: inputTexture.height
            )
        )
        let subject = SIFT(device: device, configuration: configuration)
        let keypoints = subject.getKeypoints(inputTexture)
        let descriptorOctaves = subject.getDescriptors(keypointOctaves: keypoints)
        let foundDescriptors = Array(descriptorOctaves.joined())
        print("Found", foundDescriptors.count, "descriptors")

        print("loading reference desriptors")
        let referenceDescriptors = try loadDescriptors(filename: "butterfly-descriptors")
        
        print("rendering image")
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

        attachImage(
            name: "descriptors",
            uiImage: drawDescriptors(
                sourceImage: referenceImage,
                referenceDescriptors: referenceDescriptors,
                foundDescriptors: foundDescriptors
            )
        )
    }
    
    func testDescriptorsPerformance() throws {
        
        let inputTexture = try device.loadTexture(name: "butterfly", extension: "png", srgb: false)
        let configuration = SIFT.Configuration(
            inputSize: IntegralSize(
                width: inputTexture.width,
                height: inputTexture.height
            )
        )
        let subject = SIFT(device: device, configuration: configuration)
        measure {
            let keypoints = subject.getKeypoints(inputTexture)
            let descriptorOctaves = subject.getDescriptors(keypointOctaves: keypoints)
        }
    }
    
    private func matchDescriptors(detected: [SIFTDescriptor], reference: [SIFTDescriptor]) {
        
        let matches = SIFTDescriptor.match(
            source: detected,
            target: reference,
            absoluteThreshold: 300,
            relativeThreshold: 0.6
        )
        
        let rate = Float(matches.count) / Float(detected.count)
        print("found \(matches.count) out of \(detected.count) = \(rate * 100)%")
        XCTAssertGreaterThanOrEqual(rate, 80.0)
    }
    
    func testMatches() throws {
        
        let inputTexture = try device.loadTexture(name: "butterfly", extension: "png", srgb: false)
        let configuration = SIFT.Configuration(
            inputSize: IntegralSize(
                width: inputTexture.width,
                height: inputTexture.height
            )
        )
        let subject = SIFT(device: device, configuration: configuration)
        let keypoints = subject.getKeypoints(inputTexture)
        let descriptorOctaves = subject.getDescriptors(keypointOctaves: keypoints)
        let foundDescriptors = Array(descriptorOctaves.joined())
        print("Found", foundDescriptors.count, "descriptors")

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

        let referenceDescriptors = try loadDescriptors(filename: "butterfly-descriptors")
        print("Loaded \(referenceDescriptors.count) reference descriptors")
        
        let matches = SIFTDescriptor.match(
            source: foundDescriptors,
            target: referenceDescriptors,
            absoluteThreshold: 300,
            relativeThreshold: 0.6
        )

        print("Found \(matches.count) matches")

        print("drawing matches")
        attachImage(
            name: "matches",
            uiImage: drawMatches(
                sourceImage: referenceImage,
                targetImage: referenceImage,
                matches: matches
            )
        )
    }
    
    func testMatchesPerformance() throws {
        let inputTexture = try device.loadTexture(name: "butterfly", extension: "png", srgb: false)
        let configuration = SIFT.Configuration(
            inputSize: IntegralSize(
                width: inputTexture.width,
                height: inputTexture.height
            )
        )
        let subject = SIFT(device: device, configuration: configuration)
        let keypoints = subject.getKeypoints(inputTexture)
        let descriptorOctaves = subject.getDescriptors(keypointOctaves: keypoints)
        let foundDescriptors = Array(descriptorOctaves.joined())
        print("Found", foundDescriptors.count, "descriptors")

        let referenceDescriptors = try loadDescriptors(filename: "butterfly-descriptors")
        print("Loaded \(referenceDescriptors.count) reference descriptors")
        
        // matchDescriptors(detected: foundDescriptors, reference: referenceDescriptors)
        
        print("Finding matches")
        measure {
            _ = SIFTDescriptor.match(
                source: foundDescriptors,
                target: referenceDescriptors,
                absoluteThreshold: 300,
                relativeThreshold: 0.6
            )
        }
    }
    
    private func filter<E>(_ input: Array<E>, every step: Int = 10, limit: Int = 10000) -> [E] {
        Array(input.enumerated().filter({ $0.offset % step == 0 }).map({ $0.element }).prefix(limit))
    }
    
    
    private func loadDescriptors(filename: String, extension: String = "txt") throws -> [SIFTDescriptor] {
        var descriptors = [SIFTDescriptor]()
        
        let fileURL = bundle.url(forResource: filename, withExtension: `extension`)!
        let data = try Data(contentsOf: fileURL)
        let string = String(data: data, encoding: .utf8)!
        let lines = string.split(separator: "\n")
        
        for line in lines {
            let components = line.split(separator: " ")
            guard components.count > 0 else {
                continue
            }
            let y = Float(components[0])!
            let x = Float(components[1])!
            let s = Float(components[2])!
            let theta = Float(components[3])!
            var features = Array<Int>(repeating: 0, count: 4 * 4 * 8)
            for i in 0 ..< features.count {
                features[i] = Int(components[i + 4])!
            }
                
            let descriptor = SIFTDescriptor(
                keypoint: SIFTKeypoint(
                    octave: 0,
                    scale: 0,
                    subScale: 0,
                    scaledCoordinate: .zero,
                    absoluteCoordinate: SIMD2<Float>(x: x, y: y),
                    sigma: s,
                    value: 0
                ),
                theta: theta,
//                rawFeatures: [],
                features: IntVector(features)
            )
            descriptors.append(descriptor)
        }
        
        return descriptors
    }
    
}
