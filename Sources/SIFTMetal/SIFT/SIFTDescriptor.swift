//
//  SIFTDescriptor.swift
//  SkyLight
//
//  Created by Luke Van In on 2023/01/02.
//

import Foundation
import simd


public struct SIFTDescriptor {
 
    // Detected keypoint.
    public let keypoint: SIFTKeypoint
    // Principal orientation.
    public let theta: Float
    // Quantized features
    public let features: IntVector
    
    public let rawFeatures: FloatVector
    
    private let indexKey: FloatVector
    private let indexValue: FloatVector
    
    public init(
        keypoint: SIFTKeypoint,
        theta: Float,
        features: IntVector
    ) {
        precondition(features.count > 0)
        self.keypoint = keypoint
        self.theta = theta
        self.features = features
        
        let rawFeatures = {
            let components = features.components.map { Float($0) / Float(255) }
            return FloatVector(components)
        }()
        self.rawFeatures = rawFeatures

        let indexFeatures = {
            let count = 8
            let features = stride(from: 0, to: rawFeatures.count, by: count)
                .map { start in
                    let end = min(start + count, rawFeatures.count)
                    let patch = rawFeatures.components[start ..< end]
                    return FloatVector(Array(patch))
                }
            let newOrder = [
                // Center
                features[5],
                features[6],
                features[9],
                features[10],
                
                // Corners
                features[0],
                features[3],
                features[12],
                features[15],
                
                // Edges
                features[1],
                features[2],
                features[4],
                features[7],
                features[8],
                features[11],
                features[13],
                features[14],
            ]
            precondition(newOrder.count == 16)

            return newOrder
        }()

        let prefix = [keypoint.normalizedCoordinates.x, keypoint.normalizedCoordinates.y]

        self.indexValue = {
            let components = Array(indexFeatures.map { $0.components }.joined())
            return FloatVector(components)
        }()

        self.indexKey = {
            let v = indexFeatures.map { $0.mean() }
            precondition(v.count == 16)
            return FloatVector(v)
        }()
    }
    
    private static func distance(_ a: SIFTDescriptor, _ b: SIFTDescriptor) -> Float {
        precondition(a.indexValue.count == 128)
        precondition(b.indexValue.count == 128)
        return a.indexValue.distance(to: b.indexValue)
//        var t = 0
//        for i in 0 ..< 128 {
//            let d = b.features[i] - a.features[i]
//            t += (d * d)
//        }
//        return sqrt(Float(t))
    }
    
    public static func matchGeometry(
        source: [SIFTDescriptor],
        target: [SIFTDescriptor],
        absoluteThreshold: Float = 1.176,
        relativeThreshold: Float = 0.6
    ) -> Float {
        let sampleSize = 10
        let matchRatio: Float = 0.05
        guard source.count >= sampleSize else {
            print("matchGeometry: rejected: Not enough source samples: \(source.count) out of \(sampleSize)")
            return 0
        }
        guard target.count >= sampleSize else {
            print("matchGeometry: rejected: Not enough target samples: \(target.count) out of \(sampleSize)")
            return 0
        }
        let matches = match(source: source, target: target, absoluteThreshold: absoluteThreshold, relativeThreshold: relativeThreshold)
        let sourceMatchRatio = Float(matches.count) / Float(source.count)
        let targetMatchRatio = Float(matches.count) / Float(target.count)
        guard matches.count >= sampleSize else {
            print("matchGeometry: rejected: Not enough matches: \(matches.count) out of \(sampleSize)")
            return 0
        }
        guard sourceMatchRatio >= matchRatio else {
            print("matchGeometry: rejected: Source match ratio too low: \(sourceMatchRatio) out of \(matchRatio)")
            return 0
        }
        guard targetMatchRatio >= matchRatio else {
            print("matchGeometry: rejected: Target match ratio too low: \(targetMatchRatio) out of \(matchRatio)")
            return 0
        }
        let sample = matches.shuffled().prefix(sampleSize)
        return compareGeometry(matches: Array(sample))
    }
    
