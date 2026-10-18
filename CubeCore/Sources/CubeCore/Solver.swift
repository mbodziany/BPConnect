import Foundation

/// Etapy metody warstwowej (dla początkujących). Biały krzyż powstaje na dole,
/// a kostkę przez cały czas trzymasz żółtym (górnym) środkiem do góry.
public enum Stage: Int, CaseIterable, Sendable {
    case cross = 1
    case firstLayerCorners
    case middleLayer
    case yellowCross
    case yellowEdges
    case yellowCornersPosition
    case yellowCornersOrientation

    public var title: String {
        switch self {
        case .cross: return "Krzyż na dole"
        case .firstLayerCorners: return "Narożniki pierwszej warstwy"
        case .middleLayer: return "Środkowa warstwa"
        case .yellowCross: return "Krzyż na górze"
        case .yellowEdges: return "Krawędzie górnej warstwy"
        case .yellowCornersPosition: return "Narożniki na swoje miejsca"
        case .yellowCornersOrientation: return "Obrót narożników"
        }
    }

    public func goal(_ n: ColorNames) -> String {
        let bottom = n.color(.D), top = n.color(.U)
        switch self {
        case .cross:
            return "Ułóż \(bottom.feminine) krzyż na dolnej ścianie. Każda krawędź krzyża musi drugim kolorem pasować do środka ściany bocznej – sam krzyż na dole to za mało."
        case .firstLayerCorners:
            return "Wstaw cztery narożniki z \(bottom.instrumental) kolorem w rogi dolnej warstwy. Po tym etapie cała pierwsza warstwa jest gotowa."
        case .middleLayer:
            return "Wstaw cztery krawędzie bez \(top.genitive) koloru w środkową warstwę. Po tym etapie dwie warstwy są ułożone."
        case .yellowCross:
            return "Ułóż \(top.feminine) krzyż na górnej ścianie (na razie liczy się tylko góra, nie boki)."
        case .yellowEdges:
            return "Przestaw krawędzie górnego krzyża, żeby ich boczne kolory pasowały do środków."
        case .yellowCornersPosition:
            return "Przestaw górne narożniki na właściwe miejsca – na razie mogą być obrócone."
        case .yellowCornersOrientation:
            return "Obróć górne narożniki \(top.instrumental) kolorem do góry. To ostatni etap!"
        }
    }
}

public struct SolutionStep: Identifiable, Sendable {
    public let id: Int
    public let stage: Stage
    public let title: String
    /// Co robimy i dlaczego.
    public let explanation: String
    /// Środek, który ma być zwrócony do Ciebie (góra to zawsze ściana U).
    public let front: Face
    /// Ruchy w układzie bezwzględnym (do animacji).
    public let moves: [Move]
    /// Zapis ruchów względem tego, jak trzymasz kostkę, z grupowaniem powtórzeń, np. "U' (R U R' U') ×3".
    public let notation: String

    public var relativeMoves: [Move] { Solver.toRelative(moves, front: front) }
}

public struct Solution: Sendable {
    public let start: CubieCube
    public let steps: [SolutionStep]

    public var moveCount: Int { steps.reduce(0) { $0 + $1.moves.count } }
}

public struct Solver {
    static let holds: [Face] = [.F, .R, .B, .L]

    let names: ColorNames
    private var cube: CubieCube
    private var steps: [SolutionStep] = []

    public static func solve(_ cube: CubieCube, colors: [Face: CubeColor]) -> Solution {
        var s = Solver(names: ColorNames(colors), cube: cube)
        s.run()
        return Solution(start: cube, steps: s.steps)
    }

    init(names: ColorNames, cube: CubieCube) {
        self.names = names
        self.cube = cube
    }

    // MARK: - Układ względny

    static func right(of f: Face) -> Face { holds[(holds.firstIndex(of: f)! + 1) % 4] }
    static func left(of f: Face) -> Face { holds[(holds.firstIndex(of: f)! + 3) % 4] }
    static func back(of f: Face) -> Face { holds[(holds.firstIndex(of: f)! + 2) % 4] }

