import SwiftUI
import BARCore

struct PrepView: View {
    @Environment(AppStore.self) private var store
    @State private var showCompleted = false
    @State private var category = "All"
    @State private var adding = false
    @State private var removeExamples = false

    private var categories: [String] { ["All"] + Set(store.prep.map(\.category)).sorted() }
    private var items: [PrepItem] {
        store.prep.filter { (category == "All" || $0.category == category) && (showCompleted || !$0.completed) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    private var completedCount: Int { store.prep.filter(\.completed).count }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Ready for a great service.").font(BarTheme.title())
                    Text("Fresh prep, clear recipes, everything in its place.").font(.subheadline).foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("Today’s progress", systemImage: "checkmark.circle")
                        Spacer()
                        Text("\(completedCount) / \(store.prep.count)").font(.headline.monospacedDigit())
                    }
                    ProgressView(value: Double(completedCount), total: Double(max(store.prep.count, 1)))
                        .tint(BarTheme.olive)
                    Text(completedCount == store.prep.count && !store.prep.isEmpty ? "You’re ready. Keep an eye on levels during service." : "Mark each recipe complete once it’s prepared and stored.")
                        .font(.caption).foregroundStyle(.secondary)
                }.barCard()
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(categories, id: \.self) { value in
                            Button { category = value } label: { TagChip(title: value, selected: category == value) }
                                .buttonStyle(.plain)
                        }
                    }
                }
                Toggle("Show completed", isOn: $showCompleted).font(.subheadline).tint(BarTheme.olive)
                }
            }
            .padding(.vertical, 12)
            .listRowBackground(Color.clear)
            if items.isEmpty {
                Section {
                    EmptyStateView(title: "Prep is in good shape", message: "No outstanding recipes here. Show completed items to review quantities or start another batch.", systemImage: "checkmark.seal")
                }.listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(items) { item in
                        NavigationLink { PrepDetailView(prepID: item.id) } label: { PrepProgressCard(item: item) }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button("Delete", role: .destructive) {
                                    let id = item.id
                                    Task { @MainActor in store.deletePrep(id: id) }
                                }
                            }
                            .accessibilityIdentifier("prep-row-\(item.id)")
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                }
            }
            Section {
                Text("Prep status is saved on this device.").font(.caption).foregroundStyle(.secondary)
            }.listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .barScreen()
        .navigationTitle("Today’s prep")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Add prep", systemImage: "plus") { adding = true }
                    if store.prep.contains(where: \.isSample) {
                        Button("Remove example data", systemImage: "trash", role: .destructive) { removeExamples = true }
                    }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .confirmationDialog("Clear example prep?", isPresented: $removeExamples, titleVisibility: .visible) {
            Button("Clear examples", role: .destructive) {
                Task { @MainActor in store.removeExamplePrep() }
            }
        } message: { Text("Your own prep items stay in place.") }
        .sheet(isPresented: $adding) { PrepEditor(item: PrepItem(id: UUID().uuidString, name: "", venueID: store.preferences.venueID)) }
    }
}

private struct PrepProgressCard: View {
    let item: PrepItem

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(item.category.uppercased()).font(.caption2.weight(.semibold)).tracking(1.5).foregroundStyle(BarTheme.olive)
                    HStack(spacing: 7) { Text(item.name).font(BarTheme.title(22)).foregroundStyle(BarTheme.ink); if item.isSample { Text("EXAMPLE").font(.caption2.weight(.bold)).tracking(1).foregroundStyle(BarTheme.olive).padding(.horizontal, 7).padding(.vertical, 4).background(BarTheme.sage.opacity(0.35), in: Capsule()) } }
                }
                Spacer()
                Image(systemName: item.completed ? "checkmark.circle.fill" : "chevron.right")
                    .foregroundStyle(item.completed ? BarTheme.olive : BarTheme.ink.opacity(0.4))
            }
            ProgressView(value: item.progress).tint(BarTheme.olive)
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current \(MeasurementFormatter.string(item.currentAmount, unit: item.unit))").font(.subheadline)
                    Text("Target \(MeasurementFormatter.string(item.targetAmount, unit: item.unit))").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(item.completed ? "READY" : "TO PREP").font(.caption2.weight(.semibold)).tracking(1)
                    Text(MeasurementFormatter.string(item.requiredAmount, unit: item.unit)).font(.title2.weight(.semibold).monospacedDigit())
                }.foregroundStyle(BarTheme.olive)
            }
        }.barCard()
        .accessibilityElement(children: .combine)
    }
}

