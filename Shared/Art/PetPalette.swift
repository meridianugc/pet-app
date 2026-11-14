import PetCore
import SwiftUI
import UIKit

/// Catalog images ship under these names. Missing art falls back to the drawn shapes.
enum GameArt {
    static let alienEgg = "alien_egg"
    static let alienBabyHappy = "alien_baby_happy"
    static let alienBabySad = "alien_baby_sad"
    static let alienBabySleep = "alien_baby_sleep"
    static let alienBabyEat = "alien_baby_eat"
    static let alienStar = "alien_star"
    static let alienCloud = "alien_cloud"
    static let alienSpiky = "alien_spiky"
    static let gemStar = "gem_star"
    static let gemMoon = "gem_moon"
    static let gemPlanet = "gem_planet"
    static let gemComet = "gem_comet"
    static let gemDonut = "gem_donut"
    static let gemHeart = "gem_heart"
    static let gemLineblast = "gem_lineblast"
    static let gemStarbomb = "gem_starbomb"
    static let platformCloud = "platform_cloud"
    static let platformAsteroid = "platform_asteroid"
    static let platformBreaking = "platform_breaking"
    static let spring = "spring"
    static let gemPickup = "gem_pickup"
    static let iconFed = "icon_fed"
    static let iconHappy = "icon_happy"
    static let iconEnergy = "icon_energy"
    static let iconGem = "icon_gem"
    static let bgHome = "bg_home"
    static let bgMatch = "bg_match"
    static let bgHopper = "bg_hopper"
    static let bgMerge = "bg_merge"
    static let bgShop = "bg_shop"

    static func planet(_ index: Int) -> String { "planet_\(min(8, max(1, index)))" }

    static func uiImage(_ name: String) -> UIImage? {
        UIImage(named: name)
    }

    static func image(_ name: String) -> Image? {
        guard uiImage(name) != nil else { return nil }
        return Image(name)
    }
}

struct CatalogImage<Fallback: View>: View {
    var name: String
    @ViewBuilder var fallback: () -> Fallback

    var body: some View {
        if let image = GameArt.image(name) {
            image.resizable().scaledToFit()
        } else {
            fallback()
        }
    }
}

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
    var theme: String? = nil
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let image = GameArt.image(backgroundName) {
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                    LinearGradient(
                        colors: [Color.black.opacity(0.28), Color.black.opacity(0.12), Color.black.opacity(0.34)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                } else {
                    LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
                }
                starfield
            }
        }
    }

    private var starfield: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 12.0)) { timeline in
                Canvas { context, size in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    for index in 0..<16 {
                        let x = CGFloat((index * 53) % 97) / 97 * size.width
                        let y = CGFloat((index * 37) % 91) / 91 * size.height
                        let twinkle = 0.25 + 0.75 * abs(sin(time * 1.3 + Double(index)))
                        let dot = CGRect(x: x, y: y, width: 3, height: 3)
                        context.fill(Path(ellipseIn: dot), with: .color(.white.opacity(twinkle)))
                    }
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var backgroundName: String {
        switch theme {
        case "bg_match", "match": return GameArt.bgMatch
        case "bg_hopper", "hopper": return GameArt.bgHopper
        case "bg_merge", "merge": return GameArt.bgMerge
        case "bg_shop", "shop": return GameArt.bgShop
        default: return GameArt.bgHome
        }
    }

    private var colors: [Color] {
        if theme == "room.starfield" {
            return [
                Color(red: 0.10, green: 0.10, blue: 0.28),
                Color(red: 0.18, green: 0.16, blue: 0.40)
            ]
        }
        if theme == "room.nebula" {
            return scheme == .dark
                ? [Color(red: 0.28, green: 0.14, blue: 0.32), Color(red: 0.45, green: 0.28, blue: 0.55)]
                : [Color(red: 0.98, green: 0.86, blue: 0.95), Color(red: 0.78, green: 0.70, blue: 0.98)]
        }
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
