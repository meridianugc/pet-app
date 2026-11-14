import PetCore
import SwiftUI

/// The space alien, drawn with shapes so real art can replace this file later.
struct PetCreatureView: View {
    var stage: LifeStage
    var mood: PetMood
    var form: AdultForm? = nil
    var tint: TraitTint? = nil
    var outfit: String? = nil
    var animates: Bool = true
    var accessibilityLabel: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Group {
            if animates && !reduceMotion {
                TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { timeline in
                    framed(time: timeline.date.timeIntervalSinceReferenceDate)
                }
            } else {
                framed(time: 0)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isImage)
        .accessibilityLabel(accessibilityLabel)
    }

    private func framed(time: TimeInterval) -> some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                GeometryReader { geo in
                    let side = min(geo.size.width, geo.size.height)
                    picture(side: side, time: time)
                        .frame(width: side, height: side)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                }
            }
    }

    private var shownForm: AdultForm? {
        stage == .adult ? (form ?? .star) : nil
    }

    private func picture(side: CGFloat, time: TimeInterval) -> some View {
        let moving = animates && !reduceMotion && time != 0
        let bob = moving ? sin(time * 1.6) * side * 0.025 : 0
        let blink = blinkAmount(time: moving ? time : 0)
        let palette = PetPalette.make(form: shownForm, scheme: scheme)
        return ZStack {
            Ellipse()
                .fill(Color.black.opacity(scheme == .dark ? 0.28 : 0.08))
                .frame(width: side * 0.42, height: side * 0.07)
                .offset(y: side * 0.38)
            if let tint {
                Circle()
                    .fill(alienTintColor(tint).opacity(0.45))
                    .frame(width: side * 0.72, height: side * 0.72)
                    .blur(radius: side * 0.04)
            }
            if stage == .egg {
                StarEgg(side: side, palette: palette)
            } else {
                AlienBody(
                    side: side,
                    form: shownForm,
                    mood: mood,
                    blink: blink,
                    palette: palette,
                    sparkle: moving ? 0.55 + 0.45 * abs(sin(time * 2.2)) : 0.8,
                    outfit: outfit
                )
            }
        }
        .offset(y: bob)
    }

    private func blinkAmount(time: TimeInterval) -> CGFloat {
        let cycle = time.truncatingRemainder(dividingBy: 4.2)
        guard cycle > 3.45, cycle < 3.8 else { return 0 }
        return CGFloat(sin((cycle - 3.45) / 0.35 * .pi))
    }
}

private struct StarEgg: View {
    var side: CGFloat
    var palette: PetPalette

    var body: some View {
        ZStack {
            Ellipse()
                .fill(palette.body)
                .overlay(Ellipse().stroke(palette.shade, lineWidth: side * 0.012))
                .frame(width: side * 0.48, height: side * 0.64)
            Ellipse()
                .fill(palette.shine)
                .frame(width: side * 0.12, height: side * 0.18)
                .offset(x: -side * 0.08, y: -side * 0.12)
            speck(side * 0.045, x: side * 0.08, y: -side * 0.08)
            speck(side * 0.03, x: -side * 0.09, y: side * 0.02)
            speck(side * 0.025, x: side * 0.02, y: side * 0.14)
            speck(side * 0.02, x: -side * 0.02, y: -side * 0.16)
            MiniStar(color: palette.sparkle)
                .frame(width: side * 0.07, height: side * 0.07)
                .offset(x: side * 0.1, y: side * 0.05)
            MiniStar(color: palette.sparkle)
                .frame(width: side * 0.05, height: side * 0.05)
                .offset(x: -side * 0.07, y: side * 0.1)
        }
    }

    private func speck(_ size: CGFloat, x: CGFloat, y: CGFloat) -> some View {
        Circle()
            .fill(palette.sparkle)
            .frame(width: size, height: size)
            .offset(x: x, y: y)
    }
}

private struct AlienBody: View {
    var side: CGFloat
    var form: AdultForm?
    var mood: PetMood
    var blink: CGFloat
    var palette: PetPalette
    var sparkle: Double
    var outfit: String? = nil

