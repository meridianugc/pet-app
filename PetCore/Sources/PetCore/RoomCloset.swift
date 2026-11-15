import Foundation

/// One hanger or shelf spot inside the open closet.
public struct ClosetPeg: Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var spot: RoomSpot
    public var worn: Bool
    public var look: Bool

    public init(id: String, title: String, spot: RoomSpot, worn: Bool, look: Bool) {
        self.id = id
        self.title = title
        self.spot = spot
        self.worn = worn
        self.look = look
    }
}

public struct ClosetWear: Equatable, Sendable {
    public var wardrobe: Wardrobe
    public var outfitID: String?

    public init(wardrobe: Wardrobe, outfitID: String?) {
        self.wardrobe = wardrobe
        self.outfitID = outfitID
    }
}

public enum RoomCloset {
    public static let petSpot = RoomSpot(x: 0.5, y: 0.42)
    public static let petReach = 0.18

    public static func nearPet(_ spot: RoomSpot) -> Bool {
        spot.distance(to: petSpot) <= petReach
    }

    public static func pegs(wardrobe: Wardrobe, outfitID: String?, ownedIDs: [String]) -> [ClosetPeg] {
        var rows: [(id: String, title: String, worn: Bool, look: Bool)] = []
        for id in wardrobe.owned {
            guard let option = LookBook.option(id) else { continue }
            rows.append((id, option.slot.spoken, wardrobe.equipped(in: option.slot) == id, true))
        }
        for id in ownedIDs where id.hasPrefix("outfit.") {
            let title = id.split(separator: ".").last.map(String.init) ?? id
            rows.append((id, title, outfitID == id, false))
        }
        return rows.enumerated().map { index, row in
            let column = index % 4
            let line = index / 4
            let spot = RoomSpot(x: 0.18 + Double(column) * 0.2, y: 0.78 - Double(line) * 0.2)
            return ClosetPeg(id: row.id, title: row.title, spot: spot, worn: row.worn, look: row.look)
        }
    }

    /// Drag a hanger onto the pet to wear it.
    public static func dropOnPet(
        id: String,
        at spot: RoomSpot,
        wardrobe: Wardrobe,
        outfitID: String?,
        ownedIDs: [String],
        stage: LifeStage,
        form: AdultForm?
    ) -> ClosetWear? {
        guard nearPet(spot) else { return nil }
        if LookBook.option(id) != nil {
            guard case let .success(next) = LookBook.wear(id: id, wardrobe: wardrobe, stage: stage, form: form) else {
                return nil
            }
            return ClosetWear(wardrobe: next, outfitID: outfitID)
        }
        guard id.hasPrefix("outfit."), ownedIDs.contains(id) else { return nil }
        return ClosetWear(wardrobe: wardrobe, outfitID: id)
    }

    /// Drag a worn piece back to its hanger to take it off.
    public static func returnToPeg(
        id: String,
        at spot: RoomSpot,
        wardrobe: Wardrobe,
        outfitID: String?,
        ownedIDs: [String],
        stage: LifeStage,
        form: AdultForm?
    ) -> ClosetWear? {
        let pegs = pegs(wardrobe: wardrobe, outfitID: outfitID, ownedIDs: ownedIDs)
        guard let peg = pegs.first(where: { $0.id == id }), spot.distance(to: peg.spot) <= 0.12 else { return nil }
        if peg.look {
            guard peg.worn, let option = LookBook.option(id) else { return nil }
            let plain = plainID(for: option.slot)
            guard plain != id else { return nil }
            guard case let .success(next) = LookBook.wear(id: plain, wardrobe: wardrobe, stage: stage, form: form) else {
                return nil
            }
            return ClosetWear(wardrobe: next, outfitID: outfitID)
        }
        guard outfitID == id else { return nil }
        return ClosetWear(wardrobe: wardrobe, outfitID: nil)
    }

    public static func plainID(for slot: LookSlot) -> String {
        switch slot {
        case .shell: return "shell.plain"
        case .eyes: return "eyes.round"
        case .antenna: return "antenna.ball"
        case .marking: return "marking.none"
        }
    }
}
