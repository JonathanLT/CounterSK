// PlayerRowView.swift
// Extracted player row UI from ContentView for clarity

import SwiftUI
import SwiftData

struct PlayerRowView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var editingItem: Item?
    var item: Item
    var currentRound: Int
    // Indicates whether we're in the "Fin de tour" phase
    var isEndPhase: Bool
    var isEditingMode: Bool
    // Baseline points snapshot when entering end phase (nil when not provided)
    var baselinePoints: Int?

    // Local state: controls presentation of the Bonus modal
    @State private var showBonusModal: Bool = false
    // Local state for bonus selection (counts per bonus type)
    @State private var bonusCounts: [String: Int] = [:]
    // Bonus definitions (label and points per occurrence)
    private let skullKingBonus = (key: "Pirate", value: 30)
    private let pirateBonus = (key: "Sirène", value: 20)
    private let sirenBonus = (key: "Skull King", value: 40)

    // 14-card constants
    private let color14Value = 10
    private let black14Value = 20
    private let fourteenKeys = ["14Y", "14P", "14G", "14B"] // Yellow, Purple, Green, Black

    // Helpers to increment/decrement planned/tricks safely and persist
    private func decrementCount() {
        if !isEndPhase {
            if item.plannedTricks > 0 { item.plannedTricks -= 1; try? modelContext.save() }
        } else {
            if item.tricksTaken > 0 { item.tricksTaken -= 1; try? modelContext.save() }
        }
    }

    private func incrementCount() {
        let maxCards = cardsForRound(currentRound)
        if !isEndPhase {
            if item.plannedTricks < maxCards { item.plannedTricks += 1; try? modelContext.save() }
        } else {
            if item.tricksTaken < maxCards { item.tricksTaken += 1; try? modelContext.save() }
        }
    }

    // Checkbox binding helper for 14-card keys
    private func checkboxBinding(_ key: String) -> Binding<Bool> {
        Binding(get: { (bonusCounts[key] ?? 0) == 1 }, set: { bonusCounts[key] = $0 ? 1 : 0 })
    }

    private func cardsForRound(_ round: Int) -> Int { max(0, round) }

    // Live preview of points: when in end phase, show baseline + this round points; otherwise show persisted points
    private var previewPoints: Int {
        if isEndPhase {
            let baseline = baselinePoints ?? item.points
            return baseline + item.roundPoints(round: cardsForRound(currentRound), planned: item.plannedTricks, taken: item.tricksTaken)
        } else {
            return item.points
        }
    }

    // Simplify complex inline expressions by moving logic into computed properties
    private var currentMaxCards: Int { cardsForRound(currentRound) }
    
    private var minusButtonColor: Color {
        if !isEndPhase {
            return item.plannedTricks > 0 ? .red : .gray
        } else {
            return item.tricksTaken > 0 ? .red : .gray
        }
    }
    
    private var plusButtonColor: Color {
        if !isEndPhase {
            return item.plannedTricks < currentMaxCards ? .green : .gray
        } else {
            return item.tricksTaken < currentMaxCards ? .green : .gray
        }
    }
    
    private var minusIsDisabled: Bool {
        if !isEndPhase {
            return item.plannedTricks <= 0
        } else {
            return item.tricksTaken <= 0
        }
    }
    
    private var plusIsDisabled: Bool {
        if !isEndPhase {
            return item.plannedTricks >= currentMaxCards
        } else {
            return item.tricksTaken >= currentMaxCards
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                if !isEditingMode {
                    Button {
                        if !isEndPhase {
                            if item.plannedTricks > 0 {
                                item.plannedTricks -= 1
                                try? modelContext.save()
                            }
                        } else {
                            if item.tricksTaken > 0 {
                                item.tricksTaken -= 1
                                try? modelContext.save()
                            }
                        }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .foregroundColor(minusButtonColor)
                            .frame(maxHeight: .infinity)
                            .contentShape(Rectangle())
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .disabled(minusIsDisabled)
                }

                // Center content
                HStack(spacing: 8) {
                    Text(item.name)
                        .lineLimit(1)
                    Spacer()
                    Text("")
                    // Compose preview points with localized pt/pts
                    Text("\(previewPoints) \(NSLocalizedString(previewPoints == 1 ? "pt" : "pts", comment: "point abbreviation"))")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)

                if !isEditingMode {
                    Button {
                        let maxCards = cardsForRound(currentRound)
                        if !isEndPhase {
                            if item.plannedTricks < maxCards {
                                item.plannedTricks += 1
                                try? modelContext.save()
                            }
                        } else {
                            if item.tricksTaken < maxCards {
                                item.tricksTaken += 1
                                try? modelContext.save()
                            }
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .foregroundColor(plusButtonColor)
                            .frame(maxHeight: .infinity)
                            .contentShape(Rectangle())
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .disabled(plusIsDisabled)
                } else {
                    Button {
                        editingItem = item
                    } label: {
                        Image(systemName: "pencil.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                            .foregroundColor(.blue)
                            .frame(maxHeight: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
            }

            if !isEditingMode {
                HStack(spacing: 12) {
                    Spacer().frame(width: 20)

                    // Left: tricks text (planned or taken)
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                        if !isEndPhase {
                            Text("\(item.plannedTricks) \(NSLocalizedString("sur", comment: "on")) \(currentRound)")
                                .font(.caption)
                        } else {
                            Text("\(item.tricksTaken) \(NSLocalizedString("sur", comment: "on")) \(item.plannedTricks)")
                                .font(.caption)
                                .foregroundColor(item.tricksTaken > item.plannedTricks ? .red : .primary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Bonus button (only in end-of-turn)
                    if isEndPhase {
                        Button("Bonus") { showBonusModal = true }
                            .buttonStyle(.bordered)
                    }

                    // Right: round points for this player displayed as (+x) or (-x)
                    let roundCards = cardsForRound(currentRound)
                    let roundValue: Int = isEndPhase ? item.roundPoints(round: roundCards, planned: item.plannedTricks, taken: item.tricksTaken) : item.roundPoints(round: roundCards, planned: item.plannedTricks, taken: item.plannedTricks)
                    let sign = roundValue >= 0 ? "+" : ""
                    Text("(\(sign)\(roundValue))")
                        .font(.caption)
                        .foregroundColor(roundValue > 0 ? .green : (roundValue < 0 ? .red : .primary))
                        .frame(width: 60, alignment: .trailing)
                    Spacer().frame(width: 22)
                }
                .padding(.vertical, 4)
                .padding(.trailing, 8)
            }
        }
        .sheet(isPresented: $showBonusModal) {
            BonusModalView(item: item, bonusCounts: $bonusCounts, isPresented: $showBonusModal, currentRound: currentRound, skullKingBonus: skullKingBonus, pirateBonus: pirateBonus, sirenBonus: sirenBonus, color14Value: color14Value, noir14Value: black14Value)
         }
     }
 }
 
fileprivate struct BonusModalView: View {
    var item: Item
    @Binding var bonusCounts: [String: Int]
    @Binding var isPresented: Bool
    var currentRound: Int
    var skullKingBonus: (key: String, value: Int)
    var pirateBonus: (key: String, value: Int)
    var sirenBonus: (key: String, value: Int)
    var color14Value: Int
    var noir14Value: Int

    @Environment(\.modelContext) private var modelContext

    private func cardsForRound(_ round: Int) -> Int { max(0, round) }

    // Bindings for pickers to reduce inline complexity
    private var skullBinding: Binding<Int> {
        Binding(get: { bonusCounts[skullKingBonus.key] ?? 0 }, set: { bonusCounts[skullKingBonus.key] = $0 })
    }
    private var pirateBinding: Binding<Int> {
        Binding(get: { bonusCounts[pirateBonus.key] ?? 0 }, set: { bonusCounts[pirateBonus.key] = $0 })
    }
    private var sirenBinding: Binding<Int> {
        Binding(get: { bonusCounts[sirenBonus.key] ?? 0 }, set: { bonusCounts[sirenBonus.key] = $0 })
    }

    private var computedTotal: Int {
        let base = [skullKingBonus, pirateBonus, sirenBonus].reduce(0) { acc, b in
            acc + (bonusCounts[b.key] ?? 0) * b.value
        }
        let colors = (bonusCounts["14 jaune"] ?? 0) * color14Value + (bonusCounts["14 violet"] ?? 0) * color14Value + (bonusCounts["14 vert"] ?? 0) * color14Value
        let noir = (bonusCounts["14 noir"] ?? 0) * noir14Value
        return base + colors + noir
    }

    // Split large view into smaller parts to help compiler
    private func skullSection() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Skull King capture").font(.headline)
            HStack {
                VStack(alignment: .leading) {
                    Text(skullKingBonus.key).bold()
                    Text("\(skullKingBonus.value) pts par capture").font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                Picker(selection: skullBinding, label: EmptyView()) {
                    ForEach(0..<7) { i in Text("\(i)").tag(i) }
                }
                .pickerStyle(.segmented)
            }
        }
    }
    
    private func piratesSection() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pirates capture").font(.headline)
            HStack {
                VStack(alignment: .leading) {
                    Text(pirateBonus.key).bold()
                    Text("\(pirateBonus.value) pts par capture").font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                Picker(selection: pirateBinding, label: EmptyView()) {
                    ForEach(0..<3) { i in Text("\(i)").tag(i) }
                }
                .pickerStyle(.segmented)
            }
        }
    }
    
    private func sirenSection() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sirène capture").font(.headline)
            HStack {
                VStack(alignment: .leading) {
                    Text(sirenBonus.key).bold()
                    Text("\(sirenBonus.value) pts par capture").font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                Picker(selection: sirenBinding, label: EmptyView()) {
                    ForEach(0..<2) { i in Text("\(i)").tag(i) }
                }
                .pickerStyle(.segmented)
            }
        }
    }
    
    private func fourteensSection() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Les 14").font(.headline)
            HStack(spacing: 16) {
                CheckboxButton(isOn: Binding(get: { (bonusCounts["14 jaune"] ?? 0) == 1 }, set: { bonusCounts["14 jaune"] = $0 ? 1 : 0 }), label: "Jaune", color: .yellow)
                CheckboxButton(isOn: Binding(get: { (bonusCounts["14 violet"] ?? 0) == 1 }, set: { bonusCounts["14 violet"] = $0 ? 1 : 0 }), label: "Violet", color: .purple)
                CheckboxButton(isOn: Binding(get: { (bonusCounts["14 vert"] ?? 0) == 1 }, set: { bonusCounts["14 vert"] = $0 ? 1 : 0 }), label: "Vert", color: .green)
            }
            HStack {
                CheckboxButton(isOn: Binding(get: { (bonusCounts["14 noir"] ?? 0) == 1 }, set: { bonusCounts["14 noir"] = $0 ? 1 : 0 }), label: "Noir", color: .black)
            }
        }
    }
    
    private func footerView() -> some View {
        VStack(spacing: 8) {
            HStack {
                Text(NSLocalizedString("Total de bonus:", comment: "Total bonus label"))
                Spacer()
                Text("\(computedTotal) \(NSLocalizedString("pts", comment: "points plural"))").bold()
            }

            HStack(spacing: 12) {
                Button(NSLocalizedString("Annuler", comment: "Cancel")) {
                    bonusCounts = [:]
                    isPresented = false
                }
                .buttonStyle(.bordered)

                Button(NSLocalizedString("Appliquer", comment: "Apply")) {
                    item.extraBonus = computedTotal
                    try? modelContext.save()
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            Text("Bonus").font(.title2).bold()
            Text("Joueur: \(item.name)").font(.headline)

            HStack {
                Text("Bonus actuel:")
                Spacer()
                Text("\(item.extraBonus) pts").foregroundColor(.secondary)
            }

            Divider()

            skullSection()
            Divider()
            piratesSection()
            Divider()
            sirenSection()
            Divider()
            fourteensSection()
            Divider()
            footerView()
            Spacer()
        }
        .padding()
        .onAppear {
            if bonusCounts[skullKingBonus.key] == nil { bonusCounts[skullKingBonus.key] = 0 }
            if bonusCounts[pirateBonus.key] == nil { bonusCounts[pirateBonus.key] = 0 }
            if bonusCounts[sirenBonus.key] == nil { bonusCounts[sirenBonus.key] = 0 }
            if bonusCounts["14 jaune"] == nil { bonusCounts["14 jaune"] = 0 }
            if bonusCounts["14 violet"] == nil { bonusCounts["14 violet"] = 0 }
            if bonusCounts["14 vert"] == nil { bonusCounts["14 vert"] = 0 }
            if bonusCounts["14 noir"] == nil { bonusCounts["14 noir"] = 0 }
        }
    }
}

// Small reusable checkbox button instead of inline Button to keep ViewBuilder simple
fileprivate struct CheckboxButton: View {
    @Binding var isOn: Bool
    var label: String
    var color: Color = .primary

    var body: some View {
        Button(action: { isOn.toggle() }) {
            HStack(spacing: 6) {
                Image(systemName: isOn ? "checkmark.square.fill" : "square")
                    .foregroundColor(color)
                Text(label)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
