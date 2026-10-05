#if DEBUG
import SwiftUI

/// Sample players for `-campaignBoard` and `-campaignFaces`, never sent anywhere.
extension Ladder.CampaignBoard {
    /// A dozen players along the road, the reader sixth.
    static var sample: Self {
        let players: [(String, Int, Int, String?, String?, String?)] = [
            ("Giulia", 30, 84, "crown", "oro", "fiori"), ("Marco", 26, 71, "medalDiamond", nil, nil),
            ("Élodie", 23, 62, "settebello", "mare", nil), ("Salvo", 20, 55, "sail", "terracotta", "corda"),
            ("Nonna Pina", 18, 47, "heart", "lavanda", nil), ("Théo", 15, 40, nil, nil, nil),
            ("Ada", 13, 33, "star", "iride", nil), ("Renzo", 11, 27, "espresso", nil, "onde"),
            ("Bea", 8, 19, "moon", "rubino", nil), ("Tommaso", 6, 12, "leaf", "oliva", nil),
            ("Chiara", 4, 7, nil, "notte", nil), ("Luca", 2, 2, nil, nil, nil),
        ]
        let top = players.enumerated().map { index, player in
            Row(id: "sample-\(index)", name: player.0, stage: player.1, stars: player.2, mark: player.3,
                livery: player.4, cornice: player.5)
        }
        return .init(top: top, you: .init(played: 318, rank: 6, percentile: 98))
    }

    /// Four of the same players, the reader third among them.
    static var friendsSample: Self {
        let top = [1, 3, 5, 8].map { sample.top[$0] }
        return .init(top: top, you: .init(played: top.count, rank: 3, percentile: nil))
    }
}

extension Ladder.CampaignTable {
    /// A few tables along the first regions with people at them, friends first.
    static var samples: [Int: Self] {
        let tables: [(Int, Int, [(String, String?, String?, Bool)])] = [
            (1, 2, [("Pietro", nil, "mare", false), ("Sofia", "leaf", nil, false)]),
            (3, 1, [("Luca", nil, nil, false)]),
            (5, 7, [("Bea", "moon", "rubino", true), ("Matteo", "bolt", nil, false), ("Ines", nil, "lavanda", false)]),
            (8, 2, [("Tommaso", "leaf", "oliva", false), ("Greta", "heart", nil, false)]),
            (10, 4, [("Chiara", nil, "notte", false), ("Dario", "star", "oro", false), ("Nina", nil, nil, false)]),
            (11, 1, [("Renzo", "espresso", nil, true)]),
            (13, 3, [("Ada", "star", "iride", false), ("Paolo", nil, "terracotta", false), ("Lia", "sun", nil, false)]),
            (18, 2, [("Nonna Pina", "heart", "lavanda", false), ("Ugo", nil, nil, false)]),
            (20, 1, [("Salvo", "sail", "terracotta", true)]),
            (26, 1, [("Marco", "medalDiamond", nil, true)]),
            (30, 3, [("Giulia", "crown", "oro", false), ("Élodie", "settebello", "mare", false)]),
        ]
        return Dictionary(uniqueKeysWithValues: tables.map { stage, count, faces in
            let drawn = faces.map { Ladder.CampaignFace(id: "face-\(stage)-\($0.0)", name: $0.0, mark: $0.1,
                                                        livery: $0.2, cornice: nil, friend: $0.3) }
            return (stage, Self(stage: stage, count: count, faces: drawn))
        })
    }
}

#Preview {
    CampaignBoardSheet(store: TableStore())
}
#endif
