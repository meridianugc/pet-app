import PetCore
import SwiftUI

/// Colors for the drawn pet. Swap this file, or stop using it, when real art arrives.
struct PetPalette {
    var body: Color
    var shade: Color
    var belly: Color
    var cheek: Color
    var shell: Color
    var spot: Color
    var ink: Color
    var shine: Color

    static func make(stage: LifeStage, scheme: ColorScheme) -> PetPalette {
        let ink = Color(red: 0.28, green: 0.18, blue: 0.18)
        let shine = Color.white.opacity(scheme == .dark ? 0.28 : 0.55)
        switch stage {
        case .egg:
            return PetPalette(
                body: Color(red: 1.0, green: 0.96, blue: 0.88),
                shade: Color(red: 0.93, green: 0.82, blue: 0.62),
                belly: Color(red: 1.0, green: 0.98, blue: 0.94),
                cheek: Color(red: 0.98, green: 0.62, blue: 0.58),
                shell: Color(red: 1.0, green: 0.96, blue: 0.88),
                spot: Color(red: 0.95, green: 0.78, blue: 0.55),
                ink: ink,
                shine: shine
            )
        case .baby:
            return creature(Color(red: 1.0, green: 0.74, blue: 0.62), ink: ink, shine: shine)
        case .child:
            return creature(Color(red: 1.0, green: 0.67, blue: 0.55), ink: ink, shine: shine)
        case .teen:
            return creature(Color(red: 0.98, green: 0.58, blue: 0.52), ink: ink, shine: shine)
        case .adult:
            return creature(Color(red: 0.93, green: 0.48, blue: 0.50), ink: ink, shine: shine)
        }
    }

    private static func creature(_ body: Color, ink: Color, shine: Color) -> PetPalette {
        PetPalette(
            body: body,
            shade: body.opacity(0.82),
            belly: Color(red: 1.0, green: 0.93, blue: 0.86),
            cheek: Color(red: 0.95, green: 0.42, blue: 0.45).opacity(0.55),
            shell: body,
            spot: body,
            ink: ink,
            shine: shine
        )
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
                Color(red: 0.11, green: 0.12, blue: 0.20),
                Color(red: 0.20, green: 0.13, blue: 0.20)
            ]
        }
        return [
            Color(red: 1.0, green: 0.96, blue: 0.93),
            Color(red: 0.84, green: 0.93, blue: 0.90)
        ]
    }
}
