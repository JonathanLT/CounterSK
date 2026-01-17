//
//  StartView.swift
//  CounterSK
//
//  Created by Jonathan LOQUET on 04/01/2026.
//

import SwiftUI
import SwiftData

struct StartView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    // Query profiles sorted by cumulative points (descending) for the ranking
    @Query(sort: [SortDescriptor(\PlayerProfile.cumulativePoints, order: .reverse)]) private var profiles: [PlayerProfile]

    // State to present the profile manager sheet
    @State private var showProfileManager: Bool = false

    @State private var navigateToMain: Bool = false
    @State private var showPlayerCountSheet: Bool = true
    @State private var playerCount: Int = 4

    @State private var roundCount: Int = 10

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

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Skull King")
                    .font(.largeTitle)
                    .bold()

                Text("Que souhaitez-vous faire ?")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Button {
                    showPlayerCountSheet = true
                } label: {
                    Text("Commencer une nouvelle partie")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                if hasExistingGame {
                    Button {
                        // Simply navigate to the main view to resume
                        navigateToMain = true
                    } label: {
                        Text("Reprendre la précédente")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                // Show top N profiles by cumulative points (if any profiles exist)
                if !profiles.isEmpty {
                    let shown = Array(profiles.prefix(5))
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Top 5 des profils")
                            .font(.headline)
                            .padding(.top)

                        ForEach(shown, id: \.name) { profile in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(profile.name)
                                    Text("(\(profile.playedCount))")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(profile.cumulativePoints) pts")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.top)
                }

                Spacer()

                // Button to open profile manager
                Button(action: { showProfileManager = true }) {
                    Text("Gérer les profils")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.bottom)
            }
            .padding()
            .navigationDestination(isPresented: $navigateToMain) {
                ContentView()
            }
            .sheet(isPresented: $showPlayerCountSheet) {
                VStack(spacing: 20) {
                    Text("Nombre de joueurs")
                        .font(.title2)
                        .bold()

                    HStack {
                        Text("Joueurs:")
                        Picker("Joueurs", selection: $playerCount) {
                            ForEach(2...12, id: \.self) { n in
                                Text("\(n)").tag(n)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: playerCount) { _, _ in
                            roundCount = maxRoundsAllowed
                        }
                    }
                    .padding(.horizontal)

                    Text("Nombre de tours maximum possible: \(maxRoundsAllowed)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    if maxRoundsAllowed < 10 {
                        Text("Avec \(playerCount) joueurs, le nombre de tours maximum est de \(maxRoundsAllowed). Il sera automatiquement ajusté si nécessaire.")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    HStack {
                        Button("Annuler") {
                            // Optionally allow closing without starting
                            showPlayerCountSheet = false
                        }
                        .buttonStyle(.bordered)

                        Button("Valider") {
                            // Détermine automatiquement le nombre de tours selon le nombre de joueurs
                            roundCount = maxRoundsAllowed
                            // Start a new game with selected player and computed round counts
                            startNewGame()
                            showPlayerCountSheet = false
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
                .presentationDetents([.medium])
            }
            // Profile manager sheet
            .sheet(isPresented: $showProfileManager) {
                ProfileManagerView()
                    .environment(\.modelContext, modelContext)
            }
        }
    }

    private var hasExistingGame: Bool {
        !items.isEmpty
    }

    private func startNewGame() {
        // Purge existing items to start fresh. Adjust if you prefer keeping history.
        items.forEach { modelContext.delete($0) }

        // Initialize game with selected number of players
        // Create one item per player
        for i in 0..<playerCount {
            modelContext.insert(Item(name: "Joueur \(i + 1)"))
        }
        try? modelContext.save()

        // Navigate to main view
        navigateToMain = true
    }
}

#Preview {
    StartView()
        .modelContainer(for: [Item.self, PlayerProfile.self, GameRecord.self], inMemory: true)
}
