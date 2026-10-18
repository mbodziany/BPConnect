import Foundation

public enum CubeValidationError: Error, Equatable, Sendable {
    case duplicateCenters
    case wrongColorCount(CubeColor, Int)
    case impossiblePiece
    case duplicatePiece
    case twistedCorner
    case flippedEdge
    case swappedPieces

    public var message: String {
        switch self {
        case .duplicateCenters:
            return "Dwa środki mają ten sam kolor. Każda ściana musi mieć inny środek."
        case let .wrongColorCount(color, n):
            return "Kolor \(color.name) występuje \(n) razy, a powinien 9."
        case .impossiblePiece:
            return "Któryś narożnik lub krawędź ma kombinację kolorów, która nie istnieje na kostce (np. dwa przeciwne kolory obok siebie). Sprawdź naklejki."
        case .duplicatePiece:
            return "Ten sam element (narożnik lub krawędź) pojawia się dwa razy. Sprawdź naklejki."
        case .twistedCorner:
            return "Jeden narożnik jest obrócony w sposób niemożliwy do ułożenia – prawdopodobnie błędnie rozpoznana naklejka (albo ktoś przekręcił narożnik)."
        case .flippedEdge:
            return "Jedna krawędź jest odwrócona w sposób niemożliwy do ułożenia – prawdopodobnie błędnie rozpoznana naklejka."
        case .swappedPieces:
            return "Dwa elementy są zamienione miejscami w sposób niemożliwy do ułożenia – sprawdź naklejki."
        }
    }
}

public enum CubeValidator {
    /// Zamienia kolory naklejek na ściany (wg kolorów środków) i sprawdza, czy taki stan da się ułożyć.
    public static func validate(colors: [CubeColor]) -> Result<CubieCube, CubeValidationError> {
        precondition(colors.count == 54)
        var faceOf: [CubeColor: Face] = [:]
        for f in Face.allCases { faceOf[colors[f.rawValue * 9 + 4]] = f }
        if faceOf.count != 6 { return .failure(.duplicateCenters) }
        for c in CubeColor.allCases {
            let n = colors.filter { $0 == c }.count
            if n != 9 { return .failure(.wrongColorCount(c, n)) }
        }
        return validate(facelets: colors.map { faceOf[$0]! })
    }

    public static func validate(facelets: [Face]) -> Result<CubieCube, CubeValidationError> {
        guard let cube = CubieCube(facelets: facelets) else { return .failure(.impossiblePiece) }
        if Set(cube.cp).count != 8 || Set(cube.ep).count != 12 { return .failure(.duplicatePiece) }
        if cube.co.reduce(0, +) % 3 != 0 { return .failure(.twistedCorner) }
        if cube.eo.reduce(0, +) % 2 != 0 { return .failure(.flippedEdge) }
        if parity(cube.cp) != parity(cube.ep) { return .failure(.swappedPieces) }
        return .success(cube)
    }

    static func parity(_ p: [Int]) -> Int {
        var s = 0
        for i in 0..<p.count {
            for j in (i + 1)..<p.count where p[i] > p[j] { s += 1 }
        }
        return s % 2
    }
}
