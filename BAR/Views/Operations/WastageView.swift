import SwiftUI
import BARCore

struct WastageView: View {
    @Environment(AppStore.self) private var store
    @State private var itemName = ""
    @State private var quantity = "1"
    @State private var unit = "bottles"
    @State private var reason = "Spillage"
    @FocusState private var focusedField: Field?

    private enum Field { case item, quantity }
    private let units = ["bottles", "cans", "glasses", "ml", "pieces"]
    private let reasons = ["Spillage", "Breakage", "Quality", "Out of date", "Other"]
    private var todayEntries: [WastageEntry] { store.wastage.filter { Calendar.current.isDateInToday($0.createdAt) } }
    private var earlierEntries: [WastageEntry] { store.wastage.filter { !Calendar.current.isDateInToday($0.createdAt) } }
    private var shareText: String {
        let lines = store.wastage.map { "\($0.itemName) × \(MeasurementFormatter.number($0.quantity)) \($0.unit) — \($0.reason)" }
        return "WASTAGE\n\n" + lines.joined(separator: "\n")
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Keep service losses visible.").font(BarTheme.title(28))
                    Text(todayEntries.isEmpty ? "Nothing logged today." : "\(todayEntries.count) \(todayEntries.count == 1 ? "item" : "items") logged today.")
                        .font(.subheadline).foregroundStyle(BarTheme.muted)
                }.padding(.vertical, 8)
            }.listRowBackground(Color.clear)

            Section("Log wastage") {
                TextField("What was wasted?", text: $itemName)
                    .textInputAutocapitalization(.words)
                    .focused($focusedField, equals: .item)
                    .accessibilityIdentifier("wastage-item")
                HStack {
                    TextField("Quantity", text: $quantity)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .quantity)
                        .accessibilityIdentifier("wastage-quantity")
                    Picker("Unit", selection: $unit) { ForEach(units, id: \.self) { Text($0).tag($0) } }
                        .pickerStyle(.menu)
                }
                Picker("Reason", selection: $reason) { ForEach(reasons, id: \.self) { Text($0).tag($0) } }
                Button {
                    let value = Double(quantity.replacingOccurrences(of: ",", with: ".")) ?? 0
                    store.addWastage(itemName: itemName, quantity: value, unit: unit, reason: reason)
                    if value > 0 && !itemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        itemName = ""
                        quantity = "1"
                        reason = "Spillage"
                        focusedField = nil
                    }
                } label: {
                    Label("Add wastage", systemImage: "plus").font(.headline).frame(maxWidth: .infinity, minHeight: 42)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(BarTheme.olive, in: RoundedRectangle(cornerRadius: 12))
                .disabled(itemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (Double(quantity.replacingOccurrences(of: ",", with: ".")) ?? 0) <= 0)
                .accessibilityIdentifier("add-wastage")
            }.listRowBackground(BarTheme.card)

            if store.wastage.isEmpty {
                Section {
                    EmptyStateView(title: "No wastage logged", message: "Add a quick entry whenever something is spilled, broken or no longer usable.", systemImage: "drop.triangle")
                }.listRowBackground(Color.clear)
            } else {
                if !todayEntries.isEmpty { entrySection("Today", entries: todayEntries) }
                if !earlierEntries.isEmpty { entrySection(todayEntries.isEmpty ? "Recent entries" : "Earlier", entries: earlierEntries) }
            }
        }
        .listStyle(.plain)
        .listSectionSpacing(8)
        .contentMargins(.top, 0, for: .scrollContent)
        .scrollContentBackground(.hidden)
        .barScreen()
        .navigationTitle("Wastage")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: shareText) { Image(systemName: "square.and.arrow.up") }
                    .accessibilityLabel("Share wastage")
                    .disabled(store.wastage.isEmpty)
            }
            ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { focusedField = nil } }
        }
    }

    @ViewBuilder private func entrySection(_ title: String, entries: [WastageEntry]) -> some View {
        Section(title) {
            ForEach(entries) { entry in
                HStack(spacing: 12) {
                    Image(systemName: "drop.triangle").foregroundStyle(BarTheme.olive).frame(width: 25)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(entry.itemName).font(.subheadline.weight(.semibold))
                        Text("\(entry.reason) · \(entry.createdAt.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(BarTheme.muted)
                    }
                    Spacer()
                    Text("\(MeasurementFormatter.number(entry.quantity)) \(entry.unit)").font(.caption.weight(.semibold)).multilineTextAlignment(.trailing)
                }.padding(.vertical, 5)
                .swipeActions { Button("Delete", role: .destructive) { store.deleteWastage(id: entry.id) } }
            }
        }.listRowBackground(BarTheme.card)
    }
}
