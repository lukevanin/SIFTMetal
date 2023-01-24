//
//  Trie.swift
//  SkyLight
//
//  Created by Luke Van In on 2023/01/20.
//

import Foundation


///
/// Approximate Nearest Neighbor (ANN) Trie.
///
/// A data structure used for finding k approximate nearest neighbors on vectors with a high number of
/// dimension (e.g. 128 ).
///
/// Given a set of n nodes with a key size of m:
/// - Initial construction is polynomial O(nm) time.
/// - Search runs in linear O(m) time.
/// - The trie can updated incrementally in linear O(m) time after creation.
/// - The key m used to insert values is independent of the value storied in leaf nodes. This allows for
/// efficient hashing methods to be used to dirive keys that can locate query results more accurately.
/// - Search complexity remains linear in m for any number of dimensions, that is, it does not fail due to
/// the "curse of dimensionality" which causes other algorithms to become ineffective when using a high
/// number of dimensions as a result of quadratic or exponential time complexity.
///
/// How it works:
///
/// We use a trie structure, also referred to as a prefix tree. A trie is a type of recursive sparse tree structure,
/// where nodes typically contain a number of child trie nodes. A trie is similar to a binary tree in that it is
/// constructed from similar nodes, which contain child nodes of the same kind. It is different to a tree in that
/// the trie nodes contain many child nodes, ranging from several to many thousands of children, depending
/// on the use case. Tries are commonly used for storing data when a subset of data needs to be fetched, e.g.
/// find all of the words in a dictionary beginning with the letters "car". We do not use the trie in the typical
/// fashion.
///
/// Each node in the trie contains several child nodes. The number of child nodes is determined when the
/// trie is constructed, and selected accordinf to the charactaristics of the data set.
///
/// We start by constructing the trie by inserting values associated with vector keys. Like a normal trie, nodes
/// are sparse, meaning that not all of the child nodes are necessarily filled and some child nodes may be
/// empty. Unlike a normal trie, the trie height is usually constant, and determined by the length of the key
/// vector.
///
/// Also unlike normal tries, leaf nodes can store any number of values, and values are independent
/// of keys. This allows keys to be tailored to the data, such as using dimensionality reduction methods to
/// create smaller keys, or by hashing keys so that leaf nodes can be locate d more efficiently.
///
/// Values are inserted into leaf nodes. To locate the leaf node, the first component of the key vector is used
/// to locate a bin in the top level of the trie. The component is allocated to one the child nodes depending on
/// its value.  If there is no existing child node for the bin corresponding to the component value, then a child
/// node is created and assigned. After the child node is allocated, the next component of the key vector is
/// used to locate a bin in the child node. This process continues for each key component. The final
/// descendant node is used as the leaf node. The value is inserted into the list of values for the leaf node.
///
/// After values are inserted, the leaf nodes are linked together to form a bi-directional linked list. In the
/// current implementation the link step needs to be performed whenever new values are inserted into the trie.
/// In future it may be possible to link leaf nodes immediatley when values are inserted, or lazily at query time.
///
/// After the trie is popuated and linked, we can perform search queries. The search starts using the first
/// component of the key vector to locate the bin corresponding to the component value. If the bin is empty
/// then the next nearest bin is used. After the first bin is located, the second component is used to locate the
/// corresponding bin in the top bin. This procedure is repeated for each component in the key. The resulting
/// node is used as the initial leaf node.
///
/// When the leaf node is located, the values of the leaf node are compared against the key.  If the distance to
/// any value in the leaf node is smaller than the currently known smallest distance, then the value is added
/// to a queue of fixed size.
///
/// After the initial nearest neighbor is located, nearby leaf nodes in the linked list are compared in the same
/// manner, up to a fixed number of neighboring leaf nodes.
///
/// The queue containing the values with the smallest distance to the key is then returned as the result of the
/// search.
///
final class Trie {
    
    typealias Value = SIFTDescriptor
    
    private(set) var nodeCountMetric = 0
    private(set) var comparisonCountMetric = 0
    
    // Number of bins
    let numberOfBins: Int
    
    // Nodes
    private var hasNodes = false
    private var nodes: [Trie?]
    
    // Values
    private var values: [Value] = []
    
