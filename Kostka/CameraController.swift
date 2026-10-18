import AVFoundation
import UIKit
import CubeCore

/// Obsługa aparatu: podgląd na żywo i odczyt kolorów 9 pól siatki na środku kadru.
final class CameraController: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    enum Status { case starting, running, denied, unavailable }

    /// Część szerokości obrazu zajmowana przez kwadrat siatki (ta sama wartość rysuje nakładkę).
    static let gridFraction: CGFloat = 0.8
    /// Proporcje obrazu z aparatu w pionie (720 × 1280).
    static let aspectRatio: CGFloat = 9.0 / 16.0

    let session = AVCaptureSession()
    @Published var status: Status = .starting
    /// Uśrednione kolory 9 pól (wierszami od lewego górnego).
    @Published var samples: [RGB] = Array(repeating: RGB(0.5, 0.5, 0.5), count: 9)
    @Published var torchOn = false

    private let queue = DispatchQueue(label: "camera.frames")
    private var device: AVCaptureDevice?
    private var smoothed: [RGB]?
    private var frameCounter = 0

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndRun()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted { self.configureAndRun() } else { self.status = .denied }
                }
            }
        default:
            status = .denied
        }
    }

    func stop() {
        setTorch(false)
        queue.async { [session] in
            if session.isRunning { session.stopRunning() }
        }
    }

    func setTorch(_ on: Bool) {
        guard let device, device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = on ? .on : .off
            device.unlockForConfiguration()
            torchOn = on
        } catch {
            torchOn = false
        }
    }

    private func configureAndRun() {
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            status = .unavailable
            return
        }
        device = camera
        queue.async { [weak self] in
            guard let self else { return }
            if self.session.inputs.isEmpty {
                self.session.beginConfiguration()
                self.session.sessionPreset = .hd1280x720
                if self.session.canAddInput(input) { self.session.addInput(input) }
                let output = AVCaptureVideoDataOutput()
                output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
                output.alwaysDiscardsLateVideoFrames = true
                output.setSampleBufferDelegate(self, queue: self.queue)
                if self.session.canAddOutput(output) { self.session.addOutput(output) }
                if let connection = output.connection(with: .video), connection.isVideoRotationAngleSupported(90) {
                    connection.videoRotationAngle = 90
                }
                self.session.commitConfiguration()
            }
            self.session.startRunning()
            DispatchQueue.main.async { self.status = .running }
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        frameCounter += 1
        guard frameCounter % 2 == 0, let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let current = Self.sampleGrid(buffer)
        if let previous = smoothed {
            smoothed = zip(previous, current).map { p, c in
                RGB(p.r * 0.6 + c.r * 0.4, p.g * 0.6 + c.g * 0.4, p.b * 0.6 + c.b * 0.4)
            }
        } else {
            smoothed = current
        }
        let result = smoothed!
        DispatchQueue.main.async { self.samples = result }
    }

    /// Średni kolor środkowej części każdego z 9 pól kwadratu na środku obrazu.
    static func sampleGrid(_ buffer: CVPixelBuffer) -> [RGB] {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        let rowBytes = CVPixelBufferGetBytesPerRow(buffer)
        guard let base = CVPixelBufferGetBaseAddress(buffer)?.assumingMemoryBound(to: UInt8.self) else {
            return Array(repeating: RGB(0.5, 0.5, 0.5), count: 9)
        }
        let side = Double(min(width, height)) * Double(gridFraction)
        let originX = (Double(width) - side) / 2
        let originY = (Double(height) - side) / 2
        let cell = side / 3
        var result: [RGB] = []
        for row in 0..<3 {
            for col in 0..<3 {
                // Próbkujemy środkowe 40% pola, żeby ominąć czarne ramki między naklejkami.
                let x0 = Int(originX + (Double(col) + 0.3) * cell), x1 = Int(originX + (Double(col) + 0.7) * cell)
                let y0 = Int(originY + (Double(row) + 0.3) * cell), y1 = Int(originY + (Double(row) + 0.7) * cell)
                var r = 0.0, g = 0.0, b = 0.0, n = 0.0
                for y in stride(from: max(0, y0), to: min(height, y1), by: 3) {
                    let line = base + y * rowBytes
                    for x in stride(from: max(0, x0), to: min(width, x1), by: 3) {
                        let p = line + x * 4
                        b += Double(p[0]); g += Double(p[1]); r += Double(p[2]); n += 1
                    }
                }
                n = max(n, 1)
                result.append(RGB(r / n / 255, g / n / 255, b / n / 255))
            }
        }
        return result
    }
}
