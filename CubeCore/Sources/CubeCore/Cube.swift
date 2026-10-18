import Foundation

/// Ściany kostki w kolejności Kociemby: U R F D L B.
/// Ściana jest wyznaczona przez swój środek – środki nigdy się nie przesuwają.
public enum Face: Int, CaseIterable, Hashable, Sendable {
    case U, R, F, D, L, B

    public var letter: String { ["U", "R", "F", "D", "L", "B"][rawValue] }
}

/// Pojedynczy ruch: ściana + liczba ćwierćobrotów zgodnie z ruchem wskazówek zegara (1, 2, 3).
public struct Move: Hashable, Sendable, CustomStringConvertible {
    public let face: Face
    public let turns: Int

    public init(_ face: Face, _ turns: Int = 1) {
        self.face = face
        self.turns = ((turns % 4) + 4) % 4
    }

    public var description: String { face.letter + ["", "", "2", "'"][turns] }

    public var inverse: Move { Move(face, 4 - turns) }

    /// "R U R' U2" -> [R, U, R', U2]
    public static func parse(_ text: String) -> [Move] {
        text.split(separator: " ").compactMap { token in
            guard let first = token.first,
                  let face = Face.allCases.first(where: { $0.letter == String(first) }) else { return nil }
            let suffix = token.dropFirst()
            switch suffix {
            case "": return Move(face, 1)
            case "2": return Move(face, 2)
            case "'": return Move(face, 3)
            default: return nil
            }
        }
    }
}

extension Array where Element == Move {
    public var notation: String { map(\.description).joined(separator: " ") }
}

// MARK: - Geometria naklejek

/// Indeksy naklejek: U 0-8, R 9-17, F 18-26, D 27-35, L 36-44, B 45-53.
/// Każda ściana czytana wierszami jak w klasycznej siatce:
/// U widziana z góry (B u góry obrazka), D widziana z dołu (F u góry obrazka),
/// F, R, B, L widziane z przodu każdej ściany z U na górze.
enum Geometry {
    struct Vec3: Hashable { var x, y, z: Int }

    static func normal(_ f: Face) -> Vec3 {
        switch f {
        case .U: return Vec3(x: 0, y: 1, z: 0)
        case .D: return Vec3(x: 0, y: -1, z: 0)
        case .F: return Vec3(x: 0, y: 0, z: 1)
        case .B: return Vec3(x: 0, y: 0, z: -1)
        case .R: return Vec3(x: 1, y: 0, z: 0)
        case .L: return Vec3(x: -1, y: 0, z: 0)
        }
    }

    /// Pozycja kostki (cubie), na której leży naklejka (wiersz r, kolumna c) danej ściany.
    static func position(_ f: Face, _ r: Int, _ c: Int) -> Vec3 {
        switch f {
        case .U: return Vec3(x: c - 1, y: 1, z: r - 1)
        case .D: return Vec3(x: c - 1, y: -1, z: 1 - r)
        case .F: return Vec3(x: c - 1, y: 1 - r, z: 1)
        case .B: return Vec3(x: 1 - c, y: 1 - r, z: -1)
        case .R: return Vec3(x: 1, y: 1 - r, z: 1 - c)
        case .L: return Vec3(x: -1, y: 1 - r, z: c - 1)
        }
    }

    static func dot(_ a: Vec3, _ b: Vec3) -> Int { a.x * b.x + a.y * b.y + a.z * b.z }

    static func cross(_ a: Vec3, _ b: Vec3) -> Vec3 {
        Vec3(x: a.y * b.z - a.z * b.y, y: a.z * b.x - a.x * b.z, z: a.x * b.y - a.y * b.x)
    }

    /// Obrót o 90° zgodnie z ruchem wskazówek zegara, patrząc na ścianę o normalnej k z zewnątrz.
    static func rotateClockwise(_ p: Vec3, around k: Vec3) -> Vec3 {
        let kp = cross(k, p)
        let d = dot(k, p)
        return Vec3(x: -kp.x + k.x * d, y: -kp.y + k.y * d, z: -kp.z + k.z * d)
    }