    /// Ściana względna (gdy `front` jest zwrócona do Ciebie) -> ściana bezwzględna.
    static func absolute(_ relative: Face, front: Face) -> Face {
        switch relative {
        case .U, .D: return relative
        case .F: return front
        case .R: return right(of: front)
        case .B: return back(of: front)
        case .L: return left(of: front)
        }
    }

    public static func toAbsolute(_ moves: [Move], front: Face) -> [Move] {
        moves.map { Move(absolute($0.face, front: front), $0.turns) }
    }

    public static func toAbsolute(_ alg: String, front: Face) -> [Move] {
        toAbsolute(Move.parse(alg), front: front)
    }

    public static func toRelative(_ moves: [Move], front: Face) -> [Move] {
        moves.map { m in
            let rel = Face.allCases.first { absolute($0, front: front) == m.face }!
            return Move(rel, m.turns)
        }
    }

    // MARK: - Pomocnicze

    private mutating func emit(_ stage: Stage, _ title: String, _ explanation: String,
                               front: Face, moves: [Move], notation: String? = nil) {
        steps.append(SolutionStep(id: steps.count, stage: stage, title: title, explanation: explanation,
                                  front: front, moves: moves,
                                  notation: notation ?? Solver.toRelative(moves, front: front).notation))
        cube = cube.applying(moves)
    }

    private func times(_ n: Int) -> String { n == 1 ? "1 raz" : "\(n) razy" }

    private func uTurn(_ k: Int) -> [Move] { k % 4 == 0 ? [] : [Move(.U, k)] }

    /// Opis miejsca, w którym aktualnie jest krawędź.
    private func edgeLocation(_ piece: Int) -> String {
        let pos = cube.edgePosition(of: piece)
        let faces = Pieces.edgeFaces[pos]
        if faces.contains(.U) {
            let side = faces.first { $0 != .U }!
            return "w górnej warstwie, nad \(names.instrumental(side)) środkiem"
        }
        if faces.contains(.D) {
            let side = faces.first { $0 != .D }!
            if pos == piece { return "na swoim miejscu na dole, ale odwrócona" }
            return "w dolnej warstwie, pod \(names.instrumental(side)) środkiem"
        }
        return "w środkowej warstwie, między \(names.instrumental(faces[0])) a \(names.instrumental(faces[1])) środkiem"
    }

    private func cornerLocation(_ piece: Int) -> String {
        let pos = cube.cornerPosition(of: piece)
        let sides = Pieces.cornerFaces[pos].filter { $0 != .U && $0 != .D }
        let pair = "\(names.instrumental(sides[0])) i \(names.instrumental(sides[1])) środkiem"
        if pos < 4 { return "w górnej warstwie, w rogu nad \(pair)" }
        if pos == piece { return "na swoim miejscu, ale obrócony" }
        return "w dolnej warstwie, w rogu pod \(pair)"
    }

    /// BFS po stanach wybranych elementów (pozycja + orientacja). Zwraca indeksy makr prowadzących do celu.
    static func searchPieces(_ start: CubieCube, corners: [Int], edges: [Int],
                             macros: [[Move]], maxDepth: Int) -> [Int]? {
        let tables: [(corner: [(Int, Int)], edge: [(Int, Int)])] = macros.map { ms in
            let m = CubieCube.solved.applying(ms)
            var cn = Array(repeating: (0, 0), count: 8)
            var en = Array(repeating: (0, 0), count: 12)
            for i in 0..<8 { cn[m.cp[i]] = (i, m.co[i]) }
            for i in 0..<12 { en[m.ep[i]] = (i, m.eo[i]) }
            return (cn, en)
        }
        let nc = corners.count, n = corners.count + edges.count

        func encode(_ s: [Int]) -> Int { s.reduce(0) { $0 * 36 + $1 } }
        func decode(_ key: Int) -> [Int] {
            var k = key, s = Array(repeating: 0, count: n)
            for i in stride(from: n - 1, through: 0, by: -1) { s[i] = k % 36; k /= 36 }
            return s
        }

        var startState: [Int] = []
        for j in corners { let p = start.cornerPosition(of: j); startState.append(p * 3 + start.co[p]) }
        for j in edges { let p = start.edgePosition(of: j); startState.append(p * 3 + start.eo[p]) }
        let goal = encode(corners.map { $0 * 3 } + edges.map { $0 * 3 })
        let startKey = encode(startState)
        if startKey == goal { return [] }

        var parent: [Int: (Int, Int)] = [startKey: (-1, -1)]
        var frontier = [startKey]
        for _ in 0..<maxDepth {
            var next: [Int] = []
            for key in frontier {
                let s = decode(key)
                for (mi, t) in tables.enumerated() {
                    var ns = s
                    for idx in 0..<n {
                        let pos = s[idx] / 3, ori = s[idx] % 3
                        if idx < nc {
                            let (np, d) = t.corner[pos]
                            ns[idx] = np * 3 + (ori + d) % 3
                        } else {
                            let (np, d) = t.edge[pos]
                            ns[idx] = np * 3 + (ori + d) % 2
                        }
                    }
                    let nk = encode(ns)
                    if parent[nk] != nil { continue }
                    parent[nk] = (key, mi)
                    if nk == goal {
                        var path: [Int] = []
                        var k = nk
                        while let entry = parent[k], entry.1 >= 0 { path.append(entry.1); k = entry.0 }
                        return path.reversed()
                    }
                    next.append(nk)
                }
            }
            frontier = next
        }
        return nil
    }

