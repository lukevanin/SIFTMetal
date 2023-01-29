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

        // let prefix = [keypoint.normalizedCoordinate.x, keypoint.normalizedCoordinate.y]

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
        let minimumSampleSize = 5
        let maximumSampleSize = 20
//        let sampleRatio: Float = 0.05
//        let maximumMatches = min(source.count, target.count)
//        let sampleSize = Int(Float(maximumMatches) * sampleRatio)
//        guard sampleSize >= minimumSampleSize else {
//            print("matchGeometry: rejected: Not enough samples: \(sampleSize) out of \(minimumSampleSize)")
//            return 0
//        }
//        let minimumMatchRatio: Float = 0.1
        guard source.count >= minimumSampleSize else {
            print("matchGeometry: rejected: Not enough source samples: \(source.count) out of \(minimumSampleSize)")
            return 0
        }
        guard target.count >= minimumSampleSize else {
            print("matchGeometry: rejected: Not enough target samples: \(target.count) out of \(minimumSampleSize)")
            return 0
        }
        let matches = match(source: source, target: target, absoluteThreshold: absoluteThreshold, relativeThreshold: relativeThreshold)
        guard matches.count >= minimumSampleSize else {
            print("matchGeometry: rejected: Not enough matches: \(matches.count) out of \(minimumSampleSize)")
            return 0
        }
//        let matchRatio = Float(matches.count) / Float(maximumMatches)
//        guard matchRatio >= minimumMatchRatio else {
//            print("matchGeometry: rejected: Source match ratio too low: \(matchRatio) out of \(minimumMatchRatio )")
//            return 0
//        }
//        let sample = matches.prefix(maximumSampleSize)
        return compareGeometry(
            matches: matches,
            minimumSampleSize: minimumSampleSize,
            maximumSampleSize: maximumSampleSize
        )
    }
    
    private static func makeCoordinate(_ keypoint: SIFTKeypoint) -> SIMD2<Float> {
//        return SIMD2<Float>(
//            keypoint.normalizedCoordinate.x * 3,
//            keypoint.normalizedCoordinate.y * 3,
//            keypoint.sigma
//        )
//        return SIMD2<Float>(
//            keypoint.absoluteCoordinate.x / keypoint.sigma,
//            keypoint.absoluteCoordinate.y / keypoint.sigma
//        )
        return keypoint.absoluteCoordinate
//        return keypoint.normalizedCoordinate
    }
    
    private static func dotProduct(_ a: SIMD2<Float>, _ b: SIMD2<Float>) -> Float {
        return simd_clamp((simd_dot(a, b) * 0.5) + 0.5, 0, 1)
    }
    
    private static func compareGeometry(
        matches: [SIFTCorrespondence],
        minimumSampleSize: Int,
        maximumSampleSize: Int
    ) -> Float {
        
        print("compareGeometry: Samples = \(matches.count)")
        
        let minimumLength: Float = 5

        var sum: Float = 0
        var count: Int = 0
        var scores: [Float] = []
        for i in stride(from: 0, to: matches.count - 2, by: 1) {
            
            guard count < maximumSampleSize else {
                break
            }

            let m0 = matches[i + 0]
            let m1 = matches[i + 1]
            
            let sourceBase = makeCoordinate(m1.source.keypoint) - makeCoordinate(m0.source.keypoint)
            let targetBase = makeCoordinate(m1.target.keypoint) - makeCoordinate(m0.target.keypoint)
            
            let sourceBaseLength = simd_length(sourceBase)
            let targetBaseLength = simd_length(targetBase)
            
            guard sourceBaseLength >= minimumLength else {
                continue
            }
            
            guard targetBaseLength >= minimumLength else {
                continue
            }

            let sourceBaseNormal = simd_normalize(sourceBase)
            let targetBaseNormal = simd_normalize(targetBase)

            let m2 = matches[i + 1]
            let m3 = matches[i + 2]
            let sourceTest = makeCoordinate(m3.source.keypoint) - makeCoordinate(m2.source.keypoint)
            let targetTest = makeCoordinate(m3.target.keypoint) - makeCoordinate(m2.target.keypoint)

            let sourceTestLength = simd_length(sourceTest)
            let targetTestLength = simd_length(targetTest)
            
            guard sourceTestLength >= minimumLength else {
                continue
            }
            
            guard targetTestLength >= minimumLength else {
                continue
            }
            
            let sourceTestNormal = simd_normalize(sourceTest)
            let targetTestNormal = simd_normalize(targetTest)

            let sourceRatio = sourceTestLength / sourceBaseLength
            let targetRatio = targetTestLength / targetBaseLength

            let sourceDotProduct = dotProduct(sourceTestNormal, sourceBaseNormal)
            let targetDotProduct = dotProduct(targetTestNormal, targetBaseNormal)
            
            precondition(sourceDotProduct >= 0)
            precondition(sourceDotProduct <= 1)
            precondition(targetDotProduct >= 0)
            precondition(targetDotProduct <= 1)

            let orientationSimilarity = 1.0 - abs(sourceDotProduct - targetDotProduct)
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

            let similarity = orientationSimilarity * scaleSimilarity
            let score = similarity * similarity
            scores.append(score)
            sum += score
            count += 1
        }
        
        guard count >= minimumSampleSize else {
            return 0
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
        
        var fairMeanSum: Float = 0
        var fairMeanCount: Float = 0
        for i in 0 ..< scores.count {
            let zscore = zscores[i]
            if zscore <= 2 {
                let score = scores[i]
                fairMeanSum += score
                fairMeanCount += 1
            }
        }
        let fairMean = fairMeanSum / fairMeanCount
        
        print(
            "compareGeometry",
            "count", count,
            "mean", mean,
            "fairMean", fairMean,
            "variance", variance,
            "standard deviation", standardDeviation,
            "scores", scores,
            "zscores", zscores
        )
        
        return fairMean
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
