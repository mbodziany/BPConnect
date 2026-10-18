import SwiftUI
import CubeCore

/// Siatka kostki do sprawdzenia i poprawienia rozpoznanych kolorów.
struct EditorView: View {
    @Environment(AppModel.self) private var model
    @State private var brush: CubeColor = .white

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Sprawdź, czy kolory zgadzają się z kostką. Żeby poprawić pole, wybierz kolor na dole i dotknij pola.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                CubeNet(colors: model.colors) { index in
                    model.colors[index] = brush
                    model.validationError = nil
                }

                palette

                if let error = model.validationError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    Task { await model.solve() }
                } label: {
                    HStack {
                        if model.isSolving { ProgressView().tint(.white) }
                        Text(model.isSolving ? "Liczę…" : "Pokaż rozwiązanie")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isSolving)

                HStack {
                    Button("Ułożona kostka") { model.resetToSolved() }
                    Spacer()
                    Button("Losowe pomieszanie") { model.loadScramble() }
                }
                .font(.subheadline)
            }
            .padding()
        }
        .navigationTitle("Sprawdź kolory")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var palette: some View {
        HStack(spacing: 10) {
            ForEach(CubeColor.allCases, id: \.self) { c in
                let count = model.colors.filter { $0 == c }.count
                Button {
                    brush = c
                } label: {
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(c.color)
                            .frame(height: 40)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(brush == c ? Color.accentColor : Color.secondary.opacity(0.4),
                                            lineWidth: brush == c ? 3 : 1)
                            )
                        Text("\(count)/9")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(count == 9 ? Color.secondary : Color.red)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(c.name)
            }
        }
    }
}

/// Rozłożona siatka:
///       U
///    L  F  R  B
///       D
struct CubeNet: View {
    let colors: [CubeColor]
    var onTap: ((Int) -> Void)?

    private struct NetFace: Identifiable {
        let face: Face
        let col: Int
        let row: Int
        var id: Int { face.rawValue }
    }

    private let layout: [NetFace] = [
        NetFace(face: .U, col: 1, row: 0), NetFace(face: .L, col: 0, row: 1), NetFace(face: .F, col: 1, row: 1),
        NetFace(face: .R, col: 2, row: 1), NetFace(face: .B, col: 3, row: 1), NetFace(face: .D, col: 1, row: 2)
    ]

    var body: some View {
        GeometryReader { geo in
            let faceSize = geo.size.width / 4
            let cell = (faceSize - 8) / 3
            ZStack(alignment: .topLeading) {
                ForEach(layout) { item in
                    faceGrid(item.face, cell: cell)
                    .overlay(alignment: .top) {
                        Text(item.face.positionName)
                            .font(.system(size: 9, weight: .semibold))
                            .padding(.horizontal, 3)
                            .background(.thinMaterial, in: Capsule())
                            .offset(y: -7)
                    }
                    .offset(x: CGFloat(item.col) * faceSize + 2, y: CGFloat(item.row) * faceSize + 2)
                }
            }
        }
        .aspectRatio(4.0 / 3.0, contentMode: .fit)
        .padding(.top, 6)
    }

    private func faceGrid(_ face: Face, cell: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { r in
                HStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { c in
                        let index = face.rawValue * 9 + r * 3 + c
                        RoundedRectangle(cornerRadius: cell * 0.15)
                            .fill(colors[index].color)
                            .overlay(
                                RoundedRectangle(cornerRadius: cell * 0.15)
                                    .stroke(Color.black.opacity(0.35), lineWidth: 0.5)
                            )
                            .padding(cell * 0.05)
                            .frame(width: cell, height: cell)
                            .contentShape(Rectangle())
                            .onTapGesture { onTap?(index) }
                    }
                }
            }
        }
        .padding(2)
        .background(Color.black, in: RoundedRectangle(cornerRadius: cell * 0.2))
    }
}
