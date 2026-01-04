//
//  ContentView.swift
//  CounterSK
//
//  Created by Jonathan LOQUET on 04/01/2026.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Item.order)]) private var items: [Item]
    @Environment(\.editMode) private var editMode
    @Environment(\.dismiss) private var dismiss

    // Mode édition explicite
    private var isEditingMode: Bool { editMode?.wrappedValue == .active }

    @State private var currentRound: Int = 1
    // Toggle state for the Vote / Fin de tour radio-like control
    private enum TurnOption: String, CaseIterable, Identifiable {
        case vote = "Vote"
        case end = "Fin de tour"
        var id: Self { self }
    }
    @State private var selectedTurnOption: TurnOption = .vote
    @State private var showValidationAlert: Bool = false
    // Kraken discard flag: when true, +1 is added to totalTaken before validation (discarded trick)
    @State private var krakenDiscarded: Bool = false
    // item sélectionné pour l'édition en modal
    @State private var editingItem: Item?

    // Indique si la partie est terminée et affiche le classement
    @State private var showGameOver: Bool = false

    // Snapshot of players' points when entering the end-of-turn phase
    @State private var pointsBaseline: [ObjectIdentifier: Int] = [:]

    // Nombre de joueurs actuellement présents
    private var playerCount: Int { items.count }

    // Limite du nombre de tours autorisés selon le nombre de joueurs
    private var maxRoundsAllowed: Int {
        switch playerCount {
        case 8, 9:
            return 9
        case 10:
            return 7
        case 11, 12:
            return 6
        default:
            return 10
        }
    }

    private func cardsForRound(_ round: Int) -> Int {
        max(0, round)
    }

    private func cardsLabel(for round: Int) -> String {
        return "Tour n°\(round)"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Radio-like toggle button: alternates between Vote and Fin de tour
                Button(action: {
                    // Toggle the displayed option
                    if selectedTurnOption == .vote {
                        selectedTurnOption = .end
                        // Snapshot baseline points for live preview during end phase
                        var baseline: [ObjectIdentifier: Int] = [:]
                        for it in items {
                            baseline[ObjectIdentifier(it)] = it.points
                        }
                        pointsBaseline = baseline
                        // Ensure kraken starts unchecked when entering end phase
                        krakenDiscarded = false
                    } else {
                        // User is trying to validate the end-of-turn: check sum of tricksTaken
                        let totalTaken = items.reduce(0) { $0 + $1.tricksTaken }
                        // If Kraken is active, add +1 to the taken sum before validation
                        let adjustedTaken = totalTaken + (krakenDiscarded ? 1 : 0)
                        let expected = cardsForRound(currentRound)
                        if adjustedTaken == expected {
                            if currentRound < maxRoundsAllowed {
                                // Apply final points for this round to each player (baseline + roundPoints)
                                items.forEach { item in
                                    let baseline = pointsBaseline[ObjectIdentifier(item)] ?? item.points
                                    item.points = baseline + item.roundPoints(round: currentRound, planned: item.plannedTricks, taken: item.tricksTaken)
                                }
                                selectedTurnOption = .vote
                                currentRound += 1
                                // Reset plannedTricks and tricksTaken for the new round
                                items.forEach { item in
                                    item.plannedTricks = 0
                                    item.tricksTaken = 0
                                }
                                // Clear baseline
                                pointsBaseline = [:]
                                // reset kraken for next rounds
                                krakenDiscarded = false
                                try? modelContext.save()
                            } else {
                                // Final round: apply final points then show game over
                                items.forEach { item in
                                    let baseline = pointsBaseline[ObjectIdentifier(item)] ?? item.points
                                    item.points = baseline + item.roundPoints(round: currentRound, planned: item.plannedTricks, taken: item.tricksTaken)
                                }
                                try? modelContext.save()
                                showGameOver = true
                            }
                        } else {
                            // Show alert and block advancement
                            showValidationAlert = true
                        }
                    }
                }) {
                    Text(selectedTurnOption.rawValue)
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(selectedTurnOption == .end ? Color.blue : Color.gray)
                        .cornerRadius(8)
                }
                .padding()
                .disabled(showGameOver || isEditingMode)
                .alert("Total des pli(s) incorrect", isPresented: $showValidationAlert) {
                    Button("OK", role: .cancel) { }
                } message: {
                    let totalTaken = items.reduce(0) { $0 + $1.tricksTaken }
                    let adjustedTaken = totalTaken + (krakenDiscarded ? 1 : 0)
                    let expected = cardsForRound(currentRound)
                    if krakenDiscarded {
                        Text("Attendu: \(expected), trouvé: \(totalTaken) (+1 kraken = \(adjustedTaken))")
                    } else {
                        Text("Attendu: \(expected), trouvé: \(totalTaken)")
                    }
                }

                // Kraken toggle: visible only in end phase and when not editing
                if selectedTurnOption == .end && !isEditingMode {
                    Button(action: { krakenDiscarded.toggle() }) {
                        HStack {
                            Image(systemName: krakenDiscarded ? "checkmark.square.fill" : "square")
                                .foregroundColor(.red)
                            Text("Kraken")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.12))
                        .cornerRadius(8)
                    }
                    .padding(.horizontal)
                    .disabled(isEditingMode || showGameOver)
                }

                List {
                    ForEach(items) { item in
                        PlayerRowView(editingItem: $editingItem, item: item, currentRound: currentRound, isEndPhase: selectedTurnOption == .end, isEditingMode: isEditingMode, baselinePoints: pointsBaseline[ObjectIdentifier(item)])
                    }
                    .onMove(perform: moveItems)
                }
            }
            .navigationTitle(isEditingMode ? "Mode édition" : cardsLabel(for: currentRound))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
            // Présente PlayerDetailView en modal quand editingItem est non nil
            .sheet(item: $editingItem) { item in
                PlayerDetailView(item: item)
                    .environment(\.modelContext, modelContext)
            }
            // Feuille de fin de partie (classement)
            .sheet(isPresented: $showGameOver) {
                VStack(spacing: 16) {
                    Text("Classement final")
                        .font(.title2)
                        .bold()

                    // Calcul du classement avec ex-aequo (competition ranking)
                    let ranking = items.sorted { $0.points > $1.points }
                    let ranked: [(rank: Int, player: Item)] = {
                        var result: [(Int, Item)] = []
                        var lastPoints: Int? = nil
                        var lastRank = 0
                        for (i, p) in ranking.enumerated() {
                            if i == 0 {
                                lastRank = 1
                                lastPoints = p.points
                                result.append((lastRank, p))
                            } else {
                                if p.points == lastPoints {
                                    result.append((lastRank, p))
                                } else {
                                    lastRank = i + 1
                                    lastPoints = p.points
                                    result.append((lastRank, p))
                                }
                            }
                        }
                        return result
                    }()

                    List {
                        ForEach(ranked, id: \.player.id) { entry in
                            HStack {
                                Text("\(entry.rank). \(entry.player.name)")
                                Spacer()
                                Text("\(entry.player.points) \(entry.player.points == 1 ? "pt" : "pts")")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    HStack(spacing: 12) {
                        Button("Fermer") {
                            showGameOver = false
                        }
                        .buttonStyle(.bordered)

                        Button("Nouvelle partie") {
                            // Supprime les joueurs (retour à l'écran de démarrage)
                            items.forEach { modelContext.delete($0) }
                            try? modelContext.save()
                            showGameOver = false
                            // Revenir à l'écran précédent (StartView)
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.horizontal)
                }
                .padding()
            }
            // Si le nombre de joueurs change, on réajuste currentRound pour rester dans les limites
            .onChange(of: items.count) { _, _ in
                if currentRound > maxRoundsAllowed {
                    currentRound = maxRoundsAllowed
                }
            }
            .onAppear { ensurePositions() }
            
            // end of VStack / NavigationStack
         }
    }

    // MARK: - Reordering helpers
    // Move handler: reorder items and persist new order indices
    private func moveItems(from source: IndexSet, to destination: Int) {
        var reordered = items
        reordered.move(fromOffsets: source, toOffset: destination)

        for (index, item) in reordered.enumerated() {
            item.order = index
        }
        try? modelContext.save()
    }

    // Ensure each item has a unique persisted order value (called on appear)
    private func ensurePositions() {
        var needsSave = false
        for (index, item) in items.enumerated() {
            if item.order != index {
                item.order = index
                needsSave = true
            }
        }
        if needsSave { try? modelContext.save() }
    }
}

// Preview
 #Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
 }
