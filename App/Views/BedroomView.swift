import PetCore
import SceneKit
import SwiftUI
import UIKit

/// Third-person bedroom. The pet walks on the floor; the camera follows from behind.
struct BedroomView: View {
    @EnvironmentObject private var session: PetSession
    var onExit: () -> Void
    var onVisit: () -> Void
    var visitor: String

    @StateObject private var world = BedroomWorld()
    @State private var hint = !UserDefaults.standard.bool(forKey: "hint.room3d")
    @State private var lookDrag = CGSize.zero
    @State private var closet = false

    var body: some View {
        ZStack {
                BedroomCanvas(world: world)
                    .ignoresSafeArea()
                HStack(spacing: 0) {
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(petGesture())
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(lookGesture())
                }
                VStack {
                    HStack {
                        CuteRoomButton(title: "Exit", system: "door.left.hand.open", action: onExit)
                        Spacer()
                        CuteRoomButton(title: "Visit", system: "person.crop.circle", action: onVisit)
                    }
                    Spacer()
                    HStack(alignment: .bottom) {
                        joystick
                        Spacer()
                        if !world.actionTitle.isEmpty {
                            CuteRoomButton(title: world.actionTitle, system: world.actionIcon, action: perform)
                        }
                    }
                }
                .padding(16)
                if closet {
                    hangerBar
                }
                if !session.speech.isEmpty {
                    Text(session.speech)
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(Color(red: 0.28, green: 0.16, blue: 0.42))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Color.white.opacity(0.92)))
                        .padding(.top, 88)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .allowsHitTesting(false)
                }
                if hint {
                    RoomHintCard {
                        UserDefaults.standard.set(true, forKey: "hint.room3d")
                        hint = false
                    }
                }
            }
        .onAppear(perform: boot)
        .onReceive(Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()) { _ in
            world.tick(dt: 1.0 / 60.0, closet: closet)
        }
        .background(Color(red: 0.16, green: 0.12, blue: 0.28))
    }

    private var joystick: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 108, height: 108)
                .overlay(Circle().stroke(Color.white.opacity(0.7), lineWidth: 2))
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.white, Color(red: 0.86, green: 0.78, blue: 1)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 48, height: 48)
                .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
                .offset(x: world.knob.width, y: world.knob.height)
        }
        .frame(width: 140, height: 140)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let limited = CGSize(
                        width: min(36, max(-36, value.translation.width)),
                        height: min(36, max(-36, value.translation.height))
                    )
                    world.stickX = Double(limited.width / 36)
                    world.stickY = Double(-limited.height / 36)
                    world.knob = limited
                }
                .onEnded { _ in
                    world.stickX = 0
                    world.stickY = 0
                    world.knob = .zero
                }
        )
        .accessibilityLabel("Move")
    }

    private var hangerBar: some View {
        VStack {
            Spacer()
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(pegs) { peg in
                        Button {
                            wear(peg)
                        } label: {
                            VStack(spacing: 4) {
                                HangerMark()
                                    .stroke(Color(red: 0.35, green: 0.22, blue: 0.5), lineWidth: 3)
                                    .frame(width: 36, height: 28)
                                Text(peg.worn ? "On" : peg.title)
                                    .font(.system(.caption2, design: .rounded).weight(.bold))
                                    .lineLimit(1)
                            }
                            .foregroundStyle(Color(red: 0.28, green: 0.16, blue: 0.4))
                            .padding(8)
                            .frame(width: 84)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(peg.worn ? Color(red: 0.75, green: 0.95, blue: 0.8) : Color.white.opacity(0.92))
                                    .shadow(color: .black.opacity(0.12), radius: 5, y: 3)
                            )
                        }
                        .buttonStyle(CosmicPressStyle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .padding(.horizontal, 12)
            .padding(.bottom, 150)
        }
    }

    private var pegs: [ClosetPeg] {
        guard let record = session.record else { return [] }
        return RoomCloset.pegs(
            wardrobe: record.progress.wardrobe,
            outfitID: record.progress.outfitID,
            ownedIDs: record.progress.ownedIDs
        )
    }

    private func petGesture() -> some Gesture {
        DragGesture(minimumDistance: 18)
            .onEnded { value in
                guard abs(value.translation.width) > 24 else { return }
                session.react(to: .pet)
                world.nudge()
            }
            .exclusively(before: TapGesture(count: 2).onEnded {
                session.react(to: .tickle)
                world.nudge()
            })
            .exclusively(before: TapGesture(count: 1).onEnded {
                session.react(to: .poke)
                world.nudge()
            })
    }

    private func lookGesture() -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard !closet else { return }
                let dx = value.translation.width - lookDrag.width
                let dy = value.translation.height - lookDrag.height
                lookDrag = value.translation
                world.yaw -= Double(dx) * 0.008
                world.pitch = min(1.15, max(0.22, world.pitch + Double(dy) * 0.004))
            }
            .onEnded { _ in lookDrag = .zero }
    }

    private func boot() {
        guard let pet = session.record?.pet else { return }
        let guest = PetCard.parse(visitor)
        world.boot(
            room: session.currentRoom(),
            stage: pet.stage,
            form: pet.displayForm,
            outfit: session.record?.progress.outfitID,
            guestName: guest?.name ?? "",
            guestForm: guest?.form ?? ""
        )
        world.onSave = { room, reward in
            session.saveRoom(room, reward: reward)
            if reward > 0 {
                PocketSound.shared.reward()
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
        }
    }

    private func perform() {
        let floor = RoomSpace.floor(from: world.room.pet)
        if closet {
            closet = false
            world.closetOpen = false
            PocketSound.shared.tap()
            return
        }
        if RoomSpace.carried(in: world.room) != nil {
            guard let result = RoomSpace.putDown(in: world.room, at: floor) else { return }
            world.room = result.0
            world.refreshItems()
            world.onSave?(result.0, result.reward)
            if result.reward == 0 { PocketSound.shared.tap() }
            return
        }
        if let item = RoomSpace.nearestLoose(in: world.room, at: floor), let next = RoomSpace.pickUp(item.id, in: world.room) {
            world.room = next
            world.refreshItems()
            world.onSave?(next, 0)
            PocketSound.shared.tap()
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            return
        }
        if RoomSpace.nearCloset(floor) {
            closet = true
            world.closetOpen = true
            PocketSound.shared.tap()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    private func wear(_ peg: ClosetPeg) {
        guard let record = session.record else { return }
        let pet = record.pet
        let owned = record.progress.ownedIDs
        let wear: ClosetWear?
        if peg.worn {
            wear = RoomCloset.returnToPeg(
                id: peg.id,
                at: peg.spot,
                wardrobe: record.progress.wardrobe,
                outfitID: record.progress.outfitID,
                ownedIDs: owned,
                stage: pet.stage,
                form: pet.displayForm
            )
        } else {
            wear = RoomCloset.dropOnPet(
                id: peg.id,
                at: RoomCloset.petSpot,
                wardrobe: record.progress.wardrobe,
                outfitID: record.progress.outfitID,
                ownedIDs: owned,
                stage: pet.stage,
                form: pet.displayForm
            )
        }
        guard let wear else { return }
        session.applyCloset(wear)
        world.dress(outfit: wear.outfitID, form: pet.displayForm, stage: pet.stage)
        PocketSound.shared.tap()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

struct CuteRoomButton: View {
    var title: String
    var system: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: system)
                Text(title)
            }
            .font(.system(.headline, design: .rounded).weight(.bold))
            .foregroundStyle(Color(red: 0.28, green: 0.16, blue: 0.42))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.white, Color(red: 1, green: 0.86, blue: 0.94)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: Color(red: 0.35, green: 0.2, blue: 0.5).opacity(0.28), radius: 8, y: 4)
            )
        }
        .buttonStyle(CosmicPressStyle())
    }
}

