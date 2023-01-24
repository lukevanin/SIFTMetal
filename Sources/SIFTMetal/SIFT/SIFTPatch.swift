//
//  SIFTHistograms.swift
//  SkyLight
//
//  Created by Luke Van In on 2023/01/02.
//

import Foundation


final class SIFTPatch {
    
    private let buffer: UnsafeMutableBufferPointer<Float>
    private let side: Int
    private let bins: Int
    
    init(side: Int, bins: Int) {
        self.side = side
        self.bins = bins
        self.buffer = UnsafeMutableBufferPointer.allocate(
            capacity: side * side * bins
        )
    }
    
    deinit {
        buffer.deallocate()
    }
    
    func addValue(x: Float, y: Float, bin: Float, value: Float) {
        let ca = SIMD2<Int>(x: Int(floor(x)), y: Int(floor(y)))
        let cb = SIMD2<Int>(x: Int(ceil(x)), y: Int(floor(y)))
        let cc = SIMD2<Int>(x: Int(ceil(x)), y: Int(ceil(y)))
        let cd = SIMD2<Int>(x: Int(floor(x)), y: Int(ceil(y)))
        
        let ba = Int(floor(bin))
        let bb = Int(ceil(bin))
        
        let iMax = x - floor(x)
        let iMin = 1 - iMax
        let jMax = y - floor(y)
        let jMin = 1 - jMax
        let bMax = bin - floor(bin)
        let bMin = 1 - bMax
        
        addValue(x: ca.x, y: ca.y, bin: ba, value: (iMin * jMin * bMin) * value)
        addValue(x: ca.x, y: ca.y, bin: bb, value: (iMin * jMin * bMax) * value)
        
        addValue(x: cb.x, y: cb.y, bin: ba, value: (iMax * jMin * bMin) * value)
        addValue(x: cb.x, y: cb.y, bin: bb, value: (iMax * jMin * bMax) * value)
        
        addValue(x: cc.x, y: cc.y, bin: ba, value: (iMax * jMax * bMin) * value)
        addValue(x: cc.x, y: cc.y, bin: bb, value: (iMax * jMax * bMax) * value)
        
        addValue(x: cd.x, y: cd.y, bin: ba, value: (iMin * jMax * bMin) * value)
        addValue(x: cd.x, y: cd.y, bin: bb, value: (iMin * jMax * bMax) * value)
    }
    
    func addValue(x: Int, y: Int, bin: Int, value: Float) {
        guard x >= 0 && x < side && y >= 0 && y < side else {
            return
        }
        var bin = bin
        while bin < 0 {
            bin += bins
        }
        while bin >= bins {
            bin -= bins
        }
        buffer[offset(x: x, y: y, bin: bin)] += value
    }
    
    private func offset(x: Int, y: Int, bin: Int) -> Int {
        (y * side * bins) + (x * bins) + bin
    }
    
    func features() -> [Float] {
        return Array(buffer)
    }
}
