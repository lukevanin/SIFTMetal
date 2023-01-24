//
//  CoreVideoMetalCache.swift
//  SkyLight
//
//  Created by Luke Van In on 2022/12/18.
//

import Foundation
import CoreVideo


final class CoreVideoMetalCache {
    
    private let textureCache: CVMetalTextureCache

    init(device: MTLDevice) {
        var textureCache: CVMetalTextureCache?
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &textureCache)
        self.textureCache = textureCache!
        
    }
    
    func makeTexture(from input: CVImageBuffer, size: IntegralSize) -> MTLTexture {
        var cvMetalTexture: CVMetalTexture?
        let result = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCache, input, nil, .bgra8Unorm, size.width, size.height, 0, &cvMetalTexture)
        guard result == kCVReturnSuccess else {
            fatalError("Cannot create texture")
        }
        let texture = CVMetalTextureGetTexture(cvMetalTexture!)!
        return texture
    }

}
