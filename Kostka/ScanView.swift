import SwiftUI
import AVFoundation
import CubeCore

struct ScanView: View {
    @Environment(AppModel.self) private var model
    @StateObject private var camera = CameraController()
    @State private var step = 0
    @State private var captured: [Face: [RGB]] = [:]

    /// Kolejność skanowania i wskazówki, jak trzymać kostkę.
    private static let order: [(face: Face, title: String, hint: String)] = [
        (.F, "Przód", "Trzymaj kostkę żółtym środkiem do góry, a zielonym w stronę aparatu."),
        (.R, "Prawa strona", "Obróć całą kostkę o ćwierć obrotu w lewo (żółty dalej u góry). Do aparatu patrzy teraz ściana, która była po prawej."),
        (.B, "Tył", "Jeszcze raz ćwierć obrotu w lewo. Do aparatu patrzy ściana, która na początku była z tyłu."),
        (.L, "Lewa strona", "I jeszcze raz ćwierć obrotu w lewo – ściana, która była po lewej."),
        (.U, "Góra", "Wróć zieloną ścianą do siebie i przechyl kostkę górą do aparatu: żółty środek na wprost, zielona ściana na dole kadru."),
        (.D, "Dół", "Teraz dół: biały środek do aparatu, zielona ściana na górze kadru.")
    ]

    var body: some View {
        VStack(spacing: 12) {
            instructions
            preview
            controls
        }
        .padding(.horizontal)
        .padding(.bottom)
        .navigationTitle("Skanowanie \(min(step + 1, 6))/6")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
    }

    private var current: (face: Face, title: String, hint: String) { Self.order[min(step, 5)] }

    private var instructions: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(current.title).font(.title2.bold())
                Spacer()
                HStack(spacing: 4) {
                    Text("środek:").font(.caption).foregroundStyle(.secondary)
                    Circle()
                        .fill(CubeColor.standardScheme[current.face]!.color)
                        .overlay(Circle().stroke(Color.secondary, lineWidth: 1))
                        .frame(width: 18, height: 18)
                }
            }
            Text(current.hint)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            progress
        }
    }

    private var progress: some View {
        HStack(spacing: 6) {
            ForEach(0..<6, id: \.self) { i in
                let face = Self.order[i].face
                if let s = captured[face] {
                    FaceThumbnail(colors: s.map { ColorClassifier.guess($0).color })
                        .frame(width: 30, height: 30)
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(i == step ? Color.accentColor : Color.secondary.opacity(0.5), lineWidth: i == step ? 2 : 1)
                        .frame(width: 30, height: 30)
                }
            }
        }
    }

    @ViewBuilder
    private var preview: some View {
        switch camera.status {
        case .denied:
            unavailable("Brak dostępu do aparatu. Włącz go w Ustawieniach → Kostka albo wpisz kolory ręcznie.")
        case .unavailable:
            unavailable("Aparat jest niedostępny (np. w symulatorze). Możesz wpisać kolory ręcznie.")
        case .starting, .running:
            ZStack {
                CameraPreview(session: camera.session)
                GridOverlay(samples: camera.samples)
            }
            .aspectRatio(CameraController.aspectRatio, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .frame(maxWidth: .infinity)
        }
    }

    private func unavailable(_ text: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.metering.unknown").font(.largeTitle)
            Text(text).multilineTextAlignment(.center)
            Button("Wpisz kolory ręcznie") {
                model.resetToSolved()
                model.path = [.editor]
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var controls: some View {
        HStack {
            Button {
                guard step > 0 else { return }
                step -= 1
                captured[Self.order[step].face] = nil
            } label: {
                Label("Cofnij", systemImage: "arrow.uturn.backward")
            }
            .disabled(step == 0)

            Spacer()

            Button {
                captured[current.face] = camera.samples
                if step == 5 {
                    finish()
                } else {
                    step += 1
                }
            } label: {
                Image(systemName: "camera.circle.fill")
                    .font(.system(size: 64))
            }
            .disabled(camera.status != .running)
            .accessibilityLabel("Zrób zdjęcie")

            Spacer()

            Button {
                camera.setTorch(!camera.torchOn)
            } label: {
                Label("Latarka", systemImage: camera.torchOn ? "flashlight.on.fill" : "flashlight.off.fill")
            }
        }
        .labelStyle(.iconOnly)
        .font(.title2)
    }

    private func finish() {
        var samples: [RGB] = []
        for f in Face.allCases { samples += captured[f]! }
        model.applyScan(samples: samples)
        camera.stop()
        model.path = [.editor]
    }
}

/// Nakładka z siatką 3×3 i podglądem rozpoznanych kolorów.
private struct GridOverlay: View {
    let samples: [RGB]

    var body: some View {
        GeometryReader { geo in
            let side = geo.size.width * CameraController.gridFraction
            let cell = side / 3
            ZStack {
                ForEach(0..<9, id: \.self) { i in
                    let r = i / 3, c = i % 3
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white, lineWidth: 2)
                            .shadow(radius: 2)
                        Circle()
                            .fill(ColorClassifier.guess(samples[i]).color)
                            .overlay(Circle().stroke(Color.black.opacity(0.6), lineWidth: 1))
                            .frame(width: cell * 0.22, height: cell * 0.22)
                            .offset(x: cell * 0.3, y: cell * 0.3)
                    }
                    .frame(width: cell - 6, height: cell - 6)
                    .position(x: (geo.size.width - side) / 2 + cell * (CGFloat(c) + 0.5),
                              y: (geo.size.height - side) / 2 + cell * (CGFloat(r) + 0.5))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

struct FaceThumbnail: View {
    let colors: [Color]

    var body: some View {
        GeometryReader { geo in
            let cell = geo.size.width / 3
            VStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { r in
                    HStack(spacing: 0) {
                        ForEach(0..<3, id: \.self) { c in
                            Rectangle().fill(colors[r * 3 + c]).frame(width: cell, height: cell)
                        }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

        override func layoutSubviews() {
            super.layoutSubviews()
            if let connection = previewLayer.connection, connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
        }
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}
}
