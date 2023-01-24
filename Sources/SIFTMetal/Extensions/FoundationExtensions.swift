//
//  File.swift
//  
//
//  Created by Luke Van In on 2023/01/24.
//

import Foundation

extension Bundle {
    
    // See: https://developer.apple.com/forums/thread/649579
    static var metalShaders: Bundle {
        let bundleURL = Bundle.main.url(forResource: "SIFTMetal_MetalShaders", withExtension: "bundle")!
        let bundle = Bundle(url: bundleURL)!
        return bundle
    }
}
