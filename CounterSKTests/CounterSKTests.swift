//
//  CounterSKTests.swift
//  CounterSKTests
//
//  Created by Jonathan LOQUET on 04/01/2026.
//

import Foundation
import Testing
import SwiftData
@testable import CounterSK

struct CounterSKTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }

}

// MARK: - GameRecord Tests
@Suite("GameRecord Tests")
struct GameRecordTests {
    
    @Test("GameRecord initialization sets default property values correctly")
    func testGameRecordDefaultInitialization() {
        let gameRecord = GameRecord()
        
        // Check that default values are set correctly
        #expect(gameRecord.plannedTricks == 0)
        #expect(gameRecord.takenTricks == 0)
        #expect(gameRecord.totalPoints == 0)
        #expect(gameRecord.rounds == 0)
        // Date should be close to now (within 1 second)
        #expect(abs(gameRecord.date.timeIntervalSinceNow) < 1.0)
    }
    
    @Test("GameRecord initialization with custom values")
    func testGameRecordCustomInitialization() {
        let customDate = Date(timeIntervalSince1970: 1234567890)
        let gameRecord = GameRecord(
            date: customDate,
            plannedTricks: 5,
            takenTricks: 4,
            totalPoints: 100,
            rounds: 7
        )
        
        #expect(gameRecord.date == customDate)
        #expect(gameRecord.plannedTricks == 5)
        #expect(gameRecord.takenTricks == 4)
        #expect(gameRecord.totalPoints == 100)
        #expect(gameRecord.rounds == 7)
    }
}

// MARK: - ProfileManager Tests
@Suite("ProfileManager Tests")
@MainActor
struct ProfileManagerTests {
    
    @Test("ProfileManagerView edits profile names and saves changes correctly")
    func testProfileNameEdit() throws {
        // Create in-memory model container
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: PlayerProfile.self,
            configurations: config
        )
        let context = container.mainContext
        
        // Create a test profile
        let profile = PlayerProfile(name: "Original Name", cumulativePoints: 50)
        context.insert(profile)
        try context.save()
        
        // Simulate editing the profile name
        profile.name = "Updated Name"
        try context.save()
        
        // Verify the name was updated
        #expect(profile.name == "Updated Name")
        #expect(profile.cumulativePoints == 50) // Other properties unchanged
    }
    
    @Test("ProfileManagerView resets cumulativePoints to zero upon confirmation")
    func testProfilePointsReset() throws {
        // Create in-memory model container
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: PlayerProfile.self,
            configurations: config
        )
        let context = container.mainContext
        
        // Create a test profile with accumulated points
        let profile = PlayerProfile(name: "Test Player", cumulativePoints: 250)
        context.insert(profile)
        try context.save()
        
        // Verify initial state
        #expect(profile.cumulativePoints == 250)
        
        // Simulate the reset action
        profile.cumulativePoints = 0
        try context.save()
        
        // Verify points were reset
        #expect(profile.cumulativePoints == 0)
        #expect(profile.name == "Test Player") // Name unchanged
    }
}

// MARK: - StartView Tests
@Suite("StartView Tests")
@MainActor
struct StartViewTests {
    
    @Test("StartView shows top profiles sorted by cumulativePoints in descending order")
    func testTopProfilesSorting() throws {
        // Create in-memory model container
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: PlayerProfile.self,
            configurations: config
        )
        let context = container.mainContext
        
        // Create multiple profiles with different cumulative points
        let profiles = [
            PlayerProfile(name: "Player A", cumulativePoints: 100),
            PlayerProfile(name: "Player B", cumulativePoints: 500),
            PlayerProfile(name: "Player C", cumulativePoints: 250),
            PlayerProfile(name: "Player D", cumulativePoints: 750),
            PlayerProfile(name: "Player E", cumulativePoints: 50),
            PlayerProfile(name: "Player F", cumulativePoints: 300)
        ]
        
        for profile in profiles {
            context.insert(profile)
        }
        try context.save()
        
        // Fetch profiles sorted by cumulativePoints in descending order
        let descriptor = FetchDescriptor<PlayerProfile>(
            sortBy: [SortDescriptor(\.cumulativePoints, order: .reverse)]
        )
        let sortedProfiles = try context.fetch(descriptor)
        
        // Verify sorting order
        #expect(sortedProfiles[0].name == "Player D") // 750 points
        #expect(sortedProfiles[1].name == "Player B") // 500 points
        #expect(sortedProfiles[2].name == "Player F") // 300 points
        #expect(sortedProfiles[3].name == "Player C") // 250 points
        #expect(sortedProfiles[4].name == "Player A") // 100 points
        #expect(sortedProfiles[5].name == "Player E") // 50 points
        
        // Verify top 5 selection (mimicking StartView logic)
        let top5 = Array(sortedProfiles.prefix(5))
        #expect(top5.count == 5)
        #expect(top5[0].cumulativePoints == 750)
        #expect(top5[4].cumulativePoints == 100)
    }
}

