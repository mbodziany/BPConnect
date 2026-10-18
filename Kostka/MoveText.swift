import CubeCore

/// Opisy ruchów po polsku – zawsze względem tego, jak trzymasz kostkę.
enum MoveText {
    static func describe(_ m: Move) -> String {
        let half = m.turns == 2
        switch (m.face, m.turns) {
        case (.R, 1): return "Prawa ściana do góry (od siebie)"
        case (.R, 3): return "Prawa ściana w dół (do siebie)"
        case (.L, 1): return "Lewa ściana w dół (do siebie)"
        case (.L, 3): return "Lewa ściana do góry (od siebie)"
        case (.U, 1): return "Górna warstwa w lewo"
        case (.U, 3): return "Górna warstwa w prawo"
        case (.D, 1): return "Dolna warstwa w prawo"
        case (.D, 3): return "Dolna warstwa w lewo"
        case (.F, 1): return "Przednia ściana zgodnie z ruchem wskazówek zegara"
        case (.F, 3): return "Przednia ściana przeciwnie do ruchu wskazówek zegara"
        case (.B, 1): return "Tylna ściana – patrząc od przodu: przeciwnie do wskazówek zegara (góra jedzie w lewo)"
        case (.B, 3): return "Tylna ściana – patrząc od przodu: zgodnie ze wskazówkami zegara (góra jedzie w prawo)"
        default:
            let names: [Face: String] = [.R: "Prawa ściana", .L: "Lewa ściana", .U: "Górna warstwa",
                                         .D: "Dolna warstwa", .F: "Przednia ściana", .B: "Tylna ściana"]
            return half ? "\(names[m.face]!) o pół obrotu (180°, kierunek dowolny)" : m.description
        }
    }

    static func faceName(_ f: Face) -> String {
        switch f {
        case .R: return "prawa"
        case .L: return "lewa"
        case .U: return "góra"
        case .D: return "dół"
        case .F: return "przód"
        case .B: return "tył"
        }
    }
}
