import SwiftUI
import SwiftData

struct ProfileManagerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: [SortDescriptor(\PlayerProfile.lastPlayedAt, order: .reverse)]) private var profiles: [PlayerProfile]

    @State private var editingProfile: PlayerProfile?
    @State private var draftName: String = ""
    @State private var showResetAlert: Bool = false
    @State private var profileToReset: PlayerProfile?

    var body: some View {
        NavigationStack {
            List {
                ForEach(profiles) { profile in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(profile.name)
                                .font(.body)
                            Text("(\(profile.playedCount) parties)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("\(profile.cumulativePoints) pts")
                                .foregroundStyle(.secondary)
                            HStack(spacing: 8) {
                                Button("Éditer") {
                                    editingProfile = profile
                                    draftName = profile.name
                                }
                                .buttonStyle(.bordered)

                                Button("Réinitialiser") {
                                    profileToReset = profile
                                    showResetAlert = true
                                }
                                .buttonStyle(.bordered)
                                .tint(.red)
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .navigationTitle("Gestion des profils")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Fermer") { dismiss() }
                }
            }
            .sheet(item: $editingProfile) { profile in
                VStack(spacing: 16) {
                    Text("Modifier le nom")
                        .font(.title2)
                        .bold()
                    TextField("Nom du profil", text: $draftName)
                        .textFieldStyle(.roundedBorder)
                        .padding()

                    HStack {
                        Button("Annuler") { editingProfile = nil }
                            .buttonStyle(.bordered)
                        Button("Enregistrer") {
                            profile.name = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
                            do { try modelContext.save() } catch { print("Failed to save profile rename: \(error)") }
                            editingProfile = nil
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    Spacer()
                }
                .padding()
            }
            .alert("Réinitialiser le cumul ?", isPresented: $showResetAlert, actions: {
                Button("Annuler", role: .cancel) { profileToReset = nil }
                Button("Réinitialiser", role: .destructive) {
                    if let p = profileToReset {
                        p.cumulativePoints = 0
                        do { try modelContext.save() } catch { print("Failed to reset: \(error)") }
                    }
                    profileToReset = nil
                }
            }, message: { Text("Le cumul de points sera remis à zéro pour ce profil.") })
        }
    }
}

#Preview {
    ProfileManagerView()
        .modelContainer(for: [PlayerProfile.self], inMemory: true)
}