struct HangerMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY + 8))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + 4, y: rect.maxY),
            control: CGPoint(x: rect.minX, y: rect.midY)
        )
        path.move(to: CGPoint(x: rect.midX, y: rect.minY + 8))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - 4, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.midY)
        )
        return path
    }
}

struct RoomHintCard: View {
    var onDone: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.28).ignoresSafeArea()
            VStack(spacing: 10) {
                Text("Your bedroom")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                Text("Left stick walks. Right side looks around.")
                Text("Pick up a toy, carry it to the bin, and drop it in.")
                Text("Walk to the closet and open the doors to get dressed.")
                CuteRoomButton(title: "Let's go", system: "sparkles", action: onDone)
            }
            .font(.system(.body, design: .rounded))
            .multilineTextAlignment(.center)
            .foregroundStyle(Color(red: 0.28, green: 0.16, blue: 0.42))
            .padding(22)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .padding(28)
        }
    }
}

struct BedroomCanvas: UIViewRepresentable {
    var world: BedroomWorld

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = world.scene
        view.pointOfView = world.camera
        view.rendersContinuously = true
        view.antialiasingMode = .multisampling4X
        view.backgroundColor = UIColor(red: 0.16, green: 0.12, blue: 0.28, alpha: 1)
        view.autoenablesDefaultLighting = false
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}
}

final class BedroomWorld: ObservableObject {
    let scene = SCNScene()
    let camera = SCNNode()
    var room = PlayRoom.starter()
    @Published var actionTitle = ""
    @Published var actionIcon = "hand.tap"
    @Published var knob = CGSize.zero
    var stickX = 0.0
    var stickY = 0.0
    var yaw = 0.0
    var pitch = 0.42
    var closetOpen = false
    var onSave: ((PlayRoom, Int) -> Void)?
    private var touchUntil = 0.0

    func nudge() {
        touchUntil = CACurrentMediaTime() + 0.45
    }

    private let pet = SCNNode()
    private let carry = SCNNode()
    private var doors: [SCNNode] = []
    private var booted = false
    private var saveWait = 0.0
    private var moved = false
    private var cam = SCNVector3(0, 1.6, 2.4)
    private var outfitID: String?
    private var form: AdultForm?
    private var stage: LifeStage = .baby