struct PrepDetailView: View {
    let prepID: String
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var scale = 1.0
    @State private var editingCurrent = false
    @State private var initializedScale = false

    private var item: PrepItem? { store.prep.first { $0.id == prepID } }

    var body: some View {
        Group {
            if let item {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(item.category.uppercased()).font(.caption.weight(.semibold)).tracking(2).foregroundStyle(BarTheme.olive)
                            Text(item.name).font(BarTheme.title(32))
                            if item.isSample { Label("Example — not verified Rockwater prep", systemImage: "info.circle").font(.caption).foregroundStyle(.secondary) }
                        }
                        HStack(spacing: 12) {
                            metric("Current", value: MeasurementFormatter.string(item.currentAmount, unit: item.unit))
                            metric("Target", value: MeasurementFormatter.string(item.targetAmount, unit: item.unit))
                            metric("To prep", value: MeasurementFormatter.string(item.requiredAmount, unit: item.unit))
                        }
                        Button { editingCurrent = true } label: { Label("Update current amount", systemImage: "pencil") }
                            .font(.subheadline.weight(.medium)).foregroundStyle(BarTheme.olive).frame(minHeight: 44)
                        VStack(alignment: .leading, spacing: 16) {
                            SectionHeader(title: "Recipe", subtitle: "Scale to the quantity you need.")
                            HStack {
                                Button { scale = max(0.25, scale - 0.25) } label: { Image(systemName: "minus").frame(width: 44, height: 44) }
                                    .disabled(scale <= 0.25)
                                Spacer()
                                VStack(spacing: 2) {
                                    Text("\(MeasurementFormatter.number(scale))× recipe").font(.title3.weight(.semibold).monospacedDigit())
                                    Text("Makes \(MeasurementFormatter.string(item.recipeYieldAmount * scale, unit: item.unit))").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button { scale = min(100, scale + 0.25) } label: { Image(systemName: "plus").frame(width: 44, height: 44) }
                                    .disabled(scale >= 100)
                            }.foregroundStyle(BarTheme.olive).padding(8).barCard()
                            HStack(spacing: 8) {
                                ForEach([0.5, 1, 2, 4], id: \.self) { amount in
                                    Button { scale = amount } label: { TagChip(title: "\(MeasurementFormatter.number(amount))×", selected: abs(scale - amount) < 0.001) }.buttonStyle(.plain)
                                }
                                if item.requiredAmount > 0 && item.recipeYieldAmount > 0 {
                                    Button { scale = item.requiredAmount / item.recipeYieldAmount } label: { TagChip(title: "To par") }.buttonStyle(.plain)
                                }
                            }
                            VStack(spacing: 0) {
                                ForEach(Array(item.recipe.enumerated()), id: \.element.id) { index, ingredient in
                                    HStack(alignment: .firstTextBaseline) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(ingredient.name).font(.subheadline)
                                            if ingredient.batchBehaviour != .normal { Text(ingredient.batchBehaviour.label).font(.caption2).foregroundStyle(BarTheme.olive) }
                                        }
                                        Spacer(minLength: 12)
                                        Text(MeasurementFormatter.string(ingredient.batchBehaviour == .garnishCount ? ceil(ingredient.amount * scale) : ingredient.amount * scale, unit: ingredient.unit))
                                            .font(.subheadline.weight(.semibold).monospacedDigit()).multilineTextAlignment(.trailing)
                                    }.padding(.vertical, 12)
                                    if index < item.recipe.count - 1 { Divider() }
                                }
                            }.barCard()
                        }
                        if !item.method.isEmpty {
                            VStack(alignment: .leading, spacing: 14) {
                                SectionHeader(title: "Method")
                                ForEach(Array(item.method.enumerated()), id: \.offset) { index, step in
                                    HStack(alignment: .top, spacing: 12) {
                                        Text("\(index + 1)").font(.caption.weight(.bold)).foregroundStyle(BarTheme.olive)
                                            .frame(width: 26, height: 26).background(BarTheme.sage.opacity(0.35), in: Circle())
                                        Text(step).font(.subheadline).lineSpacing(4).padding(.top, 3)
                                    }
                                }
                            }
                        }
                        VStack(alignment: .leading, spacing: 16) {
                            Label("Storage & shelf life", systemImage: "refrigerator").font(BarTheme.title(22))
                            if !item.storageInstructions.isEmpty { Text(item.storageInstructions).font(.subheadline).lineSpacing(3) }
                            if !item.shelfLife.isEmpty { Label(item.shelfLife, systemImage: "clock").font(.subheadline.weight(.medium)).foregroundStyle(BarTheme.olive) }
                            if let date = item.lastPreparedDate { Text("Last prepared \(date.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(.secondary) }
                        }.barCard()
                        if !item.notes.isEmpty {
                            VStack(alignment: .leading, spacing: 8) { SectionHeader(title: "Prep notes"); Text(item.notes).font(.subheadline).lineSpacing(4) }
                        }
                        if item.completed {
                            Label("Ready for service", systemImage: "checkmark.circle.fill").font(.headline).foregroundStyle(BarTheme.olive)
                                .frame(maxWidth: .infinity, minHeight: 54).background(BarTheme.sage.opacity(0.3), in: RoundedRectangle(cornerRadius: 14))
                        } else {
                            PrimaryButton(title: "Mark prepared to target", systemImage: "checkmark") {
                                store.completePrep(id: item.id)
                            }
                            Text("Sets current amount to \(MeasurementFormatter.string(item.targetAmount, unit: item.unit)). For a smaller batch, update the current amount above.").font(.caption).foregroundStyle(.secondary)
                        }
                    }.padding(20)
                }
                .onAppear {
                    if !initializedScale {
                        scale = item.requiredAmount > 0 && item.recipeYieldAmount > 0 ? item.requiredAmount / item.recipeYieldAmount : 1
                        initializedScale = true
                    }
                }
                .sheet(isPresented: $editingCurrent) {
                    AmountEditor(title: "Current prep amount", amount: item.currentAmount, unit: item.unit.rawValue) { amount in
                        store.updatePrep(id: item.id, current: amount)
                    }
                }
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Menu {
                    if item.completed { Button("Reopen") { store.reopenPrep(id: item.id) } }
                    Button("Delete prep", role: .destructive) {
                        let id = item.id
                        dismiss()
                        Task { @MainActor in store.deletePrep(id: id) }
                    }
                } label: { Image(systemName: "ellipsis.circle") } } }
            } else {
                EmptyStateView(title: "Recipe unavailable", message: "This recipe may have been removed from the venue’s prep list.", systemImage: "leaf")
            }
        }
        .barScreen()
        .navigationTitle("Prep recipe")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func metric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline.monospacedDigit()).minimumScaleFactor(0.7).lineLimit(1)
        }.frame(maxWidth: .infinity, alignment: .leading).barCard()
    }
}

