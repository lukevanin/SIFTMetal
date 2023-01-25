//
//  SharedTestCase.swift
//  SkyLightTests
//
//  Created by Luke Van In on 2022/12/26.
//

import XCTest
import CoreImage
import CoreImage.CIFilterBuiltins
import MetalKit
import MetalPerformanceShaders

@testable import SIFTMetal


let bundle = Bundle.module


extension MTLDevice {
    
    func loadTexture(url: URL, srgb: Bool = true) throws -> MTLTexture {
        print("Loading texture \(url)")
        let loader = MTKTextureLoader(device: self)
        return try loader.newTexture(
            URL: url,
            options: [
                .SRGB: NSNumber(value: srgb),
            ]
        )
    }
    
    func loadTexture(name: String, extension: String, srgb: Bool = true) throws -> MTLTexture {
        let imageURL = bundle.url(forResource: name, withExtension: `extension`)!
        return try loadTexture(url: imageURL, srgb: srgb)
    }
}



//func makeUIImage(texture: MTLTexture, context: CIContext) -> UIImage {
//    makeUIImage(ciImage: makeCIImage(texture: texture), context: context)
//}


extension CIContext {
    
    func makeUIImage(ciImage: CIImage) -> UIImage {
        return UIImage(cgImage: makeCGImage(ciImage: ciImage))
    }

    func makeCGImage(ciImage: CIImage) -> CGImage {
        return createCGImage(ciImage, from: ciImage.extent)!
    }
}


extension CIImage {
    
    convenience init(name: String, extension: String) throws {
        let imageURL = bundle.url(forResource: name, withExtension: `extension`)!
        self.init(contentsOf: imageURL)!
    }

//    convenience init(texture: MTLTexture, orientation: CGImagePropertyOrientation = .downMirrored) {
//        var ciImage = CIImage(mtlTexture: texture)!
//        ciImage = ciImage.transformed(
//            by: ciImage.orientationTransform(
//                for: orientation
//            )
//        )
//        self = ciImage
//    }
    
    func orientation(_ orientation: CGImagePropertyOrientation) -> CIImage {
        return transformed(
            by: orientationTransform(
                for: orientation
            )
        )
    }

    func sRGBToneCurveToLinear() -> CIImage {
        let filter = CIFilter.sRGBToneCurveToLinear()
        filter.inputImage = self
        return filter.outputImage!
    }
    
    
    func linearToSRGBToneCurve() -> CIImage {
        let filter = CIFilter.linearToSRGBToneCurve()
        filter.inputImage = self
        return filter.outputImage!
    }
    
    func smearColor() -> CIImage {
        let filter = CIFilter.colorMatrix()
        filter.rVector = CIVector(x: 1, y: 0, z: 0)
        filter.gVector = CIVector(x: 1, y: 0, z: 0)
        filter.bVector = CIVector(x: 1, y: 0, z: 0)
        filter.biasVector = CIVector(x: 0, y: 0, z: 0)
        filter.inputImage = self
        return filter.outputImage!.cropped(
            to: self.extent
        )
    }
    
    func normalizeColor() -> CIImage {
        let filter = CIFilter.colorMatrix()
        filter.rVector = CIVector(x: 0.5, y: 0, z: 0)
        filter.gVector = CIVector(x: 0.5, y: 0, z: 0)
        filter.bVector = CIVector(x: 0.5, y: 0, z: 0)
        filter.biasVector = CIVector(x: 0.5, y: 0.5, z: 0.5)
        filter.inputImage = self
        return filter.outputImage!.cropped(
            to: self.extent
        )
    }
    
    func invertColor() -> CIImage {
        self.colorInverted()
    }
    
    
    func mapColor() -> CIImage {
        let imageFileURL = bundle.url(forResource: "viridis", withExtension: "png")!
        let filter = CIFilter.colorMap()
        filter.gradientImage = CIImage(contentsOf: imageFileURL)
        filter.inputImage = self
        return filter.outputImage!
    }
}


class SharedTestCase: XCTestCase {

    var device: MTLDevice!
    var commandQueue: MTLCommandQueue!
    var ciContext: CIContext!
//    var upscaleFunction: NearestNeighborUpScaleKernel!
    var subtractFunction: MPSImageSubtract!
    var convertSRGBToLinearGrayscaleFunction: MPSImageConversion!
//    var convertLinearRGBToLinearGrayscaleFunction: MPSImageConversion!

    override func setUp() {
        device = MTLCreateSystemDefaultDevice()!
        commandQueue = device.makeCommandQueue()!
//        upscaleFunction = NearestNeighborUpScaleKernel(device: device)
        subtractFunction = MPSImageSubtract(device: device)
        convertSRGBToLinearGrayscaleFunction = MPSImageConversion(
            device: device,
            srcAlpha: .alphaIsOne,
            destAlpha: .alphaIsOne,
            backgroundColor: nil,
            conversionInfo: CGColorConversionInfo(
                src: CGColorSpace(name: CGColorSpace.sRGB)!,
                dst: CGColorSpace(name: CGColorSpace.linearGray)!
            )
        )
        ciContext = CIContext(
            mtlDevice: device,
            options: [
                .outputColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
            ]
        )
    }

    override func tearDown() {
        ciContext = nil
//        upscaleFunction = nil
        subtractFunction = nil
        commandQueue = nil
        device = nil
    }

    func attachImage(name: String, uiImage: UIImage) {
        let attachment = XCTAttachment(
            image: uiImage,
            quality: .original
        )
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