    func boot(room: PlayRoom, stage: LifeStage, form: AdultForm?, outfit: String?, guestName: String, guestForm: String) {
        guard !booted else { return }
        booted = true
        var room = room
        var floor = RoomSpace.floor(from: room.pet)
        if RoomSpace.blocked(floor) {
            floor = FloorPoint(x: 0.35, z: 0.45)
            room.pet = RoomSpace.spot(from: floor)
        }
        self.room = room
        self.yaw = room.yaw
        self.stage = stage
        self.form = form
        self.outfitID = outfit
        buildRoom()
        buildPet()
        if !guestName.isEmpty {
            addGuest(name: guestName, form: guestForm)
        }
        refreshItems()
        placePet(at: floor, yaw: yaw, moving: false, time: 0)
    }

    func tick(dt: Double, closet: Bool) {
        guard booted else { return }
        closetOpen = closet
        let time = CACurrentMediaTime()
        var floor = RoomSpace.floor(from: room.pet)
        if closet {
            easeCamera(to: SCNVector3(0, 1.35, -0.55), look: SCNVector3(0, 1.05, -1.9), dt: dt)
            setDoors(open: true)
            setAction("Close", "xmark.circle")
            return
        }
        setDoors(open: false)
        let walked = RoomSpace.walk(from: floor, yaw: yaw, stickX: stickX, stickY: stickY, dt: dt)
        floor = walked.0
        yaw = walked.yaw
        room.pet = RoomSpace.spot(from: floor)
        room.yaw = yaw
        placePet(at: floor, yaw: yaw, moving: walked.moving, time: time)
        followCamera(pet: floor, dt: dt)
        if walked.moving {
            moved = true
            saveWait += dt
            if saveWait > 0.7 {
                saveWait = 0
                moved = false
                onSave?(room, 0)
            }
        }
        refreshPrompt(at: floor)
    }

    func refreshItems() {
        scene.rootNode.childNode(withName: "items", recursively: false)?.removeFromParentNode()
        let pile = SCNNode()
        pile.name = "items"
        for thing in room.things where !thing.tucked && !thing.carried {
            let node = toyNode(thing)
            let spot = RoomSpace.floor(from: thing.spot)
            node.position = SCNVector3(Float(spot.x), 0.16, Float(spot.z))
            pile.addChildNode(node)
        }
        scene.rootNode.addChildNode(pile)
        carry.childNodes.forEach { $0.removeFromParentNode() }
        if let held = RoomSpace.carried(in: room) {
            let node = toyNode(held)
            node.position = SCNVector3(0, 0.15, 0)
            carry.addChildNode(node)
        }
    }

    func dress(outfit: String?, form: AdultForm?, stage: LifeStage) {
        outfitID = outfit
        self.form = form
        self.stage = stage
        pet.childNode(withName: "outfit", recursively: false)?.removeFromParentNode()
        let worn = outfitNode(outfit)
        worn.name = "outfit"
        pet.addChildNode(worn)
    }

    private func refreshPrompt(at floor: FloorPoint) {
        let title: String
        let icon: String
        if RoomSpace.carried(in: room) != nil {
            if floor.distance(to: RoomSpace.bin) <= RoomSpace.reach
                || floor.distance(to: RoomSpace.shelf) <= RoomSpace.reach
                || floor.distance(to: RoomSpace.bed) <= RoomSpace.reach {
                title = "Drop"
                icon = "arrow.down.circle"
            } else {
                title = ""
                icon = "hand.tap"
            }
        } else if RoomSpace.nearestLoose(in: room, at: floor) != nil {
            title = "Pick up"
            icon = "hand.raised"
        } else if RoomSpace.nearCloset(floor) {
            title = "Open"
            icon = "door.left.hand.open"
        } else {
            title = ""
            icon = "hand.tap"
        }
        if title != actionTitle {
            actionTitle = title
            actionIcon = icon
        }
    }

    private func setAction(_ title: String, _ icon: String) {
        if actionTitle != title {
            actionTitle = title
            actionIcon = icon
        }
    }

    private func placePet(at floor: FloorPoint, yaw: Double, moving: Bool, time: Double) {
        pet.position = SCNVector3(Float(floor.x), 0, Float(floor.z))
        pet.eulerAngles.y = Float(yaw)
        let touched = time < touchUntil
        let swing = moving ? Float(sin(time * 10)) : (touched ? Float(sin(time * 18)) : Float(sin(time * 2) * 0.2))
        let bob = moving ? abs(sin(time * 10)) * 0.06 : sin(time * 2) * 0.012
        let squash: Float = touched ? 0.82 : (moving ? Float(1 - sin(time * 10) * 0.06) : Float(1 + sin(time * 2) * 0.02))
        if let body = pet.childNode(withName: "body", recursively: false) {
            body.position.y = 0.46 + Float(bob)
            body.scale = SCNVector3(touched ? 1.12 : 1, squash, touched ? 1.12 : 1)
            body.eulerAngles.z = moving ? Float(sin(time * 10) * 0.08) : (touched ? swing * 0.2 : 0)
        }
        pet.childNode(withName: "footL", recursively: false)?.eulerAngles.x = swing * 0.9
        pet.childNode(withName: "footR", recursively: false)?.eulerAngles.x = -swing * 0.9
        pet.childNode(withName: "handL", recursively: false)?.eulerAngles.x = -swing
        pet.childNode(withName: "handR", recursively: false)?.eulerAngles.x = swing
        if let antenna = pet.childNode(withName: "antenna", recursively: true) {
            antenna.eulerAngles.z = swing * 0.25
        }
    }

