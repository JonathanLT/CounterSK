//
//  GameRecord.swift
//  CounterSK
//
//  Created by GitHub Copilot on 17/01/2026.
//

import Foundation
import SwiftData

@Model
final class GameRecord {
    var date: Date
    var plannedTricks: Int
    var takenTricks: Int
    var totalPoints: Int
    var rounds: Int

    init(date: Date = Date(), plannedTricks: Int = 0, takenTricks: Int = 0, totalPoints: Int = 0, rounds: Int = 0) {
        self.date = date
        self.plannedTricks = plannedTricks
        self.takenTricks = takenTricks
        self.totalPoints = totalPoints
        self.rounds = rounds
    }
}
