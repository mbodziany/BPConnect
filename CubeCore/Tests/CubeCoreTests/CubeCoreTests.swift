import XCTest
@testable import CubeCore

final class CubeCoreTests: XCTestCase {
    func testMoveOrder() {
        for f in Face.allCases {
            XCTAssertEqual(CubieCube.solved.applying(Array(repeating: Move(f), count: 4)), .solved)
        }
        let sexy = Move.parse("R U R' U'")
        XCTAssertEqual(CubieCube.solved.applying(Array(repeating: sexy, count: 6).flatMap { $0 }), .solved)
    }

    func testMoveDirections() {
        // Po R prawa kolumna U ma kolor F; po U górny rząd F ma kolor R.
        let r = CubieCube.solved.applying(Move(.R)).facelets
        XCTAssertEqual([r[2], r[5], r[8]], [.F, .F, .F])
        let u = CubieCube.solved.applying(Move(.U)).facelets
        XCTAssertEqual(Array(u[18...20]), [.R, .R, .R])
    }

    func testFaceletRoundTrip() {
        let c = CubieCube.solved.applying(Move.parse("R U F D L B R2 U' F2"))
        XCTAssertEqual(CubieCube(facelets: c.facelets), c)
    }

    func testRelativeNotation() {
        XCTAssertEqual(Solver.toAbsolute("R U F", front: .R).notation, "B U R")
        let m = Move.parse("R U F' L2 B D")
        for f in [Face.F, .R, .B, .L] {
            XCTAssertEqual(Solver.toAbsolute(Solver.toRelative(Solver.toAbsolute(m, front: f), front: f), front: f),
                           Solver.toAbsolute(m, front: f))
        }
    }

    func testSolvesRandomScrambles() {
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<200 {
            let scramble = (0..<25).map { _ in Move(Face.allCases.randomElement(using: &rng)!, Int.random(in: 1...3, using: &rng)) }
            let start = CubieCube.solved.applying(scramble)
            let solution = Solver.solve(start, colors: CubeColor.standardScheme)
            XCTAssertTrue(start.applying(solution.steps.flatMap(\.moves)).isSolved, "Nie ułożono: \(scramble.notation)")
        }
    }

    func testSolvedCube() {
        let solution = Solver.solve(.solved, colors: CubeColor.standardScheme)
        XCTAssertEqual(solution.moveCount, 0)
        XCTAssertEqual(solution.steps.count, Stage.allCases.count)
    }

    func testValidation() {
        var colors = CubieCube.solved.facelets.map { CubeColor.standardScheme[$0]! }
        if case .failure = CubeValidator.validate(colors: colors) { XCTFail("Ułożona kostka powinna być poprawna") }
        colors.swapAt(0, 9)
        if case .success = CubeValidator.validate(colors: colors) { XCTFail("Zamienione naklejki powinny być błędem") }
        // Przekręcony narożnik
        var twisted = CubieCube.solved
        twisted.co[0] = 1
        XCTAssertEqual(CubeValidator.validate(facelets: twisted.facelets).failureValue, .twistedCorner)
    }

    func testClassifierUsesCenters() {
        let cube = CubieCube.solved.applying(Move.parse("R U2 F' L D B2"))
        let scheme = CubeColor.standardScheme
        // Przyciemnione kolory jak na zdjęciu przy słabym świetle.
        let samples = cube.facelets.map { f -> RGB in
            let c = scheme[f]!.displayRGB
            return RGB(c.r * 0.7, c.g * 0.7, c.b * 0.7)
        }
        XCTAssertEqual(ColorClassifier.classify(samples), cube.facelets)
        var centers: [Face: RGB] = [:]
        for f in Face.allCases { centers[f] = samples[f.rawValue * 9 + 4] }
        XCTAssertEqual(ColorClassifier.assignCenters(centers), scheme)
    }
}

private extension Result {
    var failureValue: Failure? {
        if case let .failure(e) = self { return e }
        return nil
    }
}
