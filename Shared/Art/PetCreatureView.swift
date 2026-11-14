import PetCore
import SwiftUI

/// The whole pet, drawn with shapes so it can be replaced with images later.
/// `animates` should be false in the widget. Widgets draw a still picture.
struct PetCreatureView: View {
    var stage: LifeStage
    var mood: PetMood
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

    private func picture(side: CGFloat, time: TimeInterval) -> some View {
        let moving = animates && !reduceMotion && time != 0
        let breathe = moving && stage != .egg ? 1 + sin(time * 1.7) * 0.018 : 1
        let wobble = moving && stage == .egg ? sin(time * 2.1) * 3.2 : 0
        let blink = blinkAmount(time: moving ? time : 0)
        return ZStack {
            Ellipse()
                .fill(Color.black.opacity(scheme == .dark ? 0.28 : 0.08))
                .frame(width: side * 0.46, height: side * 0.08)
                .offset(y: side * 0.38)
            if stage == .egg {
                EggPicture(side: side, palette: palette)
            } else {
                BlobPicture(side: side, stage: stage, mood: mood, blink: blink, palette: palette)
            }
        }
        .scaleEffect(breathe)
        .rotationEffect(.degrees(wobble))
    }

    private var palette: PetPalette {
        PetPalette.make(stage: stage, scheme: scheme)
    }

    private func blinkAmount(time: TimeInterval) -> CGFloat {
        let cycle = time.truncatingRemainder(dividingBy: 4.4)
        guard cycle > 3.55, cycle < 3.9 else { return 0 }
        let u = (cycle - 3.55) / 0.35
        return CGFloat(sin(u * .pi))
    }
}

private struct EggPicture: View {
    var side: CGFloat
    var palette: PetPalette

    var body: some View {
        ZStack {
            Ellipse()
                .fill(palette.shell)
                .overlay(Ellipse().stroke(palette.shade, lineWidth: side * 0.012))
                .frame(width: side * 0.50, height: side * 0.64)
            Ellipse()
                .fill(palette.shine)
                .frame(width: side * 0.12, height: side * 0.18)
                .offset(x: -side * 0.10, y: -side * 0.14)
            Circle()
                .fill(palette.spot)
                .frame(width: side * 0.055)
                .offset(x: side * 0.10, y: -side * 0.06)
            Circle()
                .fill(palette.spot)
                .frame(width: side * 0.04)
                .offset(x: -side * 0.11, y: side * 0.08)
            Circle()
                .fill(palette.spot)
                .frame(width: side * 0.028)
                .offset(x: side * 0.02, y: side * 0.16)
            EggCrack()
                .stroke(palette.shade, style: StrokeStyle(lineWidth: side * 0.012, lineCap: .round, lineJoin: .round))
                .frame(width: side * 0.16, height: side * 0.10)
                .offset(y: -side * 0.02)
        }
    }
}

private struct EggCrack: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.height * 0.25))
        path.addLine(to: CGPoint(x: rect.width * 0.32, y: rect.height * 0.7))
        path.addLine(to: CGPoint(x: rect.width * 0.55, y: rect.height * 0.2))
        path.addLine(to: CGPoint(x: rect.width * 0.78, y: rect.height * 0.75))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height * 0.35))
        return path
    }
}

private struct BlobPicture: View {
    var side: CGFloat
    var stage: LifeStage
    var mood: PetMood
    var blink: CGFloat
    var palette: PetPalette

    var body: some View {
        let size = bodySize
        ZStack {
            ears
            if stage == .adult {
                hair
            }
            if stage == .adult {
                Circle()
                    .fill(palette.body)
                    .frame(width: side * 0.14, height: side * 0.14)
                    .offset(x: size.width * 0.48, y: size.height * 0.18)
            }
            Ellipse()
                .fill(palette.body)
                .frame(width: size.width, height: size.height)
            Ellipse()
                .fill(palette.belly)
                .frame(width: size.width * 0.55, height: size.height * 0.42)
                .offset(y: size.height * 0.16)
            if stage != .baby {
                arms(body: size)
            }
            feet(body: size)
            FacePicture(side: side, mood: mood, blink: blink, palette: palette)
                .offset(y: -size.height * 0.08)
            if mood == .sleepy {
                SleepMarks(side: side, ink: palette.ink)
                    .offset(x: size.width * 0.42, y: -size.height * 0.42)
            }
        }
    }