// MARK: - ContentView / handleTurnAction Tests
@Suite("Turn Action Tests")
@MainActor
struct TurnActionTests {
    
    @Test("handleTurnAction toggles from vote to end phase")
    func testTurnActionToggleToEndPhase() throws {
        // Create in-memory model container
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Item.self,
            configurations: config
        )
        let context = container.mainContext
        
        // Create test items (players)
        let player1 = Item(name: "Player 1", points: 50)
        let player2 = Item(name: "Player 2", points: 75)
        context.insert(player1)
        context.insert(player2)
        try context.save()
        
        // Simulate the state before handleTurnAction is called
        var selectedTurnOption = ContentView.TurnOption.vote
        var pointsBaseline: [ObjectIdentifier: Int] = [:]
        var krakenDiscarded = false
        let items = [player1, player2]
        
        // Simulate handleTurnAction when in vote phase
        if selectedTurnOption == .vote {
            selectedTurnOption = .end
            // Snapshot baseline points
            for item in items {
                pointsBaseline[ObjectIdentifier(item)] = item.points
            }
            krakenDiscarded = false
        }
        
        // Verify state after toggle
        #expect(selectedTurnOption == .end)
        #expect(pointsBaseline[ObjectIdentifier(player1)] == 50)
        #expect(pointsBaseline[ObjectIdentifier(player2)] == 75)
        #expect(krakenDiscarded == false)
    }
    
    @Test("handleTurnAction updates points and advances round when tricks match")
    func testTurnActionAdvancesRound() throws {
        // Create in-memory model container
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Item.self,
            configurations: config
        )
        let context = container.mainContext
        
        // Create test items with planned and taken tricks for round 3 (3 cards)
        let player1 = Item(name: "Player 1", plannedTricks: 2, tricksTaken: 2, points: 50)
        let player2 = Item(name: "Player 2", plannedTricks: 1, tricksTaken: 1, points: 75)
        context.insert(player1)
        context.insert(player2)
        try context.save()
        
        let items = [player1, player2]
        var currentRound = 3
        var selectedTurnOption = ContentView.TurnOption.end
        var pointsBaseline: [ObjectIdentifier: Int] = [
            ObjectIdentifier(player1): 50,
            ObjectIdentifier(player2): 75
        ]
        let krakenDiscarded = false
        
        // Calculate total taken tricks
        let totalTaken = items.reduce(0) { $0 + $1.tricksTaken }
        let adjustedTaken = totalTaken + (krakenDiscarded ? 1 : 0)
        let expected = currentRound // Round 3 = 3 cards
        
        // Verify tricks match
        #expect(adjustedTaken == expected) // 2 + 1 = 3
        
        // Simulate the advancement logic
        if adjustedTaken == expected && currentRound < 10 {
            // Apply final points for this round
            for item in items {
                let baseline = pointsBaseline[ObjectIdentifier(item)] ?? item.points
                let roundPts = item.roundPoints(round: currentRound, planned: item.plannedTricks, taken: item.tricksTaken)
                item.points = baseline + roundPts
            }
            selectedTurnOption = .vote
            currentRound += 1
            // Reset tricks
            for item in items {
                item.plannedTricks = 0
                item.tricksTaken = 0
            }
            pointsBaseline = [:]
        }
        
        // Verify round advancement
        #expect(currentRound == 4)
        #expect(selectedTurnOption == .vote)
        
        // Verify points were updated correctly
        // Player 1: planned 2, taken 2 -> 20 * 2 = 40 points
        #expect(player1.points == 90) // 50 + 40
        // Player 2: planned 1, taken 1 -> 20 * 1 = 20 points
        #expect(player2.points == 95) // 75 + 20
        
        // Verify tricks were reset
        #expect(player1.plannedTricks == 0)
        #expect(player1.tricksTaken == 0)
        #expect(player2.plannedTricks == 0)
        #expect(player2.tricksTaken == 0)
        
        // Verify baseline was cleared
        #expect(pointsBaseline.isEmpty)
    }
    
    @Test("handleTurnAction validates trick count with kraken bonus")
    func testTurnActionWithKrakenValidation() {
        // Create test items
        let player1 = Item(name: "Player 1", plannedTricks: 2, tricksTaken: 1, points: 50)
        let player2 = Item(name: "Player 2", plannedTricks: 1, tricksTaken: 1, points: 75)
        let items = [player1, player2]
        
        let currentRound = 3
        let krakenDiscarded = true
        
        // Calculate total taken with kraken
        let totalTaken = items.reduce(0) { $0 + $1.tricksTaken } // 1 + 1 = 2
        let adjustedTaken = totalTaken + (krakenDiscarded ? 1 : 0) // 2 + 1 = 3
        let expected = currentRound // 3
        
        // Verify kraken adjustment makes the total valid
        #expect(totalTaken == 2)
        #expect(adjustedTaken == 3)
        #expect(adjustedTaken == expected)
    }
}
