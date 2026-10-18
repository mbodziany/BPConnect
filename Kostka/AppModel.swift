import SwiftUI
import CubeCore

enum Route: Hashable {
    case scan
    case editor
    case solution
    case notation
}

@Observable
final class AppModel {
    var path: [Route] = []
    /// Kolory 54 naklejek w kolejności U R F D L B (po 9, wierszami).
    var colors: [CubeColor] = AppModel.solvedColors
    var solution: Solution?
    var colorOf: [Face: CubeColor] = CubeColor.standardScheme
    var isSolving = false
    var validationError: String?

    static var solvedColors: [CubeColor] {
        CubieCube.solved.facelets.map { CubeColor.standardScheme[$0]! }
    }

    func loadScramble() {
        let scramble = (0..<25).map { _ in Move(Face.allCases.randomElement()!, Int.random(in: 1...3)) }
        colors = CubieCube.solved.applying(scramble).facelets.map { CubeColor.standardScheme[$0]! }
        validationError = nil
    }

    func resetToSolved() {
        colors = AppModel.solvedColors
        validationError = nil
    }

    /// Zapisuje wynik skanowania: 54 próbki RGB w kolejności U R F D L B.
    func applyScan(samples: [RGB]) {
        let faces = ColorClassifier.classify(samples)
        var centers: [Face: RGB] = [:]
        for f in Face.allCases { centers[f] = samples[f.rawValue * 9 + 4] }
        let scheme = ColorClassifier.assignCenters(centers)
        colors = faces.map { scheme[$0]! }
        validationError = nil
    }

    @MainActor
    func solve() async {
        switch CubeValidator.validate(colors: colors) {
        case let .failure(error):
            validationError = error.message
        case let .success(cube):
            validationError = nil
            var scheme: [Face: CubeColor] = [:]
            for f in Face.allCases { scheme[f] = colors[f.rawValue * 9 + 4] }
            colorOf = scheme
            isSolving = true
            let result = await Task.detached(priority: .userInitiated) {
                Solver.solve(cube, colors: scheme)
            }.value
            isSolving = false
            solution = result
            path.append(.solution)
        }
    }
}

extension CubeColor {
    var color: Color {
        let c = displayRGB
        return Color(red: c.r, green: c.g, blue: c.b)
    }

    var uiColor: UIColor {
        let c = displayRGB
        return UIColor(red: c.r, green: c.g, blue: c.b, alpha: 1)
    }
}

extension Face {
    /// Nazwa położenia ściany przy skanowaniu (żółty u góry, zielony z przodu).
    var positionName: String {
        switch self {
        case .U: return "Góra"
        case .D: return "Dół"
        case .F: return "Przód"
        case .B: return "Tył"
        case .R: return "Prawa"
        case .L: return "Lewa"
        }
    }
}