    // MARK: - Etapy

    private mutating func run() {
        let stageCounts = { (steps: [SolutionStep], stage: Stage) in steps.filter { $0.stage == stage }.count }
        let stages: [(Stage, (inout Solver) -> Void)] = [
            (.cross, { $0.solveCross() }),
            (.firstLayerCorners, { $0.solveFirstCorners() }),
            (.middleLayer, { $0.solveMiddle() }),
            (.yellowCross, { $0.solveYellowCross() }),
            (.yellowEdges, { $0.solveYellowEdges() }),
            (.yellowCornersPosition, { $0.solveCornerPositions() }),
            (.yellowCornersOrientation, { $0.solveCornerOrientation() })
        ]
        for (stage, solve) in stages {
            solve(&self)
            if stageCounts(steps, stage) == 0 {
                emit(stage, "Już gotowe", "Ten etap jest już ułożony – możesz przejść dalej.", front: .F, moves: [])
            }
        }
    }

    private var crossEdges: [Int] { Solver.holds.map { Pieces.edge(between: [.D, $0]) } }
    private var bottomSlots: [Int] { Solver.holds.map { Pieces.corner(between: [.D, $0, Solver.right(of: $0)]) } }
    private var middleSlots: [Int] { Solver.holds.map { Pieces.edge(between: [$0, Solver.right(of: $0)]) } }
    private var topEdges: [Int] { Solver.holds.map { Pieces.edge(between: [.U, $0]) } }
    private var topCorners: [Int] { Solver.holds.map { Pieces.corner(between: [.U, $0, Solver.right(of: $0)]) } }

    private mutating func solveCross() {
        let all18 = Face.allCases.flatMap { f in (1...3).map { [Move(f, $0)] } }
        var done: [Int] = []
        while done.count < 4 {
            var best: (edge: Int, path: [Int])?
            for e in crossEdges where !done.contains(e) {
                guard let p = Solver.searchPieces(cube, corners: [], edges: done + [e], macros: all18, maxDepth: 10) else { continue }
                if best == nil || p.count < best!.path.count { best = (e, p) }
            }
            let (e, path) = best!
            let side = Pieces.edgeFaces[e][1]
            if !path.isEmpty {
                let bottom = names.color(.D)
                var text = "Ta krawędź jest teraz \(edgeLocation(e)). Jej miejsce jest na dole z przodu: \(bottom.feminine) naklejka w dół, a druga (\(names.color(side).feminine)) z przodu, przy środku w tym samym kolorze."
                if !done.isEmpty { text += " Ruchy dobrano tak, żeby nie zepsuć ułożonych już krawędzi krzyża." }
                emit(.cross, "Krawędź \(names.edge(Pieces.edgeFaces[e]))", text,
                     front: side, moves: path.map { all18[$0][0] })
            }
            done.append(e)
        }
    }