    private func followCamera(pet floor: FloorPoint, dt: Double) {
        let lookX = sin(yaw)
        let lookZ = -cos(yaw)
        let distance = 2.55 - (pitch - 0.42) * 0.45
        let height = 1.15 + Float(pitch) * 0.85
        var desired = SCNVector3(
            Float(floor.x) - Float(lookX) * Float(distance),
            height,
            Float(floor.z) - Float(lookZ) * Float(distance)
        )
        desired = pullInside(desired, around: floor)
        let t: Float = min(1, Float(dt) * 6)
        cam = SCNVector3(cam.x + (desired.x - cam.x) * t, cam.y + (desired.y - cam.y) * t, cam.z + (desired.z - cam.z) * t)
        camera.position = cam
        camera.look(at: SCNVector3(Float(floor.x), 0.7, Float(floor.z)), up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, -1))
    }

    private func easeCamera(to desired: SCNVector3, look: SCNVector3, dt: Double) {
        let t: Float = min(1, Float(dt) * 3)
        cam = SCNVector3(cam.x + (desired.x - cam.x) * t, cam.y + (desired.y - cam.y) * t, cam.z + (desired.z - cam.z) * t)
        camera.position = cam
        camera.look(at: look, up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, -1))
    }

    /// Keeps the camera on the pet's side of the walls instead of sliding through them.
    private func pullInside(_ point: SCNVector3, around floor: FloorPoint) -> SCNVector3 {
        let limit: Float = 1.7
        let origin = SCNVector3(Float(floor.x), point.y, Float(floor.z))
        var dx = point.x - origin.x
        var dz = point.z - origin.z
        var scale: Float = 1
        if abs(origin.x + dx) > limit, abs(dx) > 0.01 {
            scale = min(scale, (limit * (dx > 0 ? 1 : -1) - origin.x) / dx)
        }
        if abs(origin.z + dz) > limit, abs(dz) > 0.01 {
            let allowed = (limit * (dz > 0 ? 1 : -1) - origin.z) / dz
            scale = min(scale, allowed)
        }
        scale = min(1, max(0.25, scale))
        dx *= scale
        dz *= scale
        return SCNVector3(
            min(limit, max(-limit, origin.x + dx)),
            min(2.2, max(0.7, point.y)),
            min(limit, max(-limit, origin.z + dz))
        )
    }

    private func setDoors(open: Bool) {
        let angle: Float = open ? 1.15 : 0
        for (index, door) in doors.enumerated() {
            let target = index == 0 ? angle : -angle
            door.eulerAngles.y += (target - door.eulerAngles.y) * 0.12
        }
    }

    private func buildRoom() {
        scene.background.contents = color(0.55, 0.62, 0.86)
        let floor = box(5.4, 0.16, 5.4, 0.02, color(0.86, 0.72, 0.52))
        floor.position = SCNVector3(0, -0.08, 0)
        if let material = floor.geometry?.firstMaterial {
            material.diffuse.contents = woodImage()
            material.diffuse.wrapS = .repeat
            material.diffuse.wrapT = .repeat
            material.diffuse.contentsTransform = SCNMatrix4MakeScale(4, 4, 1)
        }
        scene.rootNode.addChildNode(floor)
        if let rug = furniture("rugRectangle") {
            rug.position = SCNVector3(0.15, 0.02, 0.2)
            rug.scale = SCNVector3(1.4, 1.4, 1.4)
            scene.rootNode.addChildNode(rug)
        }
        addWalls()
        scene.rootNode.addChildNode(makeBed())
        scene.rootNode.addChildNode(makeCloset())
        scene.rootNode.addChildNode(makeShelf())
        if let desk = furniture("desk") {
            desk.position = SCNVector3(1.35, 0, 0.15)
            desk.eulerAngles.y = -.pi / 2
            scene.rootNode.addChildNode(desk)
        }
        if let lamp = furniture("lampRoundFloor") {
            lamp.position = SCNVector3(-1.85, 0, 1.15)
            scene.rootNode.addChildNode(lamp)
        }
        if let plant = furniture("plantSmall1") {
            plant.position = SCNVector3(1.7, 0, -1.15)
            scene.rootNode.addChildNode(plant)
        }
        if let plant = furniture("plantSmall2") {
            plant.position = SCNVector3(-0.2, 0, 1.7)
            scene.rootNode.addChildNode(plant)
        }
        scene.rootNode.addChildNode(makeBin())
        scene.rootNode.addChildNode(makeWindow())
        addLights()
        camera.camera = SCNCamera()
        camera.camera?.fieldOfView = 58
        camera.camera?.zNear = 0.05
        camera.camera?.zFar = 40
        scene.rootNode.addChildNode(camera)
    }

    private func addWalls() {
        let paint = color(0.93, 0.86, 0.98)
        let trim = color(1, 0.95, 0.98)
        let paper = wallpaperImage()
        for (x, z, w, l) in [(Float(0), Float(-2.6), Float(5.2), Float(0.12)), (0, 2.6, 5.2, 0.12), (-2.6, 0, 0.12, 5.2), (2.6, 0, 0.12, 5.2)] {
            let wall = box(CGFloat(w), 2.7, CGFloat(l), 0.04, paint)
            if let material = wall.geometry?.firstMaterial {
                material.diffuse.contents = paper
                material.diffuse.wrapS = .repeat
                material.diffuse.wrapT = .repeat
                material.diffuse.contentsTransform = SCNMatrix4MakeScale(3, 2, 1)
            }
            wall.position = SCNVector3(x, 1.35, z)
            scene.rootNode.addChildNode(wall)
            let board = box(CGFloat(w * 0.96), 0.16, CGFloat(max(l, 0.18)), 0.04, trim)
            board.position = SCNVector3(x, 0.1, z)
            scene.rootNode.addChildNode(board)
        }
        let ceiling = box(5.2, 0.08, 5.2, 0.02, color(0.98, 0.94, 1))
        ceiling.position = SCNVector3(0, 2.7, 0)
        scene.rootNode.addChildNode(ceiling)
        let cord = cylinder(0.02, 0.35, color(0.9, 0.85, 0.95))
        cord.position = SCNVector3(0, 2.5, 0)
        scene.rootNode.addChildNode(cord)
        let lamp = sphere(0.16, color(1, 0.95, 0.75))
        lamp.position = SCNVector3(0, 2.28, 0)
        lamp.geometry?.firstMaterial?.emission.contents = color(1, 0.9, 0.6)
        scene.rootNode.addChildNode(lamp)
    }

    private func makeBed() -> SCNNode {
        if let bed = furniture("bedSingle") {
            bed.position = SCNVector3(-1.15, 0, -1.35)
            bed.eulerAngles.y = .pi
            return bed
        }
        let bed = SCNNode()
        bed.position = SCNVector3(-1.1, 0, -1.55)
        bed.addChildNode(shifted(box(1.7, 0.28, 1.05, 0.08, color(0.62, 0.72, 0.95)), y: 0.22))
        bed.addChildNode(shifted(box(1.55, 0.18, 0.92, 0.1, color(0.82, 0.9, 1)), y: 0.4))
        bed.addChildNode(shifted(box(1.35, 0.1, 0.7, 0.06, color(0.98, 0.78, 0.88)), x: 0.05, y: 0.5, z: 0.05))
        bed.addChildNode(shifted(cylinder(0.12, 0.7, color(0.95, 0.7, 0.82)), x: 0.15, y: 0.48, z: 0.28))
        bed.addChildNode(shifted(box(1.55, 0.7, 0.12, 0.06, color(0.55, 0.62, 0.9)), y: 0.7, z: -0.48))
        let pillow = sphere(0.2, color(1, 0.96, 0.98))
        pillow.scale = SCNVector3(1.3, 0.55, 0.8)
        pillow.position = SCNVector3(-0.28, 0.58, -0.28)
        bed.addChildNode(pillow)
        let pillow2 = pillow.clone()
        pillow2.position = SCNVector3(0.28, 0.58, -0.22)
        bed.addChildNode(pillow2)
        for (x, z) in [(-0.7, -0.4), (0.7, -0.4), (-0.7, 0.4), (0.7, 0.4)] as [(Float, Float)] {
            bed.addChildNode(shifted(cylinder(0.06, 0.22, color(0.45, 0.4, 0.7)), x: x, y: 0.1, z: z))
        }
        return bed
    }

    private func makeCloset() -> SCNNode {
        let closet = SCNNode()
        closet.position = SCNVector3(0, 0, -1.95)
        closet.addChildNode(shifted(box(1.55, 1.9, 0.42, 0.06, color(0.98, 0.82, 0.9)), y: 0.98))
        closet.addChildNode(shifted(box(1.62, 0.1, 0.48, 0.04, color(0.9, 0.7, 0.82)), y: 1.95))
        closet.addChildNode(shifted(box(1.2, 0.06, 0.3, 0.02, color(0.85, 0.7, 0.95)), y: 1.15, z: 0.02))
        let left = hinge(width: 0.7, height: 1.7, x: -0.74, flip: false)
        let right = hinge(width: 0.7, height: 1.7, x: 0.74, flip: true)
        closet.addChildNode(left)
        closet.addChildNode(right)
        doors = [left, right]
        return closet
    }

    private func hinge(width: CGFloat, height: CGFloat, x: Float, flip: Bool) -> SCNNode {
        let hinge = SCNNode()
        hinge.position = SCNVector3(x, 1.0, 0.22)
        let sign: Float = flip ? -1 : 1
        let panel = box(width, height, 0.06, 0.03, color(1, 0.9, 0.94))
        panel.position = SCNVector3(sign * Float(width / 2), 0, 0)
        hinge.addChildNode(panel)
        let handle = sphere(0.045, color(1, 0.82, 0.45))
        handle.position = SCNVector3(sign * (Float(width) - 0.12), 0, 0.06)
        hinge.addChildNode(handle)
        return hinge
    }

    private func makeShelf() -> SCNNode {
        if let shelf = furniture("bookcaseOpen") {
            shelf.position = SCNVector3(-1.95, 0, 0.15)
            shelf.eulerAngles.y = .pi / 2
            return shelf
        }
        let shelf = SCNNode()
        shelf.position = SCNVector3(-1.95, 0, 0.1)
        shelf.addChildNode(shifted(box(0.18, 1.5, 1.4, 0.03, color(0.98, 0.9, 0.7)), y: 0.85))
        for step in [0.45, 0.9, 1.35] as [Float] {
            shelf.addChildNode(shifted(box(0.42, 0.06, 1.25, 0.02, color(0.95, 0.82, 0.6)), x: 0.12, y: step))
        }
        let book = box(0.08, 0.28, 0.22, 0.01, color(0.7, 0.6, 0.95))
        book.position = SCNVector3(0.12, 1.08, -0.3)
        shelf.addChildNode(book)
        let book2 = box(0.08, 0.24, 0.2, 0.01, color(1, 0.7, 0.75))
        book2.position = SCNVector3(0.12, 1.06, -0.05)
        shelf.addChildNode(book2)
        let star = sphere(0.1, color(1, 0.9, 0.45))
        star.position = SCNVector3(0.16, 0.62, 0.35)
        shelf.addChildNode(star)
        return shelf
    }

    private func makeBin() -> SCNNode {
        let bin = SCNNode()
        bin.position = SCNVector3(1.72, 0, 1.48)
        let body = cylinder(0.34, 0.42, color(0.58, 0.46, 0.9))
        body.position = SCNVector3(0, 0.24, 0)
        bin.addChildNode(body)
        let rim = cylinder(0.36, 0.06, color(0.75, 0.65, 1))
        rim.position = SCNVector3(0, 0.46, 0)
        bin.addChildNode(rim)
        let lid = cylinder(0.32, 0.05, color(0.86, 0.78, 1))
        lid.position = SCNVector3(0.08, 0.52, -0.02)
        lid.eulerAngles.z = 0.5
        bin.addChildNode(lid)
        let knob = sphere(0.05, color(1, 0.82, 0.45))
        knob.position = SCNVector3(0.08, 0.58, -0.02)
        bin.addChildNode(knob)
        return bin
    }

    private func makeWindow() -> SCNNode {
        let window = SCNNode()
        window.position = SCNVector3(0.2, 1.45, 2.48)
        window.addChildNode(shifted(box(1.5, 1.15, 0.08, 0.04, color(1, 0.95, 0.98))))
        let glass = box(1.15, 0.82, 0.02, 0.02, color(0.25, 0.22, 0.5))
        glass.geometry?.firstMaterial?.emission.contents = color(0.35, 0.4, 0.8)
        glass.position = SCNVector3(0, 0, 0.04)
        window.addChildNode(glass)
        for index in 0..<7 {
            let star = sphere(0.025, color(1, 0.95, 0.7))
            star.geometry?.firstMaterial?.emission.contents = color(1, 0.95, 0.6)
            star.position = SCNVector3(Float(index) * 0.14 - 0.42, Float(index % 3) * 0.16 - 0.16, 0.06)
            window.addChildNode(star)
        }
        let curtain = capsule(0.08, 0.9, color(0.95, 0.75, 0.9))
        curtain.position = SCNVector3(-0.72, -0.05, 0.08)
        window.addChildNode(curtain)
        let curtain2 = curtain.clone()
        curtain2.position = SCNVector3(0.72, -0.05, 0.08)
        window.addChildNode(curtain2)
        return window
    }

    private func addLights() {
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 180
        ambient.light?.color = color(1, 0.93, 0.98)
        scene.rootNode.addChildNode(ambient)
        let sun = SCNNode()
        sun.light = SCNLight()
        sun.light?.type = .directional
        sun.light?.intensity = 420
        sun.light?.color = color(1, 0.96, 0.9)
        sun.light?.castsShadow = true
        sun.light?.shadowMode = .deferred
        sun.light?.shadowSampleCount = 8
        sun.light?.shadowRadius = 6
        sun.light?.shadowMapSize = CGSize(width: 1024, height: 1024)
        sun.light?.shadowColor = UIColor(white: 0, alpha: 0.28)
        sun.eulerAngles = SCNVector3(-0.9, 0.4, 0)
        scene.rootNode.addChildNode(sun)
        let fill = SCNNode()
        fill.light = SCNLight()
        fill.light?.type = .omni
        fill.light?.intensity = 180
        fill.light?.color = color(0.8, 0.75, 1)
        fill.position = SCNVector3(-1.2, 1.8, 1.2)
        scene.rootNode.addChildNode(fill)
    }

    private func buildPet() {
        pet.childNodes.forEach { $0.removeFromParentNode() }
        let colors = petColors(form)
        let scale: Float = stage == .egg ? 0.7 : (stage == .baby ? 0.9 : 1)
        let body = sphere(0.34 * CGFloat(scale), colors.body)
        body.name = "body"
        body.position = SCNVector3(0, 0.5, 0)
        if form?.root == .spiky {
            for index in 0..<5 {
                let spike = SCNCone(topRadius: 0, bottomRadius: 0.05, height: 0.16)
                let node = SCNNode(geometry: spike)
                node.geometry?.materials = [paint(colors.antenna)]
                let angle = Float(index) / 5 * .pi * 2
                node.position = SCNVector3(sin(angle) * 0.22, 0.18, cos(angle) * 0.22)
                node.eulerAngles.x = 0.6
                body.addChildNode(node)
            }
        }
        if form?.root == .cloud {
            for offset in [SCNVector3(-0.22, 0.05, 0), SCNVector3(0.22, 0.02, 0.05), SCNVector3(0, 0.16, -0.05)] {
                let puff = sphere(0.16, colors.body)
                puff.position = offset
                body.addChildNode(puff)
            }
        }
        let belly = sphere(0.2 * CGFloat(scale), colors.belly)
        belly.position = SCNVector3(0, -0.06, 0.16)
        body.addChildNode(belly)
        let eye = sphere(0.07, color(1, 1, 1))
        eye.position = SCNVector3(-0.1, 0.08, 0.26)
        body.addChildNode(eye)
        let eye2 = eye.clone()
        eye2.position = SCNVector3(0.1, 0.08, 0.26)
        body.addChildNode(eye2)
        let pupil = sphere(0.035, color(0.25, 0.16, 0.4))
        pupil.position = SCNVector3(-0.1, 0.08, 0.32)
        body.addChildNode(pupil)
        let pupil2 = pupil.clone()
        pupil2.position = SCNVector3(0.1, 0.08, 0.32)
        body.addChildNode(pupil2)
        let antenna = SCNNode()
        antenna.name = "antenna"
        for side: Float in [-1, 1] {
            let stalk = capsule(0.03, 0.22, colors.antenna)
            stalk.position = SCNVector3(side * 0.12, 0.38, 0)
            antenna.addChildNode(stalk)
            let tip = sphere(0.06, colors.antenna)
            tip.position = SCNVector3(side * 0.12, 0.52, 0)
            antenna.addChildNode(tip)
        }
        body.addChildNode(antenna)
        pet.addChildNode(body)
        for (name, x) in [("handL", Float(-0.32)), ("handR", Float(0.32))] {
            let hand = sphere(0.07, colors.body)
            hand.name = name
            hand.position = SCNVector3(x, 0.42, 0.12)
            pet.addChildNode(hand)
        }
        let foot = sphere(0.09, colors.body)
        foot.name = "footL"
        foot.position = SCNVector3(-0.12, 0.08, 0.04)
        pet.addChildNode(foot)
        let footR = foot.clone()
        footR.name = "footR"
        footR.position = SCNVector3(0.12, 0.08, 0.04)
        pet.addChildNode(footR)
        carry.position = SCNVector3(0, 1.05, 0)
        pet.addChildNode(carry)
        let worn = outfitNode(outfitID)
        worn.name = "outfit"
        pet.addChildNode(worn)
        scene.rootNode.addChildNode(pet)
    }

    private func addGuest(name: String, form raw: String) {
        let guest = SCNNode()
        let body = sphere(0.22, color(0.75, 0.85, 1))
        body.position = SCNVector3(1.3, 0.4, 1.9)
        guest.addChildNode(body)
        let label = SCNNode()
        label.position = SCNVector3(1.3, 0.75, 1.9)
        guest.addChildNode(label)
        _ = name
        _ = raw
        scene.rootNode.addChildNode(guest)
    }

    private func outfitNode(_ id: String?) -> SCNNode {
        let node = SCNNode()
        guard let id else { return node }
        if id == "outfit.scarf" {
            let scarf = SCNTorus(ringRadius: 0.16, pipeRadius: 0.04)
            let wrap = SCNNode(geometry: scarf)
            wrap.geometry?.materials = [paint(color(1, 0.55, 0.7))]
            wrap.position = SCNVector3(0, 0.38, 0)
            wrap.eulerAngles.x = .pi / 2
            node.addChildNode(wrap)
        } else if id == "outfit.bow" {
            let puff = sphere(0.08, color(1, 0.45, 0.65))
            puff.position = SCNVector3(-0.08, 0.55, 0.1)
            node.addChildNode(puff)
            let puff2 = puff.clone()
            puff2.position = SCNVector3(0.08, 0.55, 0.1)
            node.addChildNode(puff2)
        } else if id == "outfit.helmet" {
            let helm = sphere(0.4, color(0.75, 0.8, 0.9))
            helm.position = SCNVector3(0, 0.55, 0)
            helm.geometry?.firstMaterial?.transparency = 0.45
            node.addChildNode(helm)
        }
        return node
    }

    private func toyNode(_ thing: RoomThing) -> SCNNode {
        switch thing.id {
        case "toy_moon":
            let moon = sphere(0.12, color(0.95, 0.95, 1))
            let bite = sphere(0.09, color(0.93, 0.86, 0.98))
            bite.position = SCNVector3(0.06, 0.02, 0)
            moon.addChildNode(bite)
            return moon
        case "snack_cookie":
            let cookie = cylinder(0.12, 0.05, color(0.95, 0.75, 0.45))
            let chip = sphere(0.03, color(0.45, 0.28, 0.2))
            chip.position = SCNVector3(0.04, 0.03, 0.02)
            cookie.addChildNode(chip)
            return cookie
        case "decor_star":
            let star = SCNNode()
            for index in 0..<5 {
                let arm = box(0.04, 0.16, 0.04, 0.01, color(1, 0.88, 0.4))
                arm.eulerAngles.z = Float(index) / 5 * .pi * 2
                arm.position = SCNVector3(0, 0.08, 0)
                star.addChildNode(arm)
            }
            return star
        default:
            let comet = sphere(0.12, color(1, 0.72, 0.45))
            let tail = SCNCone(topRadius: 0.02, bottomRadius: 0.08, height: 0.22)
            let flame = SCNNode(geometry: tail)
            flame.geometry?.materials = [paint(color(1, 0.9, 0.55))]
            flame.eulerAngles.x = .pi / 2
            flame.position = SCNVector3(0, 0, -0.16)
            comet.addChildNode(flame)
            return comet
        }
    }

    private func petColors(_ form: AdultForm?) -> (body: UIColor, belly: UIColor, antenna: UIColor) {
        switch form?.root {
        case .cloud:
            return (color(0.9, 0.94, 1), color(1, 1, 1), color(0.75, 0.85, 1))
        case .spiky:
            return (color(0.95, 0.7, 0.75), color(1, 0.9, 0.88), color(0.85, 0.45, 0.55))
        default:
            return (color(0.75, 0.66, 0.98), color(0.95, 0.9, 1), color(0.55, 0.45, 0.9))
        }
    }

    private func box(_ w: CGFloat, _ h: CGFloat, _ l: CGFloat, _ chamfer: CGFloat, _ ui: UIColor) -> SCNNode {
        let geo = SCNBox(width: w, height: h, length: l, chamferRadius: chamfer)
        geo.materials = [paint(ui)]
        return SCNNode(geometry: geo)
    }

    private func sphere(_ radius: CGFloat, _ ui: UIColor) -> SCNNode {
        let geo = SCNSphere(radius: radius)
        geo.segmentCount = 24
        geo.materials = [paint(ui)]
        return SCNNode(geometry: geo)
    }

    private func cylinder(_ radius: CGFloat, _ height: CGFloat, _ ui: UIColor) -> SCNNode {
        let geo = SCNCylinder(radius: radius, height: height)
        geo.radialSegmentCount = 24
        geo.materials = [paint(ui)]
        return SCNNode(geometry: geo)
    }

    private func capsule(_ radius: CGFloat, _ height: CGFloat, _ ui: UIColor) -> SCNNode {
        let geo = SCNCapsule(capRadius: radius, height: height)
        geo.materials = [paint(ui)]
        return SCNNode(geometry: geo)
    }

    private func furniture(_ name: String) -> SCNNode? {
        let candidates = [
            Bundle.main.url(forResource: name, withExtension: "dae", subdirectory: "Furniture"),
            Bundle.main.url(forResource: name, withExtension: "dae")
        ]
        for url in candidates.compactMap({ $0 }) {
            guard let loaded = try? SCNScene(url: url, options: nil) else { continue }
            let root = SCNNode()
            for child in loaded.rootNode.childNodes {
                root.addChildNode(child.clone())
            }
            root.enumerateChildNodes { node, _ in
                guard let materials = node.geometry?.materials else { return }
                for material in materials {
                    let title = (material.name ?? "").lowercased()
                    let tone: UIColor
                    if title.contains("wood") {
                        tone = color(0.84, 0.68, 0.48)
                    } else if title.contains("carpet") || title.contains("fabric") {
                        tone = color(0.96, 0.72, 0.82)
                    } else if title.contains("metal") {
                        tone = color(0.78, 0.8, 0.86)
                    } else if title.contains("plant") || title.contains("leaf") {
                        tone = color(0.42, 0.72, 0.46)
                    } else if title.contains("lamp") {
                        tone = color(1, 0.94, 0.7)
                        material.emission.contents = color(1, 0.9, 0.55)
                    } else {
                        tone = color(0.94, 0.9, 0.98)
                    }
                    material.lightingModel = .physicallyBased
                    material.diffuse.contents = tone
                    material.roughness.contents = NSNumber(value: 0.55)
                }
            }
            return root
        }
        return nil
    }

    private func woodImage() -> UIImage {
        let side = CGSize(width: 128, height: 128)
        return UIGraphicsImageRenderer(size: side).image { ctx in
            UIColor(red: 0.86, green: 0.7, blue: 0.48, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: side))
            for row in 0..<6 {
                UIColor(red: 0.62, green: 0.44, blue: 0.26, alpha: 0.45).setFill()
                ctx.fill(CGRect(x: 0, y: CGFloat(row) * 22, width: 128, height: 2))
            }
        }
    }

    private func wallpaperImage() -> UIImage {
        let side = CGSize(width: 128, height: 128)
        return UIGraphicsImageRenderer(size: side).image { ctx in
            UIColor(red: 0.93, green: 0.86, blue: 0.97, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: side))
            let stars = [(12, 20), (40, 48), (70, 18), (96, 60), (24, 88), (80, 100), (54, 72)]
            UIColor(red: 1, green: 0.95, blue: 0.7, alpha: 0.9).setFill()
            for (x, y) in stars {
                ctx.cgContext.fillEllipse(in: CGRect(x: x, y: y, width: 4, height: 4))
            }
        }
    }

    private func paint(_ ui: UIColor) -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        material.diffuse.contents = ui
        material.roughness.contents = NSNumber(value: 0.58)
        material.metalness.contents = NSNumber(value: 0.02)
        return material
    }

    private func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> UIColor {
        UIColor(red: r, green: g, blue: b, alpha: 1)
    }

    private func shifted(_ node: SCNNode, x: Float = 0, y: Float = 0, z: Float = 0) -> SCNNode {
        node.position = SCNVector3(x, y, z)
        return node
    }
}
