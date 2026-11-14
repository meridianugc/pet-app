import SwiftUI
import PetCore

enum StatTint {
    static let fed = Color(red: 0.93, green: 0.55, blue: 0.32)
    static let happy = Color(red: 0.86, green: 0.40, blue: 0.52)
    static let energy = Color(red: 0.36, green: 0.55, blue: 0.82)
}

/// A labeled meter. Higher is better for fed, happiness, and energy.
struct StatMeterView: View {
    var stat: CareStat
    var value: Double
    var tint: Color
    var compact: Bool = false
    var pop: Int? = nil

    private var fraction: Double {
        min(1, max(0, value / 100))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 2 : 6) {
            HStack(spacing: 6) {
                CareGlyph(stat: stat, side: compact ? 14 : 22)
                Spacer(minLength: 8)
                Text("\(Int(value.rounded()))")
                    .monospacedDigit()
            }
            .font(compact ? .caption : .subheadline)
            .foregroundStyle(.primary)

            Capsule()
                .fill(tint.opacity(0.22))
                .overlay(alignment: .leading) {
                    GeometryReader { geo in
                        Capsule()
                            .fill(tint)
                            .frame(width: geo.size.width * fraction)
                    }
                }
                .frame(height: compact ? 8 : 14)
        }
        .overlay(alignment: .topTrailing) {
            if let pop {
                ChipFace(chip: CareChip(stat: stat, amount: pop), side: compact ? 14 : 20)
                    .offset(y: compact ? -16 : -22)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(stat.spokenName)
        .accessibilityValue("\(Int(value.rounded())) percent")
    }
}

struct ChipFace: View {
    var chip: CareChip
    var side: CGFloat = 18

    var body: some View {
        HStack(spacing: 3) {
            CareGlyph(stat: chip.stat, side: side)
            if chip.stat != .look, chip.stat != .sky {
                Text(chip.amount > 0 ? "+\(chip.amount)" : "\(chip.amount)")
                    .font(.system(size: side * 0.72, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.82))
                .shadow(color: .black.opacity(0.08), radius: 3, y: 2)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(chip.stat.spokenName) plus \(chip.amount)")
    }
}

struct CareGlyph: View {
    var stat: CareStat
    var side: CGFloat = 22

    var body: some View {
        ZStack {
            Circle()
                .fill(fill)
                .overlay(Circle().stroke(Color.white.opacity(0.8), lineWidth: max(1, side * 0.06)))
            Circle()
                .fill(Color.white.opacity(0.55))
                .frame(width: side * 0.28, height: side * 0.28)
                .offset(x: -side * 0.16, y: -side * 0.16)
            symbol
        }
        .frame(width: side, height: side)
        .shadow(color: fill.opacity(0.45), radius: side * 0.12, y: side * 0.06)
        .accessibilityHidden(true)
    }

    private var fill: Color {
        switch stat {
        case .fed: return Color(red: 1, green: 0.55, blue: 0.68)
        case .happy: return Color(red: 1, green: 0.42, blue: 0.55)
        case .energy, .sleep: return Color(red: 0.55, green: 0.48, blue: 0.95)
        case .gems: return Color(red: 1, green: 0.82, blue: 0.35)
        case .look: return Color(red: 0.98, green: 0.55, blue: 0.75)
        case .sky: return Color(red: 0.55, green: 0.75, blue: 1)
        }
    }

    @ViewBuilder
    private var symbol: some View {
        switch stat {
        case .fed:
            Circle()
                .fill(Color(red: 0.95, green: 0.35, blue: 0.55))
                .frame(width: side * 0.42, height: side * 0.42)
                .offset(y: side * 0.04)
            Capsule()
                .fill(Color(red: 0.45, green: 0.75, blue: 0.45))
                .frame(width: side * 0.1, height: side * 0.22)
                .offset(y: -side * 0.22)
        case .happy:
            HeartMark()
                .fill(Color.white)
                .frame(width: side * 0.46, height: side * 0.4)
        case .energy, .sleep:
            Circle()
                .fill(Color(red: 1, green: 0.95, blue: 0.7))
                .frame(width: side * 0.38, height: side * 0.38)
                .offset(x: side * 0.06)
            Circle()
                .fill(fill)
                .frame(width: side * 0.32, height: side * 0.32)
                .offset(x: side * 0.14)
        case .gems:
            GemMark()
                .fill(Color.white)
                .frame(width: side * 0.36, height: side * 0.46)
        case .look:
            HStack(spacing: 0) {
                Circle().frame(width: side * 0.18)
                Circle().frame(width: side * 0.1)
                Circle().frame(width: side * 0.18)
            }
            .foregroundStyle(Color.white)
        case .sky:
            HStack(spacing: -side * 0.06) {
                Circle().frame(width: side * 0.2)
                Circle().frame(width: side * 0.28)
                Circle().frame(width: side * 0.18)
            }
            .foregroundStyle(Color.white)
            .offset(y: side * 0.04)
        }
    }
}

private struct HeartMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        path.move(to: CGPoint(x: w * 0.5, y: h))
        path.addCurve(
            to: CGPoint(x: 0, y: h * 0.32),
            control1: CGPoint(x: w * 0.15, y: h * 0.72),
            control2: CGPoint(x: 0, y: h * 0.55)
        )
        path.addArc(
            center: CGPoint(x: w * 0.25, y: h * 0.28),
            radius: w * 0.25,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: false
        )
        path.addArc(
            center: CGPoint(x: w * 0.75, y: h * 0.28),
            radius: w * 0.25,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: false
        )
        path.addCurve(
            to: CGPoint(x: w * 0.5, y: h),
            control1: CGPoint(x: w, y: h * 0.55),
            control2: CGPoint(x: w * 0.85, y: h * 0.72)
        )
        return path
    }
}

private struct GemMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY * 0.7))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY * 0.7))
        path.closeSubpath()
        return path
    }
}

extension CareStat {
    var spokenName: String {
        switch self {
        case .fed: return "Fed"
        case .happy: return "Happy"
        case .energy: return "Energy"
        case .gems: return "Star gems"
        case .sleep: return "Sleep"
        case .look: return "Look"
        case .sky: return "Sky"
        }
    }
}
