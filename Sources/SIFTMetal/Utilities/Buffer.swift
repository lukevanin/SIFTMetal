//
//  Buffer.swift
//  SkyLight
//
//  Created by Luke Van In on 2023/01/06.
//

import Foundation
import Metal


public final class Buffer<T> {

    public private(set) var count: Int
    let data: MTLBuffer
    let pointer: UnsafeMutablePointer<T>
    public let capacity: Int

    public init(device: MTLDevice, label: String, capacity: Int) {
        self.capacity = capacity
        let numberOfBytes = MemoryLayout<T>.stride * capacity
        self.data = device.makeBuffer(
            length: numberOfBytes,
            options: [.hazardTrackingModeTracked, .storageModeShared]
        )!
        self.data.label = label
        self.pointer = data.contents().bindMemory(to: T.self, capacity: capacity)
        self.count = 0
    }
    
    deinit {
        data.setPurgeableState(.empty)
    }
    
    public func allocate(_ count: Int) {
        precondition(count >= 0)
        precondition(count <= capacity)
        self.count = count
    }
    
    public subscript(i: Int) -> T {
        get {
            precondition(i >= 0)
            precondition(i < count)
            return pointer[i]
        }
        set {
            precondition(i >= 0)
            precondition(i < count)
            pointer[i] = newValue
        }
    }
}
