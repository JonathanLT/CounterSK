//
//  PlayerDetailView.swift
//  CounterSK
//
//  Created by Jonathan LOQUET on 05/01/2026.
//

import SwiftUI
import SwiftData
import Foundation

struct PlayerDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var item: Item
    @Environment(\.editMode) private var editMode

    @State private var showSuggestions: Bool = false
    @State private var previousName: String = ""
    @State private var showDuplicateAlert: Bool = false

    // Query existing profiles for suggestions (latest first)
    @Query(sort: [SortDescriptor(\PlayerProfile.lastPlayedAt, order: .reverse)]) private var profiles: [PlayerProfile]
    // Query current items to know which profile names are already used in this game
    @Query(sort: [SortDescriptor(\Item.order)]) private var items: [Item]

    private func isDefaultPlayerName(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: " ")
        if parts.count == 2 {
            let first = parts[0].lowercased()
            let second = parts[1]
            if first == "joueur" && second.allSatisfy({ $0.isNumber }) {
                return true
            }
        }
        return false
    }

    private var suggestionNames: [String] {
        let names = Set(profiles.map { $0.name })
        // Names already used by other items (exclude current item)
        let usedNames = Set(items.filter { $0.id != item.id }.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })

        return names.filter { name in
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !isDefaultPlayerName(trimmed) else { return false }
            return !usedNames.contains(trimmed.lowercased())
        }
        .sorted()
    }

    var body: some View {
        Form {
            Section(header: Text("Informations")) {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Nom du joueur", text: $item.name, onEditingChanged: { editing in
                        showSuggestions = editing
                        if !editing {
                            // Editing ended: validate duplicate within current game
                            let trimmed = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
                            let usedNames = Set(items.filter { $0.id != item.id }.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
                            if !trimmed.isEmpty && usedNames.contains(trimmed.lowercased()) {
                                // Revert and notify
                                item.name = previousName
                                showDuplicateAlert = true
                            } else {
                                saveProfileIfNeeded(item.name)
                                previousName = item.name
                            }
                        }
                    })
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)

                    if showSuggestions && !suggestionNames.isEmpty {
                        ScrollView(.vertical, showsIndicators: true) {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(suggestionNames, id: \.self) { name in
                                    Button(action: {
                                        item.name = name
                                        showSuggestions = false
                                        saveProfileIfNeeded(name)
                                    }) {
                                        HStack {
                                            Text(name)
                                                .foregroundColor(.primary)
                                            Spacer()
                                        }
                                        .padding(8)
                                        .background(Color.gray.opacity(0.08))
                                        .cornerRadius(8)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 2)
                        }
                        .frame(maxHeight: 200)
                    }
                }
            }
        }
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { previousName = item.name }
        .onDisappear {
            let trimmed = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let usedNames = Set(items.filter { $0.id != item.id }.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
            if !trimmed.isEmpty && usedNames.contains(trimmed.lowercased()) {
                item.name = previousName
                showDuplicateAlert = true
            } else {
                saveProfileIfNeeded(item.name)
            }
        }
        .alert("Nom déjà utilisé", isPresented: $showDuplicateAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Ce profil est déjà utilisé par un autre joueur dans la partie.")
        }
    }

    private func saveProfileIfNeeded(_ rawName: String) {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !isDefaultPlayerName(trimmed) else { return }
        // Don't save if name is already used by another item in this game
        let usedNames = Set(items.filter { $0.id != item.id }.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
        if usedNames.contains(trimmed.lowercased()) { return }

        // Fetch all profiles and find case-insensitive match in Swift
        let fetch = FetchDescriptor<PlayerProfile>(predicate: nil, sortBy: [SortDescriptor(\PlayerProfile.lastPlayedAt, order: .reverse)])
        let existingProfiles = (try? modelContext.fetch(fetch)) ?? []

        if let existing = existingProfiles.first(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            existing.lastPlayedAt = Date()
            existing.playedCount += 1
            do { try modelContext.save(); print("Updated PlayerProfile metadata for \(trimmed)") }
            catch { print("Failed to update PlayerProfile metadata for \(trimmed): \(error)") }
        } else {
            let profile = PlayerProfile(name: trimmed)
            modelContext.insert(profile)
            do { try modelContext.save(); print("Inserted PlayerProfile metadata for \(trimmed)") }
            catch { print("Failed to insert PlayerProfile metadata for \(trimmed): \(error)") }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
