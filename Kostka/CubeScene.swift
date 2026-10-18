import SwiftUI
import SceneKit
import CubeCore

/// Trójwymiarowa kostka z animacją ruchów. Sterowana imperatywnie z widoku rozwiązania.
final class CubeSceneController {
    let view = SCNView()
    private let scene = SCNScene()
    private let cubeRoot = SCNNode()
    private let cameraPivot = SCNNode()
    private var cubies: [SCNNode] = []
    private var cubiePositions: [SCNNode: SIMD3<Int>] = [:]
    private var colorOf: [Face: CubeColor] = CubeColor.standardScheme
    private var cameraAngle: Float = 0

    init() {
        view.scene = scene
        view.backgroundColor = .clear
        view.antialiasingMode = .multisampling4X
        view.autoenablesDefaultLighting = false

        scene.rootNode.addChildNode(cubeRoot)

        let camera = SCNCamera()
        camera.fieldOfView = 38
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(3.4, 4.2, 7.6)
        cameraNode.look(at: SCNVector3(0, 0, 0))
        cameraPivot.addChildNode(cameraNode)
        scene.rootNode.addChildNode(cameraPivot)
        view.pointOfView = cameraNode

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light!.type = .ambient
        ambient.light!.intensity = 550
        scene.rootNode.addChildNode(ambient)

        let key = SCNNode()
        key.light = SCNLight()
        key.light!.type = .directional
        key.light!.intensity = 700
        key.eulerAngles = SCNVector3(-0.8, 0.5, 0)
        cameraPivot.addChildNode(key)
    }

    func setColors(_ colorOf: [Face: CubeColor]) {
        self.colorOf = colorOf
    }

    /// Ustawia kostkę w danym stanie (bez animacji).
    func show(_ cube: CubieCube) {
        cubeRoot.childNodes.forEach { $0.removeFromParentNode() }
        cubies.removeAll()
        cubiePositions.removeAll()
        let facelets = cube.facelets
        var nodes: [SIMD3<Int>: SCNNode] = [:]
        for x in -1...1 {
            for y in -1...1 {
                for z in -1...1 where !(x == 0 && y == 0 && z == 0) {
                    let box = SCNBox(width: 0.96, height: 0.96, length: 0.96, chamferRadius: 0.1)
                    let body = SCNMaterial()
                    body.diffuse.contents = UIColor(white: 0.08, alpha: 1)
                    box.materials = [body]
                    let node = SCNNode(geometry: box)
                    node.position = SCNVector3(Float(x), Float(y), Float(z))
                    cubeRoot.addChildNode(node)
                    cubies.append(node)
                    let p = SIMD3(x, y, z)
                    cubiePositions[node] = p
                    nodes[p] = node
                }
            }
        }
        for s in CubeGeometry.stickers {
            guard let node = nodes[SIMD3(s.x, s.y, s.z)] else { continue }
            let plane = SCNPlane(width: 0.8, height: 0.8)
            plane.cornerRadius = 0.12
            let material = SCNMaterial()
            material.diffuse.contents = colorOf[facelets[s.index]]!.uiColor
            material.lightingModel = .lambert
            plane.materials = [material]
            let sticker = SCNNode(geometry: plane)
            let n = CubeGeometry.normal(s.face)
            sticker.position = SCNVector3(Float(n.x) * 0.485, Float(n.y) * 0.485, Float(n.z) * 0.485)
            switch s.face {
            case .F: break
            case .B: sticker.eulerAngles.y = .pi
            case .R: sticker.eulerAngles.y = .pi / 2
            case .L: sticker.eulerAngles.y = -.pi / 2
            case .U: sticker.eulerAngles.x = -.pi / 2
            case .D: sticker.eulerAngles.x = .pi / 2
            }
            node.addChildNode(sticker)
        }
    }

    /// Obraca kamerę tak, żeby wskazana ściana była „przodem” (góra zostaje u góry).
    func setFront(_ front: Face, animated: Bool) {
        let angles: [Face: Float] = [.F: 0, .R: .pi / 2, .B: .pi, .L: -.pi / 2]
        let target = angles[front] ?? 0
        var delta = (target - cameraAngle).truncatingRemainder(dividingBy: 2 * .pi)
        if delta > .pi { delta -= 2 * .pi }
        if delta < -.pi { delta += 2 * .pi }
        cameraAngle += delta
        SCNTransaction.begin()
        SCNTransaction.animationDuration = animated ? 0.6 : 0
        cameraPivot.eulerAngles.y = cameraAngle
        SCNTransaction.commit()
    }

    /// Animuje ruch, a potem ustawia kostkę w stanie `after`.
    func animate(_ move: Move, to after: CubieCube, duration: TimeInterval = 0.4, completion: @escaping () -> Void) {
        let n = CubeGeometry.normal(move.face)
        let axis = SIMD3(n.x, n.y, n.z)
        let pivot = SCNNode()
        cubeRoot.addChildNode(pivot)
        for node in cubies {
            guard let p = cubiePositions[node], p.x * axis.x + p.y * axis.y + p.z * axis.z == 1 else { continue }
            node.removeFromParentNode()
            pivot.addChildNode(node)
        }
        // Zgodnie z ruchem wskazówek zegara patrząc na ścianę = obrót ujemny wokół normalnej.
        let quarter: CGFloat = move.turns == 3 ? 1 : -CGFloat(move.turns)
        let action = SCNAction.rotate(by: quarter * .pi / 2,
                                      around: SCNVector3(Float(axis.x), Float(axis.y), Float(axis.z)),
                                      duration: duration)
        action.timingMode = .easeInEaseOut
        pivot.runAction(action) { [weak self] in
            DispatchQueue.main.async {
                self?.show(after)
                completion()
            }
        }
    }
}

struct CubeSceneView: UIViewRepresentable {
    let controller: CubeSceneController

    func makeUIView(context: Context) -> SCNView { controller.view }
    func updateUIView(_ uiView: SCNView, context: Context) {}
}
