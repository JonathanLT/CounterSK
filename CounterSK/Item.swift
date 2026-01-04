//
//  Item.swift
//  CounterSK
//
//  Created by Jonathan LOQUET on 04/01/2026.
//

import Foundation
import SwiftData

@Model
final class Item {
    var name: String
    var timestamp: Date
    var plannedTricks: Int
    var tricksTaken: Int
    var points: Int
    // Extra bonus points (from Bonus modal)
    var extraBonus: Int
    // Persistent ordering index for players (used for reordering in the UI)
    var order: Int
    
    init(name:String, timestamp: Date = Date(), plannedTricks: Int = 0, tricksTaken: Int = 0, points: Int = 0, extraBonus: Int = 0, order: Int = 0) {
        self.name = name
        self.timestamp = timestamp
        self.plannedTricks = plannedTricks
        self.tricksTaken = tricksTaken
        self.points = points
        self.extraBonus = extraBonus
        self.order = order
    }

    // Compute points for a single round based on plannedTricks and tricksTaken.
    // Scoring rules:
    //  - If player bid 0 and took 0 -> award = 10 * numberOfCards (full round points)
    //  - Else if player planned 0 but took !=0 -> penalty = -full round points
    //  - Else if player took exactly the planned tricks -> award = 20 * planned + extraBonus
    //  - Otherwise -> penalty = -(abs(taken - planned) * 10)
    func roundPoints(round: Int, planned: Int, taken: Int) -> Int {
        // 'round' is used as the number of cards for this round
        if planned == 0 && taken == 0 {
            return max(0, round) * 10
        } else if planned == 0 && taken != 0  {
            return -(max(0, round) * 10)
        } else if taken == planned {
            return 20 * planned + extraBonus
        } else {
            return -(abs(taken - planned) * 10)
        }
    }
}
