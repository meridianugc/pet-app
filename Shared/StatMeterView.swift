import SwiftUI

enum StatTint {
    static let fed = Color(red: 0.93, green: 0.55, blue: 0.32)
    static let happy = Color(red: 0.86, green: 0.40, blue: 0.52)
    static let energy = Color(red: 0.36, green: 0.55, blue: 0.82)
}

/// A labeled meter. Higher is better for fed, happiness, and energy.
struct StatMeterView: View {
    var title: String
    var value: Double
    var tint: Color
    var compact: Bool = false

    private var fraction: Double {
        min(1, max(0, value / 100))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 2 : 6) {
            HStack {
                Text(title)
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue("\(Int(value.rounded())) percent")
    }
}