private struct PrepEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var item: PrepItem
    @State private var target = ""
    init(item: PrepItem) { _item = State(initialValue: item); _target = State(initialValue: item.targetAmount == 0 ? "" : MeasurementFormatter.number(item.targetAmount)) }
    var body: some View {
        NavigationStack {
            Form {
                Section("Quick prep") {
                    TextField("Name, e.g. Lime juice", text: $item.name)
                    TextField("Target amount", text: $target).keyboardType(.decimalPad)
                    Picker("Unit", selection: $item.unit) { ForEach([MeasurementUnit.litre, .ml, .piece], id: \.self) { Text($0.label).tag($0) } }
                }
                Section("Optional details") {
                    TextField("Method", text: Binding(get: { item.method.joined(separator: " ") }, set: { item.method = $0.isEmpty ? [] : [$0] }))
                    TextField("Storage", text: $item.storageInstructions)
                    TextField("Shelf life", text: $item.shelfLife)
                    TextField("Notes", text: $item.notes)
                }
            }.navigationTitle("Prep item").toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") {
                    let value = Double(target.replacingOccurrences(of: ",", with: ".")) ?? 0
                    item.name = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    item.targetAmount = max(value, 0); item.recipeYieldAmount = max(value, 1)
                    store.savePrep(item); dismiss()
                }.disabled(item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
            }
        }
    }
}
