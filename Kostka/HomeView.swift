import SwiftUI
import CubeCore

struct HomeView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        NavigationStack(path: $model.path) {
            ScrollView {
                VStack(spacing: 20) {
                    MiniCubeLogo()
                        .frame(width: 110, height: 110)
                        .padding(.top, 24)
                    Text("Sfotografuj wszystkie 6 ścian kostki, a aplikacja krok po kroku pokaże Ci, jak ją ułożyć – i wyjaśni, dlaczego każdy ruch działa.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    VStack(spacing: 12) {
                        HomeButton(title: "Zeskanuj kostkę", subtitle: "6 zdjęć aparatem", icon: "camera.fill", prominent: true) {
                            model.path.append(.scan)
                        }
                        HomeButton(title: "Wpisz kolory ręcznie", subtitle: "Pomaluj siatkę kostki", icon: "square.grid.3x3.fill") {
                            model.resetToSolved()
                            model.path.append(.editor)
                        }
                        HomeButton(title: "Wypróbuj na przykładzie", subtitle: "Losowo pomieszana kostka", icon: "shuffle") {
                            model.loadScramble()
                            model.path.append(.editor)
                        }
                        HomeButton(title: "Jak czytać ruchy?", subtitle: "R, U', F2… – krótki słowniczek", icon: "book.fill") {
                            model.path.append(.notation)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 24)
            }
            .navigationTitle("Kostka")
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .scan: ScanView()
                case .editor: EditorView()
                case .solution: SolutionView()
                case .notation: NotationView()
                }
            }
        }
    }
}

private struct HomeButton: View {
    let title: String
    let subtitle: String
    let icon: String
    var prominent = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title2)
                    .frame(width: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    Text(subtitle).font(.subheadline).opacity(0.8)
                }
                Spacer()
                Image(systemName: "chevron.right").opacity(0.6)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .foregroundStyle(prominent ? Color.white : Color.primary)
            .background(prominent ? Color.accentColor : Color(.secondarySystemBackground),
                        in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

struct MiniCubeLogo: View {
    private let grid: [CubeColor] = [.yellow, .green, .orange, .blue, .yellow, .red, .white, .green, .yellow]

    var body: some View {
        GeometryReader { geo in
            let cell = geo.size.width / 3
            ZStack {
                RoundedRectangle(cornerRadius: cell * 0.35).fill(Color.black)
                VStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { r in
                        HStack(spacing: 0) {
                            ForEach(0..<3, id: \.self) { c in
                                RoundedRectangle(cornerRadius: cell * 0.18)
                                    .fill(grid[r * 3 + c].color)
                                    .padding(cell * 0.07)
                            }
                        }
                    }
                }
                .padding(cell * 0.06)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