    private mutating func solveFirstCorners() {
        let slots = bottomSlots
        let cross = crossEdges
        var done: [Int] = []
        while done.count < 4 {
            var best: (corner: Int, length: Int, plan: [CornerPart])?
            for t in slots where !done.contains(t) {
                var plan: [CornerPart] = []
                var c = cube
                let pos = c.cornerPosition(of: t)
                if pos >= 4 && pos != t {
                    let f = Solver.holds[slots.firstIndex(of: pos)!]
                    let m = Solver.toAbsolute("R U R' U'", front: f)
                    plan.append((0, f, m, 1, 0))
                    c = c.applying(m)
                }
                if !c.cornerSolved(t) {
                    let f = Solver.holds[slots.firstIndex(of: t)!]
                    var moves: [Move] = []
                    var k = 0
                    if c.cornerPosition(of: t) != t {
                        let above = Pieces.corner(between: [.U, f, Solver.right(of: f)])
                        while c.cornerPosition(of: t) != above { c = c.applying(Move(.U)); k += 1 }
                        moves += uTurn(k)
                    }
                    let sexy = Solver.toAbsolute("R U R' U'", front: f)
                    var n = 0
                    while !c.cornerSolved(t) && n < 6 { c = c.applying(sexy); n += 1; moves += sexy }
                    plan.append((1, f, moves, n, k))
                }
                let ok = c.cornerSolved(t) && done.allSatisfy { c.cornerSolved($0) } && cross.allSatisfy { c.edgeSolved($0) }
                guard ok else { continue }
                let length = plan.reduce(0) { $0 + $1.moves.count }
                if best == nil || length < best!.length { best = (t, length, plan) }
            }
            let (t, _, plan) = best!
            let name = names.corner(Pieces.cornerFaces[t])
            let bottom = names.color(.D)
            for part in plan {
                if part.kind == 0 {
                    emit(.firstLayerCorners, "Wyjmij narożnik \(name)",
                         "Narożnik jest \(cornerLocation(t)), ale to nie jego miejsce. Trzymaj kostkę tak, żeby był na dole z przodu po prawej – jedno R U R' U' wyrzuci go do górnej warstwy, a krzyż zostanie nietknięty.",
                         front: part.front, moves: part.moves, notation: "R U R' U'")
                } else {
                    let right = Solver.right(of: part.front)
                    var text: String
                    let prefix = Solver.toRelative(uTurn(part.k), front: part.front).notation
                    if part.k > 0 {
                        text = "Narożnik jest \(cornerLocation(t)). Najpierw obróć górną warstwę (\(prefix)), żeby stanął dokładnie nad swoim miejscem – u góry z przodu po prawej, nad rogiem między \(names.instrumental(part.front)) i \(names.instrumental(right)) środkiem. "
                    } else if cube.cornerPosition(of: t) == t {
                        text = "Narożnik jest na swoim miejscu, ale obrócony. "
                    } else {
                        text = "Narożnik jest już nad swoim miejscem – u góry z przodu po prawej. "
                    }
                    text += "Teraz powtarzaj R U R' U' (tu: \(times(part.n))), aż narożnik wskoczy na dół \(bottom.instrumental) kolorem w dół. Dlaczego to działa: każde powtórzenie obraca ten narożnik, a po 6 powtórzeniach kostka wraca do stanu wyjścia – dlatego reszta dolnej warstwy się nie psuje."
                    let reps = part.n == 1 ? "R U R' U'" : "(R U R' U') ×\(part.n)"
                    emit(.firstLayerCorners, "Wstaw narożnik \(name)", text, front: part.front, moves: part.moves,
                         notation: prefix.isEmpty ? reps : "\(prefix)  \(reps)")
                }
            }
            done.append(t)
        }
    }

    private typealias CornerPart = (kind: Int, front: Face, moves: [Move], n: Int, k: Int)
    private typealias EdgePart = (kind: Int, front: Face, moves: [Move], k: Int, right: Bool)

    private static let rightInsert = "U R U' R' U' F' U F"
    private static let leftInsert = "U' L' U L U F U' F'"