    struct Sticker: Hashable { var position: Vec3; var normal: Vec3 }

    static let stickers: [Sticker] = {
        var result: [Sticker] = []
        for f in Face.allCases {
            for r in 0..<3 {
                for c in 0..<3 {
                    result.append(Sticker(position: Geometry.position(f, r, c), normal: Geometry.normal(f)))
                }
            }
        }
        return result
    }()

    /// Permutacja naklejek dla ćwierćobrotu: nowe[i] = stare[perm[i]].
    static func faceletPermutation(_ face: Face) -> [Int] {
        let k = normal(face)
        var index: [Sticker: Int] = [:]
        for (i, s) in stickers.enumerated() { index[s] = i }
        var perm = Array(0..<54)
        for (i, s) in stickers.enumerated() where dot(s.position, k) == 1 {
            let moved = Sticker(position: rotateClockwise(s.position, around: k),
                                normal: rotateClockwise(s.normal, around: k))
            perm[index[moved]!] = i
        }
        return perm
    }
}

// MARK: - Model kostek (cubie)

/// Narożniki: URF UFL ULB UBR DFR DLF DBL DRB; krawędzie: UR UF UL UB DR DF DL DB FR FL BL BR.
public enum Pieces {
    static func facelet(_ s: String) -> Int {
        let face = Face.allCases.first { $0.letter == String(s.first!) }!
        return face.rawValue * 9 + Int(String(s.last!))! - 1
    }

    public static let cornerFacelets: [[Int]] = [
        ["U9", "R1", "F3"], ["U7", "F1", "L3"], ["U1", "L1", "B3"], ["U3", "B1", "R3"],
        ["D3", "F9", "R7"], ["D1", "L9", "F7"], ["D7", "B9", "L7"], ["D9", "R9", "B7"]
    ].map { $0.map(Pieces.facelet) }

    public static let edgeFacelets: [[Int]] = [
        ["U6", "R2"], ["U8", "F2"], ["U4", "L2"], ["U2", "B2"], ["D6", "R8"], ["D2", "F8"],
        ["D4", "L8"], ["D8", "B8"], ["F6", "R4"], ["F4", "L6"], ["B6", "L4"], ["B4", "R6"]
    ].map { $0.map(Pieces.facelet) }

    /// Ściany, do których należy dany narożnik / krawędź (w kolejności naklejek powyżej).
    public static let cornerFaces: [[Face]] = Pieces.cornerFacelets.map { $0.map { Face(rawValue: $0 / 9)! } }
    public static let edgeFaces: [[Face]] = Pieces.edgeFacelets.map { $0.map { Face(rawValue: $0 / 9)! } }

    public static func corner(between faces: Set<Face>) -> Int {
        cornerFaces.firstIndex { Set($0) == faces }!
    }

    public static func edge(between faces: Set<Face>) -> Int {
        edgeFaces.firstIndex { Set($0) == faces }!
    }
}

public struct CubieCube: Hashable, Sendable {
    public var cp: [Int] = Array(0..<8)
    public var co: [Int] = Array(repeating: 0, count: 8)
    public var ep: [Int] = Array(0..<12)
    public var eo: [Int] = Array(repeating: 0, count: 12)

    public init() {}

    public static let solved = CubieCube()

    public var isSolved: Bool { self == .solved }

    /// Złożenie: najpierw self, potem b.
    public func multiplied(by b: CubieCube) -> CubieCube {
        var r = CubieCube()
        for i in 0..<8 {
            r.cp[i] = cp[b.cp[i]]
            r.co[i] = (co[b.cp[i]] + b.co[i]) % 3
        }
        for i in 0..<12 {
            r.ep[i] = ep[b.ep[i]]
            r.eo[i] = (eo[b.ep[i]] + b.eo[i]) % 2
        }
        return r
    }

