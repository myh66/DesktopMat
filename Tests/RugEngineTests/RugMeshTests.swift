import Testing
import simd
@testable import RugEngine

@Test func gridHasExpectedTopologyAndTextureCoverage() {
    let mesh = RugMesh(columns: 40, rows: 30)
    #expect(mesh.vertexCount == 41 * 31)
    #expect(mesh.triangleCount == 40 * 30 * 2)
    #expect(mesh.triangleIndices.allSatisfy { Int($0) < mesh.vertexCount })
    #expect(mesh.vertices.first?.textureCoordinate == SIMD2<Float>(0, 0))
    #expect(mesh.vertices.last?.textureCoordinate == SIMD2<Float>(1, 1))
    #expect(mesh.vertexIndex(column: 40, row: 30) == 1270)
    #expect(mesh.vertexIndex(column: 41, row: 30) == nil)
    #expect(mesh.vertexIndex(column: 0, row: -1) == nil)
    for vertex in mesh.vertices {
        #expect(vertex.position.x.isFinite && vertex.position.y.isFinite && vertex.position.z.isFinite)
        #expect((0...1).contains(vertex.textureCoordinate.x))
        #expect((0...1).contains(vertex.textureCoordinate.y))
    }
}

@Test func trianglesFaceUpAndNormalsSurviveSurfaceDeformation() {
    var mesh = RugMesh(columns: 4, rows: 3)
    for index in stride(from: 0, to: mesh.triangleIndices.count, by: 3) {
        let a = mesh.vertices[Int(mesh.triangleIndices[index])].position
        let b = mesh.vertices[Int(mesh.triangleIndices[index + 1])].position
        let c = mesh.vertices[Int(mesh.triangleIndices[index + 2])].position
        #expect(simd_cross(b - a, c - a).z > 0)
    }
    for index in mesh.vertices.indices {
        let point = mesh.vertices[index].position
        mesh.vertices[index].position.z = 0.2 * point.x
    }
    mesh.updateNormals()
    let expected = simd_normalize(SIMD3<Float>(-0.2, 0, 1))
    for vertex in mesh.vertices {
        #expect(simd_distance(vertex.normal, expected) < 0.00001)
    }
}