    private mutating func solveMiddle() {
        let slots = middleSlots
        let firstLayerCorners = bottomSlots
        let cross = crossEdges
        var done: [Int] = []
        while done.count < 4 {
            var best: (edge: Int, length: Int, plan: [EdgePart])?
            for t in slots where !done.contains(t) {
                var plan: [EdgePart] = []
                var c = cube
                let pos = c.edgePosition(of: t)
                if pos >= 8 && !c.edgeSolved(t) {
                    let f = Solver.holds[slots.firstIndex(of: pos)!]
                    let m = Solver.toAbsolute(Solver.rightInsert, front: f)
                    plan.append((0, f, m, 0, true))
                    c = c.applying(m)
                }
                if !c.edgeSolved(t) {
                    var k = 0
                    var side = Face.F, topColor = Face.U
                    while k < 4 {
                        let p = c.edgePosition(of: t)
                        let fl = c.facelets
                        side = Pieces.edgeFaces[p][1]
                        topColor = fl[Pieces.edgeFacelets[p][0]]
                        if fl[Pieces.edgeFacelets[p][1]] == side { break }
                        c = c.applying(Move(.U)); k += 1
                    }
                    let isRight = topColor == Solver.right(of: side)
                    let m = Solver.toAbsolute(isRight ? Solver.rightInsert : Solver.leftInsert, front: side)
                    c = c.applying(m)
                    plan.append((1, side, uTurn(k) + m, k, isRight))
                }
                let ok = c.edgeSolved(t) && done.allSatisfy { c.edgeSolved($0) }
                    && firstLayerCorners.allSatisfy { c.cornerSolved($0) } && cross.allSatisfy { c.edgeSolved($0) }
                guard ok else { continue }
                let length = plan.reduce(0) { $0 + $1.moves.count }
                if best == nil || length < best!.length { best = (t, length, plan) }
            }
            let (t, _, plan) = best!
            let name = names.edge(Pieces.edgeFaces[t])
            for part in plan {
                if part.kind == 0 {
                    emit(.middleLayer, "Wyjmij krawędź \(name)",
                         "Krawędź jest \(edgeLocation(t)) – w złym miejscu albo odwrócona. Trzymaj kostkę tak, żeby była w środkowej warstwie z przodu po prawej, i wykonaj algorytm wstawiania w prawo: dowolna krawędź z góry zajmie jej miejsce, a ona wyskoczy do górnej warstwy.",
                         front: part.front, moves: part.moves, notation: Solver.rightInsert)
                } else {
                    let prefix = Solver.toRelative(uTurn(part.k), front: part.front).notation
                    let pieceFaces = Pieces.edgeFaces[t]
                    let topColor = pieceFaces.first { $0 != part.front }!
                    var text = part.k > 0
                        ? "Obróć górną warstwę (\(prefix)) tak, żeby przednia naklejka krawędzi stała nad \(names.instrumental(part.front)) środkiem – razem ze środkiem tworzy pionowy pasek (odwrócone T). "
                        : "Przednia naklejka krawędzi już stoi nad \(names.instrumental(part.front)) środkiem – tworzy z nim pionowy pasek (odwrócone T). "
                    let dir = part.right ? "prawej" : "lewej"
                    let dir2 = part.right ? "prawo" : "lewo"
                    text += "Górna naklejka jest \(names.color(topColor).feminine), a \(names.instrumental(topColor)) środek jest po \(dir), więc krawędź wędruje w \(dir2). Pierwsza połowa algorytmu odsuwa miejsce docelowe i wyjmuje z niego narożnik, druga wkłada krawędź razem z narożnikiem z powrotem – pierwsza warstwa zostaje nietknięta."
                    let alg = part.right ? Solver.rightInsert : Solver.leftInsert
                    emit(.middleLayer, "Wstaw krawędź \(name) w \(dir2)", text, front: part.front, moves: part.moves,
                         notation: prefix.isEmpty ? alg : "\(prefix)  \(alg)")
                }
            }
            done.append(t)
        }
    }