    private static func compareGeometry(
        matches: [SIFTCorrespondence]
    ) -> Float {
        
        print("compareGeometry: Matches \(matches.count)")

        var sum: Float = 0
        var count: Int = 0
        var scores: [Float] = []
        for i in stride(from: 0, to: matches.count - 4, by: 2) {

            let m0 = matches[i + 0]
            let m1 = matches[i + 1]
            
            let sourceBase = m1.source.keypoint.absoluteCoordinate - m0.source.keypoint.absoluteCoordinate
            let targetBase = m1.target.keypoint.absoluteCoordinate - m0.target.keypoint.absoluteCoordinate
            
            let sourceBaseLength = simd_length(sourceBase)
            let targetBaseLength = simd_length(targetBase)

            let sourceBaseNormal = simd_normalize(sourceBase)
            let targetBaseNormal = simd_normalize(targetBase)
            
            guard sourceBaseLength > 0.001 else {
                continue
            }
            
            guard targetBaseLength > 0.001 else {
                continue
            }

            let m2 = matches[i + 2]
            let m3 = matches[i + 3]
            let sourceTest = m3.source.keypoint.absoluteCoordinate - m2.source.keypoint.absoluteCoordinate
            let targetTest = m3.target.keypoint.absoluteCoordinate - m2.target.keypoint.absoluteCoordinate

            let sourceTestLength = simd_length(sourceTest)
            let targetTestLength = simd_length(targetTest)
            
            let sourceTestNormal = simd_normalize(sourceTest)
            let targetTestNormal = simd_normalize(targetTest)
            
            guard sourceTestLength > 0.001 else {
                continue
            }
            
            guard targetTestLength > 0.001 else {
                continue
            }

            let sourceRatio = sourceTestLength / sourceBaseLength
            let targetRatio = targetTestLength / targetBaseLength

            let sourceDotProduct = simd_clamp((simd_dot(sourceTestNormal, sourceBaseNormal) * 0.5) + 0.5, 0, 1)
            let targetDotProduct = simd_clamp((simd_dot(targetTestNormal, targetBaseNormal) * 0.5) + 0.5, 0, 1)
            
            precondition(sourceDotProduct >= 0)
            precondition(sourceDotProduct <= 1)
            precondition(targetDotProduct >= 0)
            precondition(targetDotProduct <= 1)

            let orientationSimilarity = sourceDotProduct * targetDotProduct
            precondition(orientationSimilarity >= 0)
            precondition(orientationSimilarity <= 1)

            let scaleSimilarity: Float
            if sourceRatio < targetRatio {
                scaleSimilarity = simd_clamp(sourceRatio / targetRatio, 0, 1)
            }
            else {
                scaleSimilarity = simd_clamp(targetRatio / sourceRatio, 0, 1)
            }
            precondition(scaleSimilarity >= 0)
            precondition(scaleSimilarity <= 1)

//            let score = orientationSimilarity * scaleSimilarity
//            let similarity = score * score
            let score = orientationSimilarity
            scores.append(score)
            sum += score
            count += 1
        }
        
        let mean = sum / Float(count)
        
        var error: Float = 0
        for score in scores {
            let delta = score - mean
            error += (delta * delta)
        }
        let variance = error / Float(count - 1)
        let standardDeviation = sqrt(variance)
        
        var zscores: [Float] = []
        for score in scores {
            let zscore = abs((score - mean) / standardDeviation)
            zscores.append(zscore)
        }
        
        print("compareGeometry", "count", count, "mean", mean, "variance", variance, "standard deviation", standardDeviation, "scores", scores, "zscores", zscores)
        
        return mean
    }
    
    public static func match(
        source: [SIFTDescriptor],
        target: [SIFTDescriptor],
        absoluteThreshold: Float = 1.176,
        relativeThreshold: Float = 0.6
    ) -> [SIFTCorrespondence] {
        var output = [SIFTCorrespondence]()
                
        for descriptor in source {
            let correspondence = match(
                descriptor: descriptor,
                target: target,
                absoluteThreshold: absoluteThreshold,
                relativeThreshold: relativeThreshold
            )
            if let correspondence {
                output.append(correspondence)
            }
        }
        return output
    }
    
    public static func match(
        descriptor: SIFTDescriptor,
        target: [SIFTDescriptor],
        absoluteThreshold: Float = 300,
        relativeThreshold: Float = 0.6
    ) -> SIFTCorrespondence? {
        
        var bestMatch: SIFTDescriptor?
        var bestMatchDistance: Float = .greatestFiniteMagnitude
        var secondBestMatchDistance: Float?

        for t in target {
            let distance = descriptor.indexValue.distance(to: t.indexValue)
            if distance < bestMatchDistance {
                bestMatch = t
                secondBestMatchDistance = bestMatchDistance
                bestMatchDistance = distance
            }
        }
        
        guard let bestMatch else {
            return nil
        }
        
        guard let secondBestMatchDistance else {
            return nil
        }
        
        guard bestMatchDistance < absoluteThreshold else {
            return nil
        }
        
        guard bestMatchDistance < (secondBestMatchDistance * relativeThreshold) else {
            return nil
        }
        
        return SIFTCorrespondence(
            source: descriptor,
            target: bestMatch,
            featureDistance: bestMatchDistance
        )
    }
    public static func approximateMatch(
        source: [SIFTDescriptor],
        target: [SIFTDescriptor],
        absoluteThreshold: Float = 300,
        relativeThreshold: Float = 0.6
    ) -> [SIFTCorrespondence] {
        var output = [SIFTCorrespondence]()
        
        let trie = Trie(numberOfBins: 8)
        for descriptor in target {
            trie.insert(key: descriptor.indexKey, value: descriptor)
        }
        trie.link()
        
        for descriptor in source {
            let correspondence = approximateMatch(
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
    
    public static func approximateMatch(
        descriptor: SIFTDescriptor,
        target: Trie,
        absoluteThreshold: Float = 300,
        relativeThreshold: Float = 0.6
    ) -> SIFTCorrespondence? {
        let matches = target.nearest(key: descriptor.indexKey, query: descriptor, radius: 10, k: 2)
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

extension SIFTDescriptor {
    
    func distance(to other: SIFTDescriptor) -> Float {
        features.distance(to: other.features)
    }
    
    func distanceSquared(to other: SIFTDescriptor) -> Float {
        Float(features.distanceSquared(to: other.features))
    }
}
