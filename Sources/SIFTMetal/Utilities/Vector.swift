//
//  Vector.swift
//  SkyLight
//
//  Created by Luke Van In on 2023/01/20.
//

import Foundation


public struct IntVector: Equatable, CustomStringConvertible {
    
    public let count: Int
   
    let components: [Int]
    
    public var description: String {
        let components = components
            .map({ String(format: "%0.3f", $0) })
            .joined(separator: ", ")
        return "<Vector [\(count)] \(components)>"
    }
    
    public init(dimension: Int) {
        self.init(Array(repeating: 0, count: dimension))
    }
    
    public init(_ components: [Int]) {
        self.components = components
        self.count = components.count
    }
    
    public subscript(index: Int) -> Int {
        components[index]
    }
    
    public func distanceSquared(to other: IntVector) -> Float {
        precondition(count == other.count)
        #warning("TODO: Use Accelerate")
        var k: Int = 0
        for i in 0 ..< count {
            let d = other[i] - self[i]
            k += d * d
        }
        return Float(k)
    }
    
    public func distance(to other: IntVector) -> Float {
        #warning("TODO: Use Accelerate")
        return sqrt(Float(distanceSquared(to: other)))
    }
}


struct FloatVector: Equatable, CustomStringConvertible {
    let count: Int
    let components: [Float]
    
    var description: String {
        let components = components
            .map({ String(format: "%0.3f", $0) })
            .joined(separator: ", ")
        return "<Vector [\(count)] \(components)>"
    }
    
    init(_ components: [Float]) {
        self.components = components
        self.count = components.count
    }
    
    subscript(index: Int) -> Float {
        components[index]
    }
    
    func distanceSquared(to other: FloatVector) -> Float {
        precondition(count == other.count)
        #warning("TODO: Use Accelerate")
        var k: Float = 0
        for i in 0 ..< count {
            let d = other[i] - self[i]
            k += d * d
        }
        return k
    }
    
    func distance(to other: FloatVector) -> Float {
        #warning("TODO: Use Accelerate")
        return sqrt(distanceSquared(to: other))
    }
}
