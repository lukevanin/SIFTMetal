//
//  TrieTests.swift
//  SkyLightTests
//
//  Created by Luke Van In on 2023/01/20.
//

import XCTest

@testable import SIFTMetal

/*
final class TrieTests: XCTestCase {
    
    func testInsert_shouldMatchStructure() {
        let expected = Trie<FloatVector>(
            Trie(
                nil,
                Trie(
                    nil,
                    nil,
                    Trie(
                        nil,
                        nil,
                        nil
                    )
                ),
                nil
            ),
            nil,
            nil
        )
        let trie = Trie<FloatVector>(numberOfBins: 3)
        trie.insert(key: FloatVector([0.0, 0.5, 1.0]), value: FloatVector([0.0, 0.5, 1.0]))
        XCTAssertEqual(trie, expected)
    }
    
    func testContains_shouldReturnFalse_whenTrieDoesNotContainExactMatch() {
        let trie = Trie<FloatVector>(numberOfBins: 3)
        trie.insert(key: FloatVector([1.0, 1.0, 1.0]), value: FloatVector([1.0, 1.0, 1.0]))
        let result = trie.contains(FloatVector([0.0, 0.0, 0.0]))
        XCTAssertFalse(result)
    }

    func testContains_shouldReturnTrue_whenTrieContainsExactMatch() {
        let trie = Trie<FloatVector>(numberOfBins: 3)
        trie.insert(key: FloatVector([0.1, 0.2, 0.3]), value: FloatVector([0.1, 0.2, 0.3]))
        let result = trie.contains(FloatVector([0.1, 0.2, 0.3]))
        XCTAssertTrue(result)
    }

    func testContains_shouldReturnTrue_whenTrieContainsPartialMatch() {
        let trie = Trie<FloatVector>(numberOfBins: 3)
        trie.insert(key: FloatVector([0.1, 0.2, 0.3]), value: FloatVector([0.1, 0.2, 0.3]))
        let result = trie.contains(FloatVector([0.1, 0.2]))
        XCTAssertTrue(result)
    }
    
    func testContains_shouldReturnTrue_whenTrieContainsSimilarValues() {
        let trie = Trie<FloatVector>(numberOfBins: 3)
        trie.insert(key: FloatVector([0, 0.5, 1.0]), value: FloatVector([0, 0.5, 1.0])) // bins: 0, 1, 2
        XCTAssertTrue(trie.contains(FloatVector([0.1, 0.5, 1.0])))
        XCTAssertTrue(trie.contains(FloatVector([0.1, 0.6, 1.0])))
        XCTAssertTrue(trie.contains(FloatVector([0.1, 0.6, 0.9])))
    }
    
    func testNearest_shouldReturnNearestValue_whenTrieContainsSimilarValues() {
        let trie = Trie<FloatVector>(numberOfBins: 3)
        trie.insert(key: FloatVector([0, 0.5, 1.0]), value: FloatVector([0, 0.5, 1.0]))
        let results = trie.nearest(key: FloatVector([0.1, 0.6, 0.9]), query: FloatVector([0.1, 0.6, 0.9]), radius: 0, k: 1)
        let expected = FloatVector([0, 0.5, 1.0])
        XCTAssertEqual(results[0].value, expected)
    }

    func testNearestAccuracy() {
        
        struct Neighbor: CustomStringConvertible {
            let id: Int
            let distance: Float
            
            var description: String {
                "<Neighbor #\(id) @\(String(format: "%0.3f", distance))>"
            }
        }
        
        // capacity = 3^d * n
        let n = 1000
        let m = 100
        let d = 128
        var values: [FloatVector] = []
        var queries: [FloatVector] = []
        var nearestNeighbors: [Neighbor] = []
        
        // Generate sample data
        print("generate sample data x", n)
        for _ in 0 ..< n {
            var vector: [Float] = Array(repeating: 0, count: d)
            for j in 0 ..< d {
                vector[j] = .random(in: 0...1)
            }
            let value = FloatVector(vector)
            values.append(value)
        }
        
        // Generate queries.
        print("generate queries x", m)
        for _ in 0 ..< m {
            var vector: [Float] = Array(repeating: 0, count: d)
            for j in 0 ..< d {
                vector[j] = .random(in: 0...1)
            }
            queries.append(FloatVector(vector))
        }

        // Compute actual nearest neighbor for each node using brute force.
        print("compute nearest neighbor ground truth")
        for i in 0 ..< m {
            let query = queries[i]
            var nearestDistance: Float = .greatestFiniteMagnitude
            var nearestNeighbor: Neighbor!
            for j in 0 ..< n {
                let value = values[j]
                let distance = value.distance(to: query)
                guard distance < nearestDistance else {
                    continue
                }
                nearestDistance = distance
                nearestNeighbor = Neighbor(id: j, distance: distance)
            }
            nearestNeighbors.append(nearestNeighbor)
        }
        
        // Create the trie.
        print("create trie")
        let subject = Trie<FloatVector>(numberOfBins: 4)
        for i in 0 ..< n {
            let value = values[i]
            subject.insert(key: value, value: value)
        }
        print("capacity", subject.capacity())

        print("linking trie")
        subject.link()

        // Sanity check
        print("check contains")
        for i in 0 ..< n {
            let query = values[i]
            let result = subject.contains(query)
            XCTAssertTrue(result)
        }

        // Sanity check: nearest() with existing key/value should always return exact match
        print("check exact nearest")
        for i in 0 ..< n {
            let query = values[i]
            let matches = subject.nearest(key: query, query: query, radius: 0, k: 1)
            XCTAssertEqual(matches[0].value, query)
        }
        
        // Compute approximate nearest neighbor.
        var totalError: Float = 0
        var totalDistance: Float = 0
        var totalCorrect: Int = 0
        var totalQueries: Int = 0
        var totalNodes: Int = 0
        var totalFound: Int = 0
//        measure {
            for i in 0 ..< m {
                totalQueries += 1
                let query = queries[i]
                let foundNeighbors = subject.nearest(key: query, query: query, radius: 10, k: 1)
                guard let foundNeighbor = foundNeighbors.first else {
                    continue
                }
                totalFound += 1
                totalNodes += subject.comparisonCountMetric
                let foundDistance = foundNeighbor.distance
                totalDistance = foundDistance
                let exactNeighbor = nearestNeighbors[i]
                let exactDistance = exactNeighbor.distance
                let delta = exactDistance - foundDistance
                let error = delta * delta
                totalError += error
                let correct = error == 0
                totalCorrect += correct ? 1 : 0
            }
//        }
        let percentCorrect = Float(totalCorrect) / Float(totalQueries)
        let meanSquaredError = totalError / Float(totalFound)
        let averageNodesPerQuery = Float(totalNodes) / Float(totalFound)
        let averageDistance = Float(totalDistance) / Float(totalFound)
        print("Total queries: \(totalQueries)")
        print("Total found: \(totalFound)")
        print("Mean squared error: \(String(format: "%0.3f", meanSquaredError))")
        print("Average absolute distance: \(String(format: "%0.3f", averageDistance))")
        print("Correct: \(totalCorrect) out of \(totalQueries) = \(String(format: "%0.3f", percentCorrect))")
        print("Total nodes: \(totalNodes)")
        print("Average comparisons per query: \(String(format: "%0.3f", averageNodesPerQuery))")
    }
}
*/
