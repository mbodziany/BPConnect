import Foundation

/// Sześć kolorów standardowej kostki wraz z polskimi formami potrzebnymi w opisach.
public enum CubeColor: Int, CaseIterable, Hashable, Sendable, Codable {
    case white, yellow, red, orange, blue, green

    /// "biały" (rodzaj męski – środek, narożnik)
    public var name: String { ["biały", "żółty", "czerwony", "pomarańczowy", "niebieski", "zielony"][rawValue] }
    /// "biała" (rodzaj żeński – krawędź, ściana)
    public var feminine: String { ["biała", "żółta", "czerwona", "pomarańczowa", "niebieska", "zielona"][rawValue] }
    /// "białym" (narzędnik)
    public var instrumental: String { ["białym", "żółtym", "czerwonym", "pomarańczowym", "niebieskim", "zielonym"][rawValue] }
    /// "białego" (dopełniacz, rodzaj męski)
    public var genitive: String { ["białego", "żółtego", "czerwonego", "pomarańczowego", "niebieskiego", "zielonego"][rawValue] }
    /// "białej" (dopełniacz, rodzaj żeński)
    public var genitiveFeminine: String { ["białej", "żółtej", "czerwonej", "pomarańczowej", "niebieskiej", "zielonej"][rawValue] }
    /// "białych" (dopełniacz liczby mnogiej)
    public var genitivePlural: String { ["białych", "żółtych", "czerwonych", "pomarańczowych", "niebieskich", "zielonych"][rawValue] }
    /// "biało" – pierwszy człon przymiotnika złożonego
    public var prefix: String { ["biało", "żółto", "czerwono", "pomarańczowo", "niebiesko", "zielono"][rawValue] }

    /// Kolor do wyświetlania (sRGB 0...1).
    public var displayRGB: RGB {
        switch self {
        case .white: return RGB(0.96, 0.96, 0.96)
        case .yellow: return RGB(1.0, 0.85, 0.0)
        case .red: return RGB(0.80, 0.07, 0.12)
        case .orange: return RGB(1.0, 0.46, 0.0)
        case .blue: return RGB(0.0, 0.32, 0.82)
        case .green: return RGB(0.0, 0.62, 0.30)
        }
    }

    /// Typowy wygląd naklejki na zdjęciu – punkt odniesienia przy rozpoznawaniu.
    var referenceRGB: RGB {
        switch self {
        case .white: return RGB(0.85, 0.85, 0.85)
        case .yellow: return RGB(0.85, 0.80, 0.10)
        case .red: return RGB(0.70, 0.08, 0.10)
        case .orange: return RGB(0.95, 0.40, 0.08)
        case .blue: return RGB(0.05, 0.25, 0.65)
        case .green: return RGB(0.05, 0.60, 0.25)
        }
    }

    /// Klasyczny schemat, gdy trzymasz kostkę żółtym do góry i zielonym do siebie.
    public static let standardScheme: [Face: CubeColor] = [
        .U: .yellow, .D: .white, .F: .green, .B: .blue, .R: .orange, .L: .red
    ]
}

/// Nazwy elementów kostki w odmianie potrzebnej w opisach kroków.
public struct ColorNames: Sendable {
    public let colorOf: [Face: CubeColor]

    public init(_ colorOf: [Face: CubeColor]) { self.colorOf = colorOf }

    public func color(_ f: Face) -> CubeColor { colorOf[f]! }

    /// "biało-czerwona" (krawędź)
    public func edge(_ faces: [Face]) -> String {
        "\(color(faces[0]).prefix)-\(color(faces[1]).feminine)"
    }

    /// "biało-czerwono-zielony" (narożnik)
    public func corner(_ faces: [Face]) -> String {
        "\(color(faces[0]).prefix)-\(color(faces[1]).prefix)-\(color(faces[2]).name)"
    }

    /// "czerwonym" – do zwrotów „środek z … kolorem”
    public func instrumental(_ f: Face) -> String { color(f).instrumental }
    public func name(_ f: Face) -> String { color(f).name }
}