    var body: some View {
        ZStack {
            antennae
            bodyShape
            if form == .star || form == .cloud {
                MiniStar(color: palette.sparkle.opacity(sparkle))
                    .frame(width: side * 0.08, height: side * 0.08)
                    .offset(x: side * 0.22, y: -side * 0.16)
                MiniStar(color: palette.sparkle.opacity(sparkle))
                    .frame(width: side * 0.05, height: side * 0.05)
                    .offset(x: -side * 0.24, y: side * 0.02)
            }
            AlienFace(side: side, mood: mood, blink: blink, grumpy: form == .spiky, palette: palette)
                .offset(y: form == .cloud ? side * 0.02 : -side * 0.02)
            accessory
            if mood == .sleepy {
                SleepMarks(side: side, ink: palette.ink)
                    .offset(x: side * 0.28, y: -side * 0.32)
            }
        }
    }

    private var antennae: some View {
        HStack(spacing: side * 0.22) {
            Antenna(side: side, lean: -1, color: palette.antenna)
            Antenna(side: side, lean: 1, color: palette.antenna)
        }
        .offset(y: -side * (form == .star ? 0.34 : 0.30))
    }

    @ViewBuilder
    private var bodyShape: some View {
        switch form {
        case .star:
            StarShape()
                .fill(palette.body)
                .overlay(StarShape().stroke(palette.shade, lineWidth: side * 0.012))
                .frame(width: side * 0.72, height: side * 0.72)
        case .cloud:
            ZStack {
                puff(side * 0.34, x: -side * 0.12, y: side * 0.04)
                puff(side * 0.36, x: side * 0.12, y: side * 0.02)
                puff(side * 0.28, x: 0, y: -side * 0.12)
                puff(side * 0.42, x: 0, y: side * 0.08)
            }
        case .spiky:
            SpikyShape()
                .fill(palette.body)
                .overlay(SpikyShape().stroke(palette.shade, lineWidth: side * 0.01))
                .frame(width: side * 0.78, height: side * 0.78)
        case nil:
            ZStack {
                Ellipse()
                    .fill(palette.body)
                    .frame(width: side * 0.58, height: side * 0.52)
                Ellipse()
                    .fill(palette.belly)
                    .frame(width: side * 0.32, height: side * 0.22)
                    .offset(y: side * 0.08)
                HStack(spacing: side * 0.16) {
                    Ellipse().fill(palette.shade).frame(width: side * 0.1, height: side * 0.06)
                    Ellipse().fill(palette.shade).frame(width: side * 0.1, height: side * 0.06)
                }
                .offset(y: side * 0.24)
            }
        }
    }

    @ViewBuilder
    private var accessory: some View {
        switch outfit {
        case "outfit.scarf":
            Capsule()
                .fill(Color(red: 0.95, green: 0.45, blue: 0.55))
                .frame(width: side * 0.28, height: side * 0.08)
                .offset(y: side * 0.12)
        case "outfit.bow":
            HStack(spacing: 0) {
                Circle().frame(width: side * 0.08, height: side * 0.08)
                Circle().frame(width: side * 0.045, height: side * 0.045)
                Circle().frame(width: side * 0.08, height: side * 0.08)
            }
            .foregroundStyle(Color(red: 1, green: 0.55, blue: 0.72))
            .offset(y: -side * 0.02)
        case "outfit.helmet":
            Capsule()
                .stroke(Color(red: 0.75, green: 0.82, blue: 0.95), lineWidth: side * 0.015)
                .background(Capsule().fill(Color.white.opacity(0.25)))
                .frame(width: side * 0.34, height: side * 0.16)
                .offset(y: -side * 0.08)
        default:
            EmptyView()
        }
    }

    private func puff(_ size: CGFloat, x: CGFloat, y: CGFloat) -> some View {
        Circle()
            .fill(palette.body)
            .frame(width: size, height: size)
            .offset(x: x, y: y)
    }
}

private struct Antenna: View {
    var side: CGFloat
    var lean: CGFloat
    var color: Color

    var body: some View {
        VStack(spacing: 0) {
            Circle()
                .fill(color)
                .frame(width: side * 0.075, height: side * 0.075)
            Capsule()
                .fill(color)
                .frame(width: side * 0.028, height: side * 0.11)
        }
        .rotationEffect(.degrees(Double(lean) * 16))
    }
}

private struct AlienFace: View {
    var side: CGFloat
    var mood: PetMood
    var blink: CGFloat
    var grumpy: Bool
    var palette: PetPalette

