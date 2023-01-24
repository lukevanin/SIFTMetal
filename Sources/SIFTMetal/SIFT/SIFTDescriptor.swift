//
//  SIFTDescriptor.swift
//  SkyLight
//
//  Created by Luke Van In on 2023/01/02.
//

import Foundation


public struct SIFTDescriptor {
 
    // Detected keypoint.
    public let keypoint: SIFTKeypoint
    // Principal orientation.
    public let theta: Float
    // Quantized features
    public let features: IntVector
    
    public init(
        keypoint: SIFTKeypoint,
        theta: Float,
        features: IntVector
    ) {
        self.keypoint = keypoint
        self.theta = theta
        self.features = features
    }

    func rawFeatures() -> FloatVector {
        let components = features.components.map { Float($0) / Float(255) }
        return FloatVector(components)
    }
    
    func makeIndexKey() -> FloatVector {
        let count = 8
        let features = rawFeatures()
        let v = stride(from: 0, to: features.count, by: count)
            .map { start in
                let end = min(start + count, features.count)
                let patch = features.components[start ..< end]
                let sum = patch.reduce(0) {
                    $0 + $1
                }
                let average = sum / Float(patch.count)
                return average
            }
        precondition(v.count == 16)
        return FloatVector(v)
    }
    
    public static func distance(_ a: SIFTDescriptor, _ b: SIFTDescriptor) -> Float {
        precondition(a.features.count == 128)
        precondition(b.features.count == 128)
        var t = 0
        for i in 0 ..< 128 {
            let d = b.features[i] - a.features[i]
            t += (d * d)
        }
        return sqrt(Float(t))
    }

    public static func match(
        source: [SIFTDescriptor],
        target: [SIFTDescriptor],
        absoluteThreshold: Float,
        relativeThreshold: Float
    ) -> [SIFTCorrespondence] {
        var output = [SIFTCorrespondence]()
        
        let trie = Trie<SIFTDescriptor>(numberOfBins: 8)
        for descriptor in target {
            let key = descriptor.makeIndexKey()
            trie.insert(key: key, value: descriptor)
        }
        trie.link()
        
        for descriptor in source {
            let correspondence = match(
                descriptor: descriptor,
                target: trie,
                absoluteThreshold: absoluteThreshold,
                relativeThreshold: relativeThreshold
            )
            if let correspondence {
                output.append(correspondence)
            }
        }
        return output
    }
    
    static func match(
        descriptor: SIFTDescriptor,
        target: Trie<SIFTDescriptor>,
        absoluteThreshold: Float,
        relativeThreshold: Float
    ) -> SIFTCorrespondence? {
        let key = descriptor.makeIndexKey()
        let matches = target.nearest(key: key, query: descriptor, radius: 10, k: 2)
        guard matches.count == 2 else {
            return nil
        }
        
        let bestMatch = matches[0]
        let secondBestMatch = matches[1]
        
        guard bestMatch.distance < absoluteThreshold else {
            return nil
        }
        
        guard bestMatch.distance < (secondBestMatch.distance * relativeThreshold) else {
            return nil
        }
        
        return SIFTCorrespondence(
            source: descriptor,
            target: bestMatch.value,
            featureDistance: bestMatch.distance
        )
    }
}

extension SIFTDescriptor: IDistanceComparable {
    
    func distance(to other: SIFTDescriptor) -> Float {
        features.distance(to: other.features)
    }
    
    func distanceSquared(to other: SIFTDescriptor) -> Float {
        Float(features.distanceSquared(to: other.features))
    }
}