    private var rightNode: Trie!
    private var leftNode: Trie!
    
    convenience init(numberOfBins: Int) {
        self.init(nodes: Array<Trie?>(repeating: nil, count: numberOfBins))
    }
    
    convenience init(_ nodes: Trie?...) {
        self.init(nodes: nodes)
    }
    
    init(nodes: [Trie?]) {
        self.numberOfBins = nodes.count
        self.nodes = nodes
    }
    
    func capacity() -> Int {
        var total = values.count
        for node in nodes {
            if let node {
                total += node.capacity()
            }
        }
        return total
    }
    
    func link() {
        let nodes = self.leaves()
        for i in 0 ..< nodes.count {
            let thisNode = nodes[i]
            let nextNode = nodes[(i + 1) % nodes.count]
            thisNode.rightNode = nextNode
            nextNode.leftNode = thisNode
        }
        check()
    }
    
    private func check() {
        if !hasNodes {
            precondition(leftNode != nil)
            precondition(rightNode != nil)
        }
        else {
            for node in nodes {
                node?.check()
            }
        }
    }
    
    private func leaves() -> [Trie] {
        var leaves: [Trie] = []
        if hasNodes {
            // Branch node
            for node in nodes {
                if let node = node {
                    let childLeaves = node.leaves()
                    leaves.append(contentsOf: childLeaves)
                }
            }
        }
        else {
            // Leaf node
            leaves.append(self)
        }
        return leaves
    }

    func insert(key: FloatVector, value: Value) {
        insert(key: ArraySlice(key.components), value: value)
    }
    
    private func insert(key: ArraySlice<Float>, value: Value) {
        #warning("TODO: use loop instead of recursion")
        guard key.count > 0 else {
            values.append(value)
            return
        }
        let prefix = key[key.startIndex]
        let binIndex = binIndex(for: prefix)
        var node: Trie! = nodes[binIndex]
        if node == nil {
            node = Trie(numberOfBins: numberOfBins)
            nodes[binIndex] = node
            hasNodes = true
        }
        let suffix = key.suffix(from: key.startIndex + 1)
        node.insert(key: suffix, value: value)

        // Uncomment to insert value into neighbor nodes
        //        let binIndex = binIndex(for: prefix)
        //        let leftBinIndex = self.binIndex(before: binIndex)
        //        let rightBinIndex = self.binIndex(after: binIndex)
        //        let indices = [leftBinIndex, binIndex, rightBinIndex]

        //        for index in indices {
        //            var node: Trie! = nodes[index]
        //            if node == nil {
        //                node = Trie(numberOfBins: numberOfBins)
        //                nodes[index] = node
        //            }
        //            let suffix = key.suffix(from: key.startIndex + 1)
        //            node.insert(key: suffix, value: value)
        //        }
    }
    
    func contains(_ key: FloatVector) -> Bool {
        return contains(ArraySlice(key.components))
    }

    private func contains(_ key: ArraySlice<Float>) -> Bool {
        guard key.count > 0 else {
            return true
        }
        let prefix = key[key.startIndex]
        let binIndex = binIndex(for: prefix)
        guard let node = nodes[binIndex] else {
            return false
        }
        guard key.count > 1 else {
            return true
        }
        let suffix = key.suffix(from: key.startIndex + 1)
        return node.contains(suffix)
    }
    
    struct Match {
        var value: Value
        var distance: Float
    }
    
    class FiniteQueue<T> {
        
        var first: T? {
            values.first
        }
        
        var count: Int {
            values.count
        }
        
        let capacity: Int
        
        private var values: [T] = []
        
        init(capacity: Int) {
            self.capacity = capacity
        }
        
        subscript(index: Int) -> T {
            values[index]
        }
        