    public func applying(_ move: Move) -> CubieCube {
        multiplied(by: MoveTables.cubes[move.face.rawValue][move.turns])
    }

    public func applying(_ moves: [Move]) -> CubieCube {
        moves.reduce(self) { $0.applying($1) }
    }

    /// Kolor (ściana środka) każdej z 54 naklejek.
    public var facelets: [Face] {
        var f = (0..<54).map { Face(rawValue: $0 / 9)! }
        for i in 0..<8 {
            for k in 0..<3 {
                f[Pieces.cornerFacelets[i][(k + co[i]) % 3]] = Pieces.cornerFaces[cp[i]][k]
            }
        }
        for i in 0..<12 {
            for k in 0..<2 {
                f[Pieces.edgeFacelets[i][(k + eo[i]) % 2]] = Pieces.edgeFaces[ep[i]][k]
            }
        }
        return f
    }

    /// Odtwarza stan kostek z naklejek. Zwraca nil, gdy jakiegoś elementu nie da się rozpoznać.
    public init?(facelets f: [Face]) {
        guard f.count == 54 else { return nil }
        for i in 0..<8 {
            let fl = Pieces.cornerFacelets[i]
            guard let ori = (0..<3).first(where: { f[fl[$0]] == .U || f[fl[$0]] == .D }) else { return nil }
            let c1 = f[fl[(ori + 1) % 3]], c2 = f[fl[(ori + 2) % 3]]
            guard let j = (0..<8).first(where: { Pieces.cornerFaces[$0][1] == c1 && Pieces.cornerFaces[$0][2] == c2 }) else { return nil }
            cp[i] = j
            co[i] = ori
        }
        for i in 0..<12 {
            let a = f[Pieces.edgeFacelets[i][0]], b = f[Pieces.edgeFacelets[i][1]]
            if let j = (0..<12).first(where: { Pieces.edgeFaces[$0] == [a, b] }) {
                ep[i] = j
                eo[i] = 0
            } else if let j = (0..<12).first(where: { Pieces.edgeFaces[$0] == [b, a] }) {
                ep[i] = j
                eo[i] = 1
            } else {
                return nil
            }
        }
    }

    public func cornerPosition(of piece: Int) -> Int { cp.firstIndex(of: piece)! }
    public func edgePosition(of piece: Int) -> Int { ep.firstIndex(of: piece)! }
    public func cornerSolved(_ i: Int) -> Bool { cp[i] == i && co[i] == 0 }
    public func edgeSolved(_ i: Int) -> Bool { ep[i] == i && eo[i] == 0 }
}

enum MoveTables {
    /// cubes[ściana][liczba ćwierćobrotów 0...3]
    static let cubes: [[CubieCube]] = Face.allCases.map { face in
        let perm = Geometry.faceletPermutation(face)
        let solved = CubieCube.solved.facelets
        let quarter = CubieCube(facelets: perm.map { solved[$0] })!
        var powers = [CubieCube.solved]
        for _ in 1..<4 { powers.append(powers.last!.multiplied(by: quarter)) }
        return powers
    }
}

// MARK: - Publiczny układ naklejek (do rysowania 3D)

public struct StickerPosition: Sendable {
    /// Indeks naklejki 0...53
    public let index: Int
    /// Ściana, na której leży naklejka (kierunek normalnej).
    public let face: Face
    /// Pozycja kostki (cubie): x w prawo (R), y w górę (U), z do przodu (F), wartości -1...1.
    public let x: Int, y: Int, z: Int
}

public enum CubeGeometry {
    public static let stickers: [StickerPosition] = Geometry.stickers.enumerated().map { i, s in
        StickerPosition(index: i, face: Face(rawValue: i / 9)!, x: s.position.x, y: s.position.y, z: s.position.z)
    }

    /// Wektor normalnej ściany (x, y, z).
    public static func normal(_ face: Face) -> (x: Int, y: Int, z: Int) {
        let n = Geometry.normal(face)
        return (n.x, n.y, n.z)
    }
}
