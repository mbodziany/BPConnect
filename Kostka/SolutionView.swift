import SwiftUI
import CubeCore

struct SolutionView: View {
    @Environment(AppModel.self) private var model
    @State private var scene = CubeSceneController()
    @State private var stepIndex = 0
    /// Ile ruchów bieżącego kroku zostało już wykonanych.
    @State private var moveIndex = 0
    @State private var isAnimating = false
    @State private var isPlaying = false
    @State private var showList = false
    @State private var didSetUp = false

    var body: some View {
        if let solution = model.solution {
            content(solution)
        } else {
            Text("Brak rozwiązania")
        }
    }

    private func content(_ solution: Solution) -> some View {
        let step = solution.steps[stepIndex]
        return VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                CubeSceneView(controller: scene)
                    .frame(maxWidth: .infinity)
                    .frame(height: 260)
                HoldBadge(top: model.colorOf[.U]!, front: model.colorOf[step.front]!)
                    .padding(10)
            }
            .background(Color(.secondarySystemBackground))

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header(solution, step)
                    movesStrip(step)
                    Text(step.explanation)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding()
            }

            controls(solution, step)
        }
        .navigationTitle("Rozwiązanie")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button {
                showList = true
            } label: {
                Image(systemName: "list.bullet")
            }
            .accessibilityLabel("Lista kroków")
        }
        .sheet(isPresented: $showList) {
            StepList(solution: solution, current: stepIndex) { index in
                showList = false
                jump(to: index, moveIndex: 0, in: solution)
            }
        }
        .onAppear {
            guard !didSetUp else { return }
            didSetUp = true
            scene.setColors(model.colorOf)
            jump(to: 0, moveIndex: 0, in: solution)
        }
    }

    private func header(_ solution: Solution, _ step: SolutionStep) -> some View {
        let stageSteps = solution.steps.filter { $0.stage == step.stage }
        let posInStage = (stageSteps.firstIndex { $0.id == step.id } ?? 0) + 1
        return VStack(alignment: .leading, spacing: 6) {
            Text("ETAP \(step.stage.rawValue)/7 · \(step.stage.title.uppercased())")
                .font(.caption.bold())
                .foregroundStyle(Color.accentColor)
            if posInStage == 1 {
                Text(step.stage.goal(ColorNames(model.colorOf)))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(step.title).font(.title3.bold())
            Text("Krok \(stepIndex + 1) z \(solution.steps.count) · łącznie \(solution.moveCount) ruchów")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func movesStrip(_ step: SolutionStep) -> some View {
        let rel = step.relativeMoves
        return VStack(alignment: .leading, spacing: 8) {
            if !rel.isEmpty {
                Text(step.notation)
                    .font(.title3.monospaced().bold())
                    .fixedSize(horizontal: false, vertical: true)
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(Array(rel.enumerated()), id: \.offset) { i, m in
                                Text(m.description)
                                    .font(.body.monospaced().bold())
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(chipColor(i), in: RoundedRectangle(cornerRadius: 8))
                                    .foregroundStyle(i == moveIndex ? Color.white : Color.primary)
                                    .id(i)
                            }
                        }
                    }
                    .onChange(of: moveIndex) { _, newValue in
                        withAnimation { proxy.scrollTo(min(newValue, rel.count - 1), anchor: .center) }
                    }
                }
                if moveIndex < rel.count {
                    Label(MoveText.describe(rel[moveIndex]), systemImage: "arrow.turn.up.right")
                        .font(.subheadline.bold())
                } else {
                    Label("Krok wykonany", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.green)
                }
            }
        }
    }

    private func chipColor(_ i: Int) -> Color {
        if i < moveIndex { return Color.green.opacity(0.25) }
        if i == moveIndex { return Color.accentColor }
        return Color(.tertiarySystemFill)
    }

    private func controls(_ solution: Solution, _ step: SolutionStep) -> some View {
        let atEndOfStep = moveIndex >= step.moves.count
        let isLast = stepIndex == solution.steps.count - 1
        return HStack(spacing: 18) {
            Button {
                if moveIndex > 0 {
                    jump(to: stepIndex, moveIndex: moveIndex - 1, in: solution)
                } else if stepIndex > 0 {
                    let prev = solution.steps[stepIndex - 1]
                    jump(to: stepIndex - 1, moveIndex: prev.moves.count, in: solution)
                }
            } label: {
                Image(systemName: "backward.fill")
            }
            .disabled(isAnimating || (stepIndex == 0 && moveIndex == 0))
            .accessibilityLabel("Cofnij ruch")

            Button {
                if isPlaying { isPlaying = false } else { isPlaying = true; playNext(solution) }
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
            }
            .disabled(atEndOfStep || (isAnimating && !isPlaying))
            .accessibilityLabel(isPlaying ? "Pauza" : "Odtwórz krok")

            Button {
                if !atEndOfStep { animateNext(solution, completion: nil) }
            } label: {
                Image(systemName: "forward.fill")
            }
            .disabled(isAnimating || atEndOfStep)
            .accessibilityLabel("Następny ruch")

            Spacer()

            if atEndOfStep && isLast {
                Label("Ułożona!", systemImage: "party.popper.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
            } else {
                Button {
                    jump(to: stepIndex + 1, moveIndex: 0, in: solution)
                } label: {
                    HStack {
                        Text("Następny krok")
                        Image(systemName: "chevron.right")
                    }
                    .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isAnimating || isLast)
            }
        }
        .font(.title2)
        .padding()
        .background(.bar)
    }

    // MARK: - Sterowanie stanem

    private func state(at stepIndex: Int, moveIndex: Int, in solution: Solution) -> CubieCube {
        var cube = solution.start
        for s in solution.steps[..<stepIndex] { cube = cube.applying(s.moves) }
        return cube.applying(Array(solution.steps[stepIndex].moves.prefix(moveIndex)))
    }

    private func jump(to index: Int, moveIndex newMove: Int, in solution: Solution) {
        isPlaying = false
        let frontChanged = solution.steps[index].front != solution.steps[stepIndex].front || !didSetUp
        stepIndex = index
        moveIndex = newMove
        scene.show(state(at: index, moveIndex: newMove, in: solution))
        scene.setFront(solution.steps[index].front, animated: frontChanged)
    }

    private func animateNext(_ solution: Solution, completion: (() -> Void)?) {
        let step = solution.steps[stepIndex]
        guard moveIndex < step.moves.count else { return }
        isAnimating = true
        let move = step.moves[moveIndex]
        let after = state(at: stepIndex, moveIndex: moveIndex + 1, in: solution)
        scene.animate(move, to: after) {
            moveIndex += 1
            isAnimating = false
            completion?()
        }
    }

    private func playNext(_ solution: Solution) {
        guard isPlaying else { return }
        guard moveIndex < solution.steps[stepIndex].moves.count else {
            isPlaying = false
            return
        }
        animateNext(solution) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { playNext(solution) }
        }
    }
}

/// Jak trzymać kostkę: który środek u góry, a który do siebie.
private struct HoldBadge: View {
    let top: CubeColor
    let front: CubeColor

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("TRZYMAJ KOSTKĘ").font(.caption2.bold()).foregroundStyle(.secondary)
            row(top, "u góry")
            row(front, "do siebie")
        }
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    private func row(_ c: CubeColor, _ text: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3)
                .fill(c.color)
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.black.opacity(0.4), lineWidth: 0.5))
                .frame(width: 14, height: 14)
            Text("\(c.name) \(text)").font(.caption)
        }
    }
}

private struct StepList: View {
    let solution: Solution
    let current: Int
    let onSelect: (Int) -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(Stage.allCases, id: \.self) { stage in
                    Section("\(stage.rawValue). \(stage.title)") {
                        ForEach(solution.steps.filter { $0.stage == stage }) { step in
                            Button {
                                onSelect(step.id)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(step.title)
                                        .font(.subheadline.bold())
                                        .foregroundStyle(step.id == current ? Color.accentColor : Color.primary)
                                    if !step.moves.isEmpty {
                                        Text(step.notation)
                                            .font(.caption.monospaced())
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Kroki")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }
}
