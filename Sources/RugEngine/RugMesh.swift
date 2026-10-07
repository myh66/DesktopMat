import Foundation
import simd

/// Mutable three-dimensional surface data shared by simulation and rendering.
/// The resting plane and simulated fabric share this topology and UV mapping.
public struct RugVertex: Sendable {
    public var position: SIMD3<Float>
    public var normal: SIMD3<Float>
    public var textureCoordinate: SIMD2<Float>

    public init(position: SIMD3<Float>, normal: SIMD3<Float>, textureCoordinate: SIMD2<Float>) {
        self.position = position
        self.normal = normal
        self.textureCoordinate = textureCoordinate
    }
}

public struct RugMesh: Sendable {
    public let columns: Int
    public let rows: Int
    public var vertices: [RugVertex]
    public let triangleIndices: [UInt32]

    /// Counts refer to cells, giving (columns + 1) * (rows + 1) particles.
    /// Positions are in a normalized resting rectangle and z is height above it.
    public init(columns: Int = 40, rows: Int = 30) {
        precondition(columns > 0 && rows > 0, "The rug must contain at least one cell.")
        precondition(columns <= 256 && rows <= 256, "Mesh dimensions exceed the supported MVP range.")
        self.columns = columns
        self.rows = rows
        var vertices: [RugVertex] = []
        vertices.reserveCapacity((columns + 1) * (rows + 1))
        for row in 0...rows {
            for column in 0...columns {
                let uv = SIMD2<Float>(Float(column) / Float(columns), Float(row) / Float(rows))
                vertices.append(RugVertex(
                    position: SIMD3(uv.x - 0.5, uv.y - 0.5, 0),
                    normal: SIMD3(0, 0, 1),
                    textureCoordinate: uv
                ))
            }
        }
        var indices: [UInt32] = []
        indices.reserveCapacity(columns * rows * 6)
        for row in 0..<rows {
            for column in 0..<columns {
                let lowerLeft = UInt32(row * (columns + 1) + column)
                let lowerRight = lowerLeft + 1
                let upperLeft = lowerLeft + UInt32(columns + 1)
                let upperRight = upperLeft + 1
                indices.append(contentsOf: [lowerLeft, lowerRight, upperLeft, lowerRight, upperRight, upperLeft])
            }
        }
        self.vertices = vertices
        self.triangleIndices = indices
    }

    public var triangleCount: Int { triangleIndices.count / 3 }
    public var vertexCount: Int { vertices.count }

    public func vertexIndex(column: Int, row: Int) -> Int? {
        guard (0...columns).contains(column), (0...rows).contains(row) else { return nil }
        return row * (columns + 1) + column
    }

    /// Recompute weighted normals after the cloth solver deforms the surface.
    public mutating func updateNormals() {
        for index in vertices.indices { vertices[index].normal = .zero }
        for triangle in stride(from: 0, to: triangleIndices.count, by: 3) {
            let a = Int(triangleIndices[triangle])
            let b = Int(triangleIndices[triangle + 1])
            let c = Int(triangleIndices[triangle + 2])
            let normal = simd_cross(vertices[b].position - vertices[a].position, vertices[c].position - vertices[a].position)
            vertices[a].normal += normal
            vertices[b].normal += normal
            vertices[c].normal += normal
        }
        for index in vertices.indices {
            let normal = vertices[index].normal
            vertices[index].normal = simd_length_squared(normal) > 0.000001 ? simd_normalize(normal) : SIMD3(0, 0, 1)
        }
    }
}