        func insert(_ value: T) {
            values.insert(value, at: 0)
            if values.count > capacity {
                values.removeLast()
            }
        }
    }

//    func nearest(_ query: FloatVector, distance: Float, radius: Int, k: Int) -> Match? {
//        nodeCountMetric = 0
//        comparisonCountMetric = 0
//        
//        let matches = FiniteQueue(capacity: k)
//        guard let bin = nearestNode(query.components) else {
//            return nil
//        }
//        
//        comparisonCountMetric += bin.values.count
//        guard var bestMatch = bin.nearestValue(query, matches: matches) else {
//            return nil
//        }
//        if bestMatch.distance <= distance {
//            // Best match is already within the required threshold
//            return bestMatch
//        }
//        
//        var leftNode = bin
//        var rightNode = bin
//        for _ in 0 ..< radius {
//            leftNode = leftNode.leftNode!
//            rightNode = rightNode.rightNode!
//            
//            comparisonCountMetric += leftNode.values.count
//            if let match = leftNode.nearestValue(query) {
//                if match.distance <= distance {
//                    return match
//                }
//            }
//            
//            comparisonCountMetric += rightNode.values.count
//            if let match = rightNode.nearestValue(query) {
//                if match.distance <= distance {
//                    return match
//                }
//            }
//        }
//        
//        return nil
//    }
    
    func nearest(key: FloatVector, query: Value, radius: Int, k: Int) -> FiniteQueue<Match> {
        nodeCountMetric = 0
        comparisonCountMetric = 0
       
        let matches = FiniteQueue<Match>(capacity: k)
        let bin = nearestNode(key.components)
        
        comparisonCountMetric += bin.values.count
        bin.nearestValue(query, matches: matches)
        
        var node = bin
        for _ in 0 ..< radius {
            node = node.leftNode!
            comparisonCountMetric += node.values.count
            node.nearestValue(query, matches: matches)
        }

        node = bin
        for _ in 0 ..< radius {
            node = node.rightNode!
            comparisonCountMetric += node.values.count
            node.nearestValue(query, matches: matches)
        }

        return matches
    }
    
    private func nearestNode(_ key: [Float]) -> Trie {
        var current = self
        for i in 0 ..< key.count {
            nodeCountMetric += 1
            guard current.hasNodes else {
                return current
            }
            let value = key[i]
            let binIndex = current.binIndex(for: value)
            guard let node = current.closestNode(to: binIndex) else {
                return current
            }
            current = node
        }
        return current
    }
    
    private func closestNode(to binIndex: Int) -> Trie? {
        if let node = nodes[binIndex] {
            return node
        }
        var bestDistance: Int = .max
        var bestNode: Trie?
        for j in 0 ..< numberOfBins {
            guard let node = nodes[j] else {
                continue
            }
            let distance = binDifference(binIndex, j)
            if distance < bestDistance {
                bestDistance = distance
                bestNode = node
            }
        }
        return bestNode
    }
    
    private func nearestValue(_ query: Value, matches: FiniteQueue<Match>) {
        let bestMatch = matches.first
        var bestDistance: Float = bestMatch?.distance ?? .greatestFiniteMagnitude
        for value in values {
            let distance = query.distance(to: value)
            if distance < bestDistance {
                bestDistance = distance
                let match = Match(
                    value: value,
                    distance: distance
                )
                matches.insert(match)
            }
        }
    }

    private func binDifference(_ a: Int, _ b: Int) -> Int {
        precondition(a >= 0)
        precondition(a < numberOfBins)
        precondition(b >= 0)
        precondition(b < numberOfBins)
        return wrapBinIndex(abs(b - a))
    }
    
    private func binIndex(for value: Float) -> Int {
        precondition(value >= 0)
        precondition(value <= 1)
        let index = Int((value * Float(numberOfBins - 1)).rounded())
        precondition(index >= 0)
        precondition(index < numberOfBins)
        return index
    }
    
    private func binIndex(before index: Int) -> Int {
        precondition(index >= 0)
        precondition(index < numberOfBins)
        return wrapBinIndex(index - 1)
    }
    
    private func binIndex(after index: Int) -> Int {
        precondition(index >= 0)
        precondition(index < numberOfBins)
        return wrapBinIndex(index + 1)
    }
    
    private func wrapBinIndex(_ input: Int) -> Int {
        var output = input
        let n = numberOfBins - 1
        if output < 0 {
            output += n
        }
        else if output >= n {
            output -= n
        }
        precondition(output >= 0)
        precondition(output < numberOfBins)
        return output
    }
}

extension Trie: Equatable {
    
    static func ==(lhs: Trie, rhs: Trie) -> Bool {
        lhs.numberOfBins == rhs.numberOfBins &&
        lhs.nodes == rhs.nodes
    }
}