    private mutating func solveYellowCross() {
        let top = names.color(.U)
        let alg = "F R U R' U' F'"
        let why = "Algorytm \(alg) odwraca krawędzie górnej warstwy, nie psując dwóch dolnych warstw."
        for _ in 0..<4 {
            let up = topEdges.map { cube.eo[$0] == 0 }   // F R B L
            let count = up.filter { $0 }.count
            if count == 4 { break }
            if count == 0 {
                emit(.yellowCross, "Kropka → L",
                     "Na górze nie ma żadnej \(top.genitiveFeminine) krawędzi, tylko środek (kropka). Wykonaj algorytm raz – pojawi się kształt L albo linia. \(why)",
                     front: .F, moves: Solver.toAbsolute(alg, front: .F))
                continue
            }
            for (i, f) in Solver.holds.enumerated() {
                let rf = up[i], rr = up[(i + 1) % 4], rb = up[(i + 2) % 4], rl = up[(i + 3) % 4]
                if rb && rl && !rf && !rr {
                    emit(.yellowCross, "Kształt L → krzyż",
                         "Na górze jest \(top.name) kształt L. Trzymaj kostkę tak, żeby L było z tyłu i z lewej (jak wskazówki zegara na 9 i 12), i wykonaj algorytm – powstanie krzyż. \(why)",
                         front: f, moves: Solver.toAbsolute(alg, front: f))
                    break
                }
                if rl && rr && !rf && !rb {
                    emit(.yellowCross, "Linia → krzyż",
                         "Na górze jest \(top.feminine) linia. Trzymaj ją poziomo (od lewej do prawej) i wykonaj algorytm – powstanie krzyż. \(why)",
                         front: f, moves: Solver.toAbsolute(alg, front: f))
                    break
                }
            }
        }
    }

    private mutating func solveYellowEdges() {
        let sune = "R U R' U R U2 R'"
        let macros: [[Move]] = [[Move(.U, 1)], [Move(.U, 3)], [Move(.U, 2)]]
            + Solver.holds.map { Solver.toAbsolute(sune, front: $0) }
        // Algorytm i obroty U nie ruszają dwóch dolnych warstw, więc wystarczy śledzić górne krawędzie.
        let keep = topEdges
        guard let path = Solver.searchPieces(cube, corners: [], edges: keep, macros: macros, maxDepth: 6) else { return }
        let top = names.color(.U)
        var pendingU = 0
        for mi in path {
            if mi < 3 { pendingU += [1, 3, 2][mi]; continue }
            let f = Solver.holds[mi - 3]
            let prefix = uTurn(pendingU)
            let prefixText = Solver.toRelative(prefix, front: f).notation
            var text = "Teraz boczne kolory \(top.genitivePlural) krawędzi mają pasować do środków. "
            if !prefix.isEmpty { text += "Najpierw obróć górę (\(prefixText)). " }
            text += "Algorytm \(sune) zostawia krawędź z przodu na miejscu, a pozostałe trzy przesuwa w kółko. Nie psuje dwóch dolnych warstw ani krzyża na górze (narożniki mogą się poprzestawiać – zajmiemy się nimi później)."
            emit(.yellowEdges, "Przestaw krawędzie", text, front: f, moves: prefix + macros[mi],
                 notation: prefixText.isEmpty ? sune : "\(prefixText)  \(sune)")
            pendingU = 0
        }
        if pendingU % 4 != 0 {
            emit(.yellowEdges, "Dopasuj krawędzie do środków",
                 "Obróć górę, żeby boczne kolory wszystkich krawędzi krzyża pasowały do środków.",
                 front: .F, moves: uTurn(pendingU))
        }
    }

