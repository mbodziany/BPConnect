import Foundation

public struct RGB: Hashable, Sendable, Codable {
    public var r, g, b: Double
    public init(_ r: Double, _ g: Double, _ b: Double) { self.r = r; self.g = g; self.b = b }
}

struct Lab { var l, a, b: Double }

enum ColorMath {
    static func linear(_ c: Double) -> Double {
        c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }

    static func lab(_ c: RGB) -> Lab {
        let r = linear(c.r), g = linear(c.g), b = linear(c.b)
        let x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047
        let y = 0.2126 * r + 0.7152 * g + 0.0722 * b
        let z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883
        func f(_ t: Double) -> Double { t > 0.008856 ? cbrt(t) : 7.787 * t + 16.0 / 116.0 }
        let fx = f(x), fy = f(y), fz = f(z)
        return Lab(l: 116 * fy - 16, a: 500 * (fx - fy), b: 200 * (fy - fz))
    }

    /// Odległość kolorów. Jasność waży mniej niż barwa, bo oświetlenie zmienia głównie jasność.
    static func distance(_ p: Lab, _ q: Lab) -> Double {
        let dl = (p.l - q.l) * 0.5, da = p.a - q.a, db = p.b - q.b
        return (dl * dl + da * da + db * db).squareRoot()
    }
}

public enum ColorClassifier {
    /// Szybkie zgadywanie koloru pojedynczej naklejki (podgląd na żywo w aparacie).
    public static func guess(_ rgb: RGB) -> CubeColor {
        let p = ColorMath.lab(rgb)
        return CubeColor.allCases.min {
            ColorMath.distance(p, ColorMath.lab($0.referenceRGB)) < ColorMath.distance(p, ColorMath.lab($1.referenceRGB))
        }!
    }

    /// Przypisuje środkom kolory (każdy inny), wybierając najlepsze dopasowanie spośród wszystkich 720 permutacji.
    public static func assignCenters(_ centers: [Face: RGB]) -> [Face: CubeColor] {
        let faces = Face.allCases
        let labs = faces.map { ColorMath.lab(centers[$0]!) }
        let refs = CubeColor.allCases.map { ColorMath.lab($0.referenceRGB) }
        var best: [Int] = Array(0..<6)
        var bestCost = Double.infinity
        func permute(_ used: [Bool], _ current: [Int], _ cost: Double) {
            if cost >= bestCost { return }
            if current.count == 6 { best = current; bestCost = cost; return }
            let i = current.count
            for c in 0..<6 where !used[c] {
                var u = used; u[c] = true
                permute(u, current + [c], cost + ColorMath.distance(labs[i], refs[c]))
            }
        }
        permute(Array(repeating: false, count: 6), [], 0)
        var result: [Face: CubeColor] = [:]
        for (i, f) in faces.enumerated() { result[f] = CubeColor(rawValue: best[i])! }
        return result
    }

    /// Klasyfikuje wszystkie 54 naklejki. Punktem odniesienia są środki sfotografowane w tym samym świetle,
    /// a każdy kolor może wystąpić najwyżej 9 razy (przydział zachłanny od najpewniejszych par).
    /// - Parameter samples: 54 próbki w kolejności naklejek (U R F D L B, po 9).
    /// - Returns: dla każdej naklejki ściana, której środek ma ten kolor.
    public static func classify(_ samples: [RGB]) -> [Face] {
        precondition(samples.count == 54)
        let labs = samples.map(ColorMath.lab)
        let centerLabs = Face.allCases.map { labs[$0.rawValue * 9 + 4] }
        var pairs: [(d: Double, sticker: Int, face: Int)] = []
        for s in 0..<54 {
            for f in 0..<6 { pairs.append((ColorMath.distance(labs[s], centerLabs[f]), s, f)) }
        }
        pairs.sort { $0.d < $1.d }
        var result: [Face?] = Array(repeating: nil, count: 54)
        var count = Array(repeating: 0, count: 6)
        for f in 0..<6 { result[f * 9 + 4] = Face(rawValue: f); count[f] = 1 }
        for p in pairs where result[p.sticker] == nil && count[p.face] < 9 {
            result[p.sticker] = Face(rawValue: p.face)
            count[p.face] += 1
        }
        return result.map { $0! }
    }
}
