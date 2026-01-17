//
//  PlayerProfile.swift
//  CounterSK
//
//  Created by Jonathan LOQUET on 17/01/2026.
//

import Foundation
import SwiftData

@Model
final class PlayerProfile {
    var name: String
    var lastPlayedAt: Date
    var playedCount: Int
    // Persistent cumulative points (sum of points across saved games)
    var cumulativePoints: Int

    init(name: String, lastPlayedAt: Date = Date(), playedCount: Int = 1, cumulativePoints: Int = 0) {
        self.name = name
        self.lastPlayedAt = lastPlayedAt
        self.playedCount = playedCount
        self.cumulativePoints = cumulativePoints
    }
}