    private var bodySize: CGSize {
        switch stage {
        case .egg, .baby:
            return CGSize(width: side * 0.62, height: side * 0.56)
        case .adult:
            return CGSize(width: side * 0.64, height: side * 0.74)
        }
    }

    private var ears: some View {
        HStack(spacing: side * 0.30) {
            ear
            ear
        }
        .offset(y: -bodySize.height * 0.42)
    }

    private var ear: some View {
        Circle()
            .fill(palette.body)
            .frame(width: side * 0.16, height: side * 0.16)
            .overlay(Circle().fill(palette.cheek).scaleEffect(0.45))
    }

    private var hair: some View {
        HStack(spacing: side * 0.02) {
            hairBit(side * 0.07)
            hairBit(side * 0.10)
            hairBit(side * 0.07)
        }
        .offset(y: -bodySize.height * 0.58)
    }

    private func hairBit(_ width: CGFloat) -> some View {
        Capsule()
            .fill(palette.shade)
            .frame(width: width, height: width * 1.3)
    }

    private func arms(body: CGSize) -> some View {
        HStack(spacing: body.width * 0.72) {
            Capsule().fill(palette.body).frame(width: side * 0.07, height: side * 0.16)
            Capsule().fill(palette.body).frame(width: side * 0.07, height: side * 0.16)
        }
        .offset(y: body.height * 0.08)
    }

    private func feet(body: CGSize) -> some View {
        HStack(spacing: body.width * 0.22) {
            Ellipse().fill(palette.shade).frame(width: side * 0.12, height: side * 0.07)
            Ellipse().fill(palette.shade).frame(width: side * 0.12, height: side * 0.07)
        }
        .offset(y: body.height * 0.46)
    }
}

private struct FacePicture: View {
    var side: CGFloat
    var mood: PetMood
    var blink: CGFloat
    var palette: PetPalette

    var body: some View {
        let eye = side * 0.075
        ZStack {
            HStack(spacing: side * 0.18) {
                Circle().fill(palette.cheek).frame(width: side * 0.07)
                Circle().fill(palette.cheek).frame(width: side * 0.07)
            }
            .offset(y: side * 0.02)
            VStack(spacing: side * 0.045) {
                HStack(spacing: side * 0.13) {
                    eyeView(width: eye)
                    eyeView(width: eye)
                }
                mouth
                    .frame(width: side * 0.12, height: side * 0.06)
            }
            if mood == .sad || mood == .critical {
                Circle()
                    .fill(Color(red: 0.45, green: 0.68, blue: 0.86))
                    .frame(width: side * 0.035, height: side * 0.035)
                    .offset(x: -side * 0.08, y: side * 0.02)
            }
        }
    }

    private func eyeView(width: CGFloat) -> some View {
        let open = mood != .joyful && mood != .sleepy && mood != .gone
        let tired = mood == .tired
        let closedHeight = max(2, width * 0.16)
        let openHeight = tired ? width * 0.55 : width
        let height = open ? max(closedHeight, openHeight * (1 - 0.86 * blink)) : closedHeight
        return Capsule()
            .fill(palette.ink)
            .frame(width: mood == .sleepy || mood == .gone || mood == .joyful ? width * 0.85 : width * 0.72, height: height)
            .overlay {
                if open && height > width * 0.45 {
                    Circle()
                        .fill(Color.white.opacity(0.85))
                        .frame(width: width * 0.22, height: width * 0.22)
                        .offset(x: -width * 0.12, y: -width * 0.12)
                }
            }
    }

    @ViewBuilder
    private var mouth: some View {
        if mood == .hungry {
            Ellipse().fill(palette.ink)
        } else {
            MouthCurve(frown: mood == .sad || mood == .critical)
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
        .foregroundStyle(ink.opacity(0.8))
    }
}

struct PetCreatureView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            VStack {
                PetCreatureView(stage: .egg, mood: .egging, animates: false, accessibilityLabel: "Egg")
                PetCreatureView(stage: .baby, mood: .joyful, animates: false, accessibilityLabel: "Baby")
                PetCreatureView(stage: .adult, mood: .sleepy, animates: false, accessibilityLabel: "Adult")
            }
            .padding()
            .background(PocketBackground())
            .previewDisplayName("Light")

            VStack {
                PetCreatureView(stage: .adult, mood: .sad, animates: false, accessibilityLabel: "Adult")
                PetCreatureView(stage: .baby, mood: .hungry, animates: false, accessibilityLabel: "Baby")
            }
            .padding()
            .background(PocketBackground())
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark")
        }
    }
}
