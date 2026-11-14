import PetCore
import SwiftUI

struct PetPalette {
    var body: Color
    var shade: Color
    var belly: Color
    var cheek: Color
    var antenna: Color
    var ink: Color
    var shine: Color
    var sparkle: Color

    static func make(form: AdultForm?, scheme: ColorScheme) -> PetPalette {
        let ink = Color(red: 0.28, green: 0.20, blue: 0.42)
        let shine = Color.white.opacity(scheme == .dark ? 0.35 : 0.7)
        switch form {
        case .star:
            return PetPalette(
                body: Color(red: 0.72, green: 0.62, blue: 0.98),
                shade: Color(red: 0.55, green: 0.48, blue: 0.90),
                belly: Color(red: 0.90, green: 0.86, blue: 1),
                cheek: Color(red: 1, green: 0.62, blue: 0.74),
                antenna: Color(red: 0.62, green: 0.50, blue: 0.95),
                ink: ink,
                shine: shine,
                sparkle: Color(red: 1, green: 0.92, blue: 0.55)
            )
        case .cloud:
            return PetPalette(
                body: Color(red: 0.93, green: 0.90, blue: 1),
                shade: Color(red: 0.78, green: 0.74, blue: 0.96),
                belly: Color.white.opacity(0.85),
                cheek: Color(red: 1, green: 0.70, blue: 0.78),
                antenna: Color(red: 0.70, green: 0.62, blue: 0.95),
                ink: ink,
                shine: shine,
                sparkle: Color(red: 1, green: 0.86, blue: 0.45)
            )
        case .spiky:
            return PetPalette(
                body: Color(red: 0.48, green: 0.38, blue: 0.68),
                shade: Color(red: 0.34, green: 0.26, blue: 0.52),
                belly: Color(red: 0.62, green: 0.52, blue: 0.78),
                cheek: Color(red: 0.72, green: 0.42, blue: 0.62),
                antenna: Color(red: 0.32, green: 0.24, blue: 0.48),
                ink: Color(red: 0.16, green: 0.10, blue: 0.24),
                shine: shine,
                sparkle: Color(red: 0.85, green: 0.75, blue: 1)
            )
        case nil:
            return PetPalette(
                body: Color(red: 0.84, green: 0.78, blue: 0.98),
                shade: Color(red: 0.68, green: 0.60, blue: 0.92),
                belly: Color(red: 0.95, green: 0.92, blue: 1),
                cheek: Color(red: 1, green: 0.66, blue: 0.76),
                antenna: Color(red: 0.66, green: 0.56, blue: 0.94),
                ink: ink,
                shine: shine,
                sparkle: Color(red: 1, green: 0.88, blue: 0.45)
            )
        }
    }
}

struct PocketBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    }

    private var colors: [Color] {
        if scheme == .dark {
            return [
                Color(red: 0.12, green: 0.10, blue: 0.22),
                Color(red: 0.22, green: 0.14, blue: 0.32)
            ]
        }
        return [
            Color(red: 0.93, green: 0.90, blue: 0.99),
            Color(red: 0.84, green: 0.78, blue: 0.96)
        ]
    }
}

func alienTintColor(_ tint: TraitTint) -> Color {
    switch tint {
    case .starlight:
        return Color(red: 1, green: 0.84, blue: 0.55)
    case .mist:
        return Color(red: 0.62, green: 0.82, blue: 1)
    case .dusk:
        return Color(red: 0.62, green: 0.42, blue: 0.86)
    case .stardust:
        return Color(red: 0.96, green: 0.75, blue: 1)
    }
}
