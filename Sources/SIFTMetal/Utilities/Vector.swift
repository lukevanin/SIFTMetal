//
//  Vector.swift
//  SkyLight
//
//  Created by Luke Van In on 2023/01/20.
//

import Foundation
import Accelerate


public struct IntVector: Equatable, CustomStringConvertible {
    
    public let count: Int
   
    public private(set) var components: [Int]
    
    public var description: String {
        let components = components
            .map({ String($0) })
            .joined(separator: ", ")
        return "<Vector [\(count)] \(components)>"
    }
    
    public init(dimension: Int) {
        precondition(dimension > 0)
        self.init(Array(repeating: 0, count: dimension))
    }
    
    public init(_ components: [Int]) {
        precondition(!components.isEmpty)
        self.components = components
        self.count = components.count
    }
    
    public subscript(index: Int) -> Int {
        get {
            components[index]
        }
        set {
            components[index] = newValue
        }
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


public struct FloatVector: Equatable, CustomStringConvertible {
    
    public let count: Int
    public private(set) var components: [Float]
    
    public var description: String {
        let components = components
            .map({ String(format: "%0.3f", $0) })
            .joined(separator: ", ")
        return "<Vector [\(count)] \(components)>"
    }
    
    public init(dimension: Int) {
        precondition(dimension > 0)
        self.init(Array(repeating: 0, count: dimension))
    }

    public init(_ components: [Float]) {
        precondition(!components.isEmpty)
        precondition(components.reduce(0) { c, _ in c.isNaN ? 1 : 0 } == 0)
        self.components = components
        self.count = components.count
    }
    
    public subscript(index: Int) -> Float {
        get {
            components[index]
        }
        set {
            components[index] = newValue
        }
    }
    
    public func square() -> FloatVector {
        return FloatVector(vDSP.square(components))
    }
    
    public func sum() -> Float {
        return vDSP.sum(components)
    }
    
    public func magnitude() -> Float {
        return vDSP.sumOfSquares(components)
//        return components.reduce(0) { total, component in
//            total + (component * component)
//        }
    }
    
    public func length() -> Float {
        return sqrt(magnitude())
    }
    
    public func normalized() -> FloatVector {
        let length = length()
        guard length > 0 else {
            return self
        }
        return self / length
    }
    
    public func mean() -> Float {
        precondition(count > 0)
        return vDSP.mean(components)
        // return components.reduce(0) { $0 + $1 } / Float(count)
    }
    
    public func populationStandardDeviation() -> Float {
        precondition(count > 0)
        let mean = mean()
//        var sum: Float = 0
//        for i in 0 ..< count {
//            let deviation = components[i] - mean
//            let squaredDeviation = deviation * deviation
//            sum += squaredDeviation
//        }
//        let deviation = sum / Float(components.count)
        let sumOfSquares = (self - mean).magnitude()
        let deviation = sumOfSquares / Float(components.count)
        let standardDeviation = sqrt(deviation)
        return standardDeviation
    }
    
    public func sampleStandardDeviation() -> Float {
        precondition(count > 1)
        let mean = mean()
//        var sum: Float = 0
//        for i in 0 ..< count {
//            let deviation = components[i] - mean
//            let squaredDeviation = deviation * deviation
//            sum += squaredDeviation
//        }
//        let deviation = sum / Float(count - 1)
        let sumOfSquares = (self - mean).magnitude()
        let deviation = sumOfSquares / Float(components.count - 1)
        let standardDeviation = sqrt(deviation)
        return standardDeviation
    }

    public func standardized() -> FloatVector {
        precondition(count > 0)
        let standardDeviation = sampleStandardDeviation()
        guard standardDeviation != 0 else {
            return self
        }
        let output = (self - mean()) / standardDeviation
        return output
//        var output: [Float] = Array(repeating: 0, count: count)
//        for i in 0 ..< count {
//            output[i] = (components[i] - mean) / standardDeviation
//        }
//        return FloatVector(output)
    }
    
    public func cosineSimilarity(to other: FloatVector) -> Float {
        let d = dotProduct(with: other)
        let m = length() * other.length()
        return d / m
    }
    
    public func dotProduct(with other: FloatVector) -> Float {
//        return zip(components, other.components).map(*).reduce(0, +)
        return vDSP.dot(components, other.components)
    }
    
    ///
    /// Computes the vector-matrix dot product, also known as the inner product or scalar product:
    ///
    /// x · A
    ///
    public func dotProduct(with matrix: FloatMatrix) -> FloatVector {
        precondition(count == matrix.rowCount)
        
        let m: __CLPK_integer = __CLPK_integer(matrix.rowCount)
        let n: __CLPK_integer = __CLPK_integer(matrix.columnCount)
        let lda: __CLPK_integer = m
        var a: [__CLPK_real] = matrix.columnMajorOrderValues
        let x: [__CLPK_real] = components
        var y: [__CLPK_real] = Array(repeating: 0, count: Int(m))

        cblas_sgemv(CblasColMajor, CblasTrans, m, n, 1.0, &a, lda, x, 1, 0.0, &y, 1);

        return FloatVector(y)
    }
    
    ///
    /// Computes the outer product with another vector.
    ///
    /// Returns an M x N matrix (M rows x N columns) where M is the number of elements in this vector, and
    /// N is the number of elements in the input vector.
    ///
    /// [1] G. H. Golub and C. F. Van Loan, Matrix Computations, 3rd ed., Baltimore, MD, Johns Hopkins University Press, 1996, pg. 8.
    ///
    public func outerProduct(with other: FloatVector) -> FloatMatrix {
        var m = FloatMatrix(columns: other.count, rows: count)
        for j in 0 ..< other.count {
            let k = other[j]
            for i in 0 ..< count {
                m[j, i] += self[i] * k
            }
        }
        return m
    }

    public func distanceSquared(to other: FloatVector) -> Float {
        precondition(count == other.count)
//        var k: Float = 0
//        for i in 0 ..< count {
//            let d = other[i] - self[i]
//            k += d * d
//        }
//        return k
        return vDSP.distanceSquared(components, other.components)
    }
    
    public func distance(to other: FloatVector) -> Float {
        return sqrt(distanceSquared(to: other))
    }
    
    public static func +(lhs: FloatVector, rhs: FloatVector) -> FloatVector {
//        return FloatVector(zip(lhs.components, rhs.components).map(+))
        return FloatVector(vDSP.add(lhs.components, rhs.components))
    }
    
    public static func +(lhs: FloatVector, rhs: Float) -> FloatVector {
//        return FloatVector(zip(lhs.components, rhs.components).map(+))
        return FloatVector(vDSP.add(rhs, lhs.components))
    }

    public static func -(lhs: FloatVector, rhs: FloatVector) -> FloatVector {
//        return FloatVector(zip(lhs.components, rhs.components).map(-))
        return FloatVector(vDSP.subtract(lhs.components, rhs.components))
    }
    
    public static func -(lhs: FloatVector, rhs: Float) -> FloatVector {
        return FloatVector(vDSP.add(-rhs, lhs.components))
    }

    public static func *(lhs: FloatVector, rhs: Float) -> FloatVector {
//        return FloatVector(lhs.components.map { $0 * rhs })
        return FloatVector(vDSP.multiply(rhs, lhs.components))
    }

    public static func /(lhs: FloatVector, rhs: Float) -> FloatVector {
        precondition(rhs != 0)
//        return FloatVector(lhs.components.map { $0 / rhs })
        return FloatVector(vDSP.divide(lhs.components, rhs))
    }
}


///
/// M x N matrix
///
public struct FloatMatrix {
    
    public enum ProgramError: Error {
        case invalidParameter(Int)
        case cannotAllocateWork
    }
    
    public enum ComputationError: Error {
        case cannotInvertNonSquareMatrix
        case cannotInvertSingularMatrix
    }
    
    var columnMajorOrderValues: [Float] {
        return Array(columns.lazy.map { $0.components }.joined())
//        var matrix: [__CLPK_real] = []
//        for column in columns {
//            matrix.append(contentsOf: column.components)
//        }
    }
    
    let columnCount: Int
    let rowCount: Int
    
    private var columns: [FloatVector]
    
    public init(columnMajorOrderValues values: [Float], rows: Int) {
        var columns = [FloatVector]()
        for i in stride(from: 0, to: values.count, by: rows) {
            let components = values[i ..< i + rows]
            let column = FloatVector(Array(components))
            columns.append(column)
        }
        self.init(columns)
    }
    
    public init(columns: Int, rows: Int) {
        precondition(columns > 0)
        precondition(rows > 0)
        let column = FloatVector(dimension: rows)
        self.init(Array(repeating: column, count: columns))
    }
    
    public init(_ columns: [FloatVector]) {
        self.rowCount = columns[0].count
        self.columnCount = columns.count
        precondition(columnCount > 0)
        precondition(columns[0].count > 0)
        precondition(columns.first { $0.count != columns[0].count } == nil)
        self.columns = columns
    }
    
    public subscript(column: Int, row: Int) -> Float {
        get {
            columns[column][row]
        }
        set {
            columns[column][row] = newValue
        }
    }
    
    public subscript(column: Int) -> FloatVector {
        get {
            columns[column]
        }
        set {
            precondition(newValue.count == rowCount)
            columns[column] = newValue
        }
    }
    
    public func sum() -> FloatVector {
        return columns.reduce(FloatVector(dimension: rowCount), +)
    }
    
    public func mean() -> FloatVector {
        return sum() / Float(columnCount)
    }

    public func zeroMean() -> Self {
        return self - mean()
    }
    
    public func covarianceMatrix() -> FloatMatrix {
        let n = columnCount
        let d = rowCount

        let zeroMean = zeroMean()
        
        var outerProducts = FloatMatrix(columns: d, rows: d)
        for i in 0 ..< n {
            for j in 0 ..< d {
                for k in 0 ..< d {
                    outerProducts[j][k] += zeroMean[i][j] * zeroMean[i][k]
                }
            }
        }
        
        guard n > 1 else {
            return outerProducts
        }

        var covariance = FloatMatrix(columns: d, rows: d)
        for i in 0 ..< d {
            for j in 0 ..< d {
                covariance[i][j] = outerProducts[i][j] / Float(n - 1)
            }
        }
        
        return covariance
    }
    
    public func dotProduct(with vector: FloatVector) -> FloatVector {
        // See: https://stackoverflow.com/a/29182830/762377
        // https://developer.apple.com/documentation/accelerate/1513065-cblas_sgemv
        //  Note: you'll want to store A in *column-major* order to use it with
        //  LAPACK (even though it's not strictly necessary for this simple example,
        //  if you try to do something more complex you'll need it).
        // float A[3][3] = {{-4,-3,-5}, {6,-7, 9}, {8,-2,-1}};
        // float x[3] = { -1, 10, -3};
        //  Compute b = Ax using cblas_sgemv.
        // float b[3];
        // cblas_sgemv(CblasColMajor, CblasNoTrans, 3, 3, 1.f, &A[0][0], 3, x, 1, 0.f, b, 1);
        // printf("b := A x = [ %g, %g, %g ]\n", b[0], b[1], b[2]);
        
        precondition(vector.count == columnCount)
        
        let m: __CLPK_integer = __CLPK_integer(rowCount)
        let n: __CLPK_integer = __CLPK_integer(columnCount)
        let lda: __CLPK_integer = m
        var a: [__CLPK_real] = columnMajorOrderValues
        let x: [__CLPK_real] = vector.components
        var y: [__CLPK_real] = Array(repeating: 0, count: Int(m))

        cblas_sgemv(CblasColMajor, CblasNoTrans, m, n, 1.0, &a, lda, x, 1, 0.0, &y, 1);

        return FloatVector(y)
    }

    public func inverse() throws -> FloatMatrix {
        // Assume square matrix
        guard rowCount == columnCount else {
            throw ComputationError.cannotInvertNonSquareMatrix
        }

//        var matrix: [__CLPK_real] = []
//        for column in columns {
//            matrix.append(contentsOf: column.components)
//        }
        var m = __CLPK_integer(rowCount)
        var n = __CLPK_integer(columnCount)
        var lda = m
        var a = columnMajorOrderValues
        var ipiv: [__CLPK_integer] = Array(repeating: 0, count: Int(min(m, n)))
        var lwork: __CLPK_integer = -1
        var work: [__CLPK_real] = [0]
        var info = __CLPK_integer(0)

        // Compute LU factorization.
        // See: https://netlib.org/lapack/explore-html/d8/ddc/group__real_g_ecomputational_ga8d99c11b94db3d5eac75cac46a0f2e17.html#ga8d99c11b94db3d5eac75cac46a0f2e17
        sgetrf_(&m, &n, &a, &lda, &ipiv, &info)
        
        // SGETRI computes the inverse of a matrix using the LU factorization
        // computed by SGETRF.
        // See: https://netlib.org/lapack/explore-html/d8/ddc/group__real_g_ecomputational_ga1af62182327d0be67b1717db399d7d83.html#ga1af62182327d0be67b1717db399d7d83
        
        // Get the ideal work size.
        sgetri_(&n, &a, &lda, &ipiv, &work, &lwork, &info)
        
        // Get inverse.
        work = Array(repeating: 0, count: Int(work[0]))
        sgetri_(&n, &a, &lda, &ipiv, &work, &lwork, &info)

        if info < 0 {
            throw ProgramError.invalidParameter(Int(-info))
        }
        else if info > 0 {
            throw ComputationError.cannotInvertSingularMatrix
        }
        
//        var columns = [FloatVector]()
//        for i in stride(from: 0, to: matrix.count, by: rowCount) {
//            let components = matrix[i ..< i + rowCount]
//            let column = FloatVector(Array(components))
//            columns.append(column)
//        }
        return FloatMatrix(columnMajorOrderValues: a, rows: rowCount)
    }
    
    public static func identity(dimensions: Int) -> FloatMatrix {
        var m = FloatMatrix(columns: dimensions, rows: dimensions)
        for i in 0 ..< dimensions {
            m[i, i] = 1
        }
        return m
    }
    
    public static func -(lhs: FloatMatrix, rhs: FloatVector) -> FloatMatrix {
        precondition(rhs.count == lhs.rowCount)
        return FloatMatrix(lhs.columns.map { $0 - rhs })
    }
}