    private mutating func solveCornerPositions() {
        let niklas = "U R U' L' U R' U' L"
        let macros = Solver.holds.map { Solver.toAbsolute(niklas, front: $0) }
        let corners = topCorners, bottom = bottomSlots, edges = crossEdges + middleSlots + topEdges
        func isGoal(_ c: CubieCube) -> Bool {
            corners.allSatisfy { c.cp[$0] == $0 } && bottom.allSatisfy { c.cornerSolved($0) } && edges.allSatisfy { c.edgeSolved($0) }
        }
        var queue: [(CubieCube, [Int])] = [(cube, [])]
        var seen: Set<CubieCube> = [cube]
        var result: [Int]?
        var head = 0
        while head < queue.count {
            let (c, path) = queue[head]; head += 1
            if isGoal(c) { result = path; break }
            if path.count >= 3 { continue }
            for (mi, m) in macros.enumerated() {
                let n = c.applying(m)
                if seen.insert(n).inserted { queue.append((n, path + [mi])) }
            }
        }
        for mi in result ?? [] {
            let f = Solver.holds[mi]
            let frontRight = Pieces.corner(between: [.U, f, Solver.right(of: f)])
            var text: String
            if cube.cp[frontRight] == frontRight {
                text = "Narożnik u góry z przodu po prawej jest już na swoim miejscu – jego kolory pasują do trzech sąsiednich środków (może być obrócony, to nic). Trzymaj go tam. "
            } else {
                text = "Żaden narożnik nie jest jeszcze na swoim miejscu. Wykonaj algorytm raz – potem przynajmniej jeden będzie na miejscu. "
            }
            text += "Algorytm \(niklas) przestawia w kółko trzy narożniki – wszystkie poza przednim prawym – i nie rusza niczego innego."
            emit(.yellowCornersPosition, "Przestaw narożniki", text, front: f, moves: macros[mi], notation: niklas)
        }
    }

    private mutating func solveCornerOrientation() {
        let corners = topCorners
        let top = names.color(.U)
        func allOriented(_ c: CubieCube) -> Bool { corners.allSatisfy { c.co[$0] == 0 } }
        guard !allOriented(cube) else { return finalAlign() }
        let front = Solver.holds.first { cube.co[Pieces.corner(between: [.U, $0, Solver.right(of: $0)])] != 0 }!
        let frontRight = Pieces.corner(between: [.U, front, Solver.right(of: front)])
        let twist = Solver.toAbsolute("R' D' R D R' D' R D", front: front)

        // Symulacja: (liczba obrotów U przed, liczba par R' D' R D)
        var plan: [(u: Int, pairs: Int)] = []
        var c = cube
        var pendingU = 0
        for _ in 0..<4 {
            if allOriented(c) { break }
            if c.co[frontRight] != 0 {
                var pairs = 0
                while c.co[frontRight] != 0 && pairs < 3 { c = c.applying(twist); pairs += 1 }
                plan.append((pendingU, pairs))
                pendingU = 0
            }
            if !allOriented(c) { c = c.applying(Move(.U)); pendingU += 1 }
        }
        for (i, p) in plan.enumerated() {
            let prefix = uTurn(p.u)
            var moves = prefix
            for _ in 0..<p.pairs { moves += twist }
            var text = ""
            if !prefix.isEmpty {
                text += "Obróć tylko górną warstwę (\(prefix.notation)), żeby kolejny narożnik bez \(top.genitive) koloru na górze trafił na przód-prawo. Całej kostki nie obracaj! "
            } else {
                text += "Narożnik u góry z przodu po prawej nie ma \(top.genitive) koloru na górze. "
            }
            text += "Powtarzaj R' D' R D, aż \(top.name) kolor będzie na górze – tu \(times(p.pairs * 2))."
            if i == 0 {
                text += " Uwaga: dolne warstwy się teraz rozsypią – to normalne! Wrócą na miejsce, gdy obrócisz wszystkie narożniki. Przez cały ten etap trzymaj kostkę tak samo, obracaj tylko górną warstwę."
            } else {
                text += " Dolne warstwy nadal wyglądają na pomieszane – tak ma być."
            }
            let reps = "(R' D' R D) ×\(p.pairs * 2)"
            emit(.yellowCornersOrientation, "Obróć narożnik", text, front: front, moves: moves,
                 notation: prefix.isEmpty ? reps : "\(prefix.notation)  \(reps)")
        }
        finalAlign(front: front)
    }

    private mutating func finalAlign(front: Face = .F) {
        var k = 0
        var c = cube
        while !c.isSolved && k < 4 { c = c.applying(Move(.U)); k += 1 }
        guard k % 4 != 0 else { return }
        emit(.yellowCornersOrientation, "Ostatni ruch",
             "Wszystkie narożniki są obrócone – obróć jeszcze górną warstwę (\(uTurn(k).notation)), żeby pasowała do reszty. Kostka ułożona!",
             front: front, moves: uTurn(k))
    }
}