    var body: some View {
        let eye = side * 0.09
        ZStack {
            HStack(spacing: side * 0.16) {
                Circle().fill(palette.cheek.opacity(0.85)).frame(width: side * 0.07)
                Circle().fill(palette.cheek.opacity(0.85)).frame(width: side * 0.07)
            }
            .offset(y: side * 0.035)
            VStack(spacing: side * 0.03) {
                HStack(spacing: side * 0.11) {
                    eyeView(width: eye)
                    eyeView(width: eye)
                }
                mouth
                    .frame(width: side * 0.11, height: side * 0.055)
            }
            if mood == .sad || mood == .critical {
                Circle()
                    .fill(Color(red: 0.55, green: 0.72, blue: 0.95))
                    .frame(width: side * 0.03, height: side * 0.03)
                    .offset(x: -side * 0.07, y: side * 0.02)
            }
        }
    }

    private func eyeView(width: CGFloat) -> some View {
        let closed = mood == .sleepy || mood == .gone || mood == .joyful
        let openHeight = mood == .tired ? width * 0.55 : width
        let height = closed ? max(2, width * 0.16) : max(2, openHeight * (1 - 0.86 * blink))
        return ZStack {
            Capsule()
                .fill(palette.ink)
                .frame(width: width * 0.78, height: height)
            if !closed, height > width * 0.4 {
                Circle()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: width * 0.22, height: width * 0.22)
                    .offset(x: -width * 0.12, y: -width * 0.14)
            }
            if grumpy, mood != .sleepy, mood != .gone {
                Capsule()
                    .fill(palette.ink)
                    .frame(width: width * 0.7, height: max(2, width * 0.12))
                    .rotationEffect(.degrees(-18))
                    .offset(y: -width * 0.55)
            }
        }
    }

    @ViewBuilder
    private var mouth: some View {
        if mood == .hungry {
            Ellipse().fill(palette.ink)
        } else {
            let frown = mood == .sad || mood == .critical || (grumpy && mood != .joyful)
            MouthCurve(frown: frown)
                .stroke(palette.ink, style: StrokeStyle(lineWidth: max(2, side * 0.012), lineCap: .round))
        }
    }
}

private struct MouthCurve: Shape {
    var frown: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: frown ? rect.maxY : rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: frown ? rect.maxY : rect.minY),
            control: CGPoint(x: rect.midX, y: frown ? rect.minY : rect.maxY)
        )
        return path
    }
}

private struct StarShape: Shape {
    func path(in rect: CGRect) -> Path {
        starPath(in: rect, points: 5, innerRatio: 0.46)
    }
}

private struct SpikyShape: Shape {
    func path(in rect: CGRect) -> Path {
        starPath(in: rect, points: 12, innerRatio: 0.78)
    }
}

private func starPath(in rect: CGRect, points: Int, innerRatio: CGFloat) -> Path {
    let center = CGPoint(x: rect.midX, y: rect.midY)
    let outer = min(rect.width, rect.height) / 2
    let inner = outer * innerRatio
    var path = Path()
    let count = points * 2
    for index in 0..<count {
        let angle = (CGFloat(index) * .pi / CGFloat(points)) - .pi / 2
        let radius = index.isMultiple(of: 2) ? outer : inner
        let point = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
        if index == 0 {
            path.move(to: point)
        } else {
            path.addLine(to: point)
        }
    }
    path.closeSubpath()
    return path
}

private struct MiniStar: View {
    var color: Color

    var body: some View {
        StarShape().fill(color)
    }
}

private struct SleepMarks: View {
    var side: CGFloat
    var ink: Color

    var body: some View {
        HStack(alignment: .bottom, spacing: 1) {
            Text("z")
            Text("z")
            Text("Z")
        }
        .font(.system(size: side * 0.07, weight: .bold, design: .rounded))
        .foregroundStyle(ink.opacity(0.75))
    }
}

struct PetCreatureView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            HStack {
                PetCreatureView(stage: .egg, mood: .egging, animates: false, accessibilityLabel: "Egg")
                PetCreatureView(stage: .baby, mood: .joyful, animates: false, accessibilityLabel: "Baby")
                PetCreatureView(stage: .adult, mood: .joyful, form: .star, animates: false, accessibilityLabel: "Star")
            }
            .padding()
            .background(PocketBackground())
            HStack {
                PetCreatureView(stage: .adult, mood: .joyful, form: .cloud, animates: false, accessibilityLabel: "Cloud")
                PetCreatureView(stage: .adult, mood: .sad, form: .spiky, animates: false, accessibilityLabel: "Spiky")
            }
            .padding()
            .background(PocketBackground())
            .preferredColorScheme(.dark)
        }
    }
}
