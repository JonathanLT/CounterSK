//
//  PlayerDetailView.swift
//  CounterSK
//
//  Created by Jonathan LOQUET on 05/01/2026.
//

import SwiftUI
import SwiftData

struct PlayerDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var item: Item
    @Environment(\.editMode) private var editMode

    var body: some View {
        Form {
            Section(header: Text("Informations")) {
                TextField("Nom du joueur", text: $item.name)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
            }
        }
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
