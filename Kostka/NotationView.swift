import SwiftUI
import CubeCore

struct NotationView: View {
    private let rows: [(String, String)] = [
        ("R", "prawa ściana"), ("L", "lewa ściana"), ("U", "górna warstwa (up)"),
        ("D", "dolna warstwa (down)"), ("F", "przednia ściana (front)"), ("B", "tylna ściana (back)")
    ]

    var body: some View {
        List {
            Section {
                Text("Każda litera to obrót jednej ściany o ćwierć obrotu **zgodnie z ruchem wskazówek zegara – tak, jakbyś patrzył prosto na tę ściankę**.")
                Text("Apostrof (np. **R'**) oznacza obrót w przeciwną stronę, a dwójka (np. **U2**) – pół obrotu.")
            }
            Section("Litery") {
                ForEach(rows, id: \.0) { row in
                    HStack {
                        Text(row.0).font(.title3.monospaced().bold()).frame(width: 36)
                        Text(row.1)
                    }
                }
            }
            Section("Najczęstsze ruchy") {
                ForEach(["R", "R'", "L", "L'", "U", "U'", "D", "D'", "F", "F'"], id: \.self) { s in
                    let m = Move.parse(s)[0]
                    HStack(alignment: .top) {
                        Text(s).font(.body.monospaced().bold()).frame(width: 36, alignment: .leading)
                        Text(MoveText.describe(m))
                    }
                }
            }
            Section("Jak trzymać kostkę") {
                Text("Ruchy są zawsze opisane względem tego, jak trzymasz kostkę. Przy każdym kroku aplikacja pokazuje, który środek ma być u góry, a który zwrócony do Ciebie – w całym rozwiązaniu żółty środek jest u góry.")
                Text("Gdy krok każe zmienić stronę, obróć całą kostkę w dłoniach (bez przekręcania warstw), aż wskazany środek będzie patrzył na Ciebie.")
            }
            Section("Metoda") {
                ForEach(Stage.allCases, id: \.self) { stage in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(stage.rawValue). \(stage.title)").font(.headline)
                        Text(stage.goal(ColorNames(CubeColor.standardScheme))).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Jak czytać ruchy")
    }
}
