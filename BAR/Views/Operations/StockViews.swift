import SwiftUI
import UIKit
import BARCore

struct StocktakeView: View {
    @Environment(AppStore.self) private var store
    @State private var category = "All"
    @State private var query = ""
    @State private var belowParOnly = false

    private var categories: [String] { ["All"] + Set(store.stock.map(\.category)).sorted() }
    private var items: [StockItem] {
        store.stock.filter {
            (category == "All" || $0.category == category) && (!belowParOnly || $0.requiredStock > 0) &&
            (query.isEmpty || "\($0.name) \($0.category)".localizedCaseInsensitiveContains(query))
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    private var belowParCount: Int { store.stock.filter { $0.requiredStock > 0 }.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Keep the bar ready.").font(BarTheme.title())
                        Text("Count quickly. Order confidently.").font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    NavigationLink { WineFinderView() } label: {
                        Image(systemName: "wineglass").font(.title2).frame(width: 48, height: 48)
                            .background(BarTheme.card, in: RoundedRectangle(cornerRadius: 14))
                    }.accessibilityLabel("Open Wine Finder")
                }
                NavigationLink { SuggestedOrderView() } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "shippingbox").font(.title2)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Suggested order").font(.headline)
                            Text(belowParCount == 0 ? "Everything is at par" : "\(belowParCount) products below par").font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                    }.barCard()
                }.buttonStyle(.plain)
                SearchBar(text: $query, placeholder: "Find a bottle or product…")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(categories, id: \.self) { value in
                            Button { category = value } label: { TagChip(title: value, selected: category == value) }.buttonStyle(.plain)
                        }
                    }
                }
                Toggle("Only below par", isOn: $belowParOnly).font(.subheadline).tint(BarTheme.olive)
                if items.isEmpty {
                    EmptyStateView(title: belowParOnly ? "The bar is stocked" : "No products found", message: belowParOnly ? "Every matching product has reached its par level." : "Try another product name or category.", systemImage: belowParOnly ? "checkmark.seal" : "shippingbox")
                } else {
                    Text("Count full bottles, then set the open bottle fraction. Tap the current count for exact entry.")
                        .font(.caption).foregroundStyle(.secondary)
                    LazyVStack(spacing: 14) {
                        ForEach(items) { item in StockRow(item: item) }
                    }
                }
                Text("Counts save automatically on this device. Suggested orders round bottle shortfalls up to whole bottles.")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(20)
        }
        .barScreen()
        .navigationTitle("Stock count")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
    }
}

private struct StockRow: View {
    let item: StockItem
    @Environment(AppStore.self) private var store
    @State private var editingCount = false
    @State private var editingPar = false
    private let fractions: [(String, Double)] = [("Empty", 0), ("¼", 0.25), ("½", 0.5), ("¾", 0.75)]
    private var fraction: Double { item.currentStock - floor(item.currentStock) }
    private var isBottle: Bool { item.unit.lowercased().contains("bottle") }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                ProductThumbnail(product: store.products.first { $0.id == item.id }).frame(width: 38, height: 46)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name).font(BarTheme.title(21))
                    Text(item.category + (item.bottleSize.map { " · \(MeasurementFormatter.number($0 / 10))cl" } ?? ""))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 12) {
                Button { editingCount = true } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("CURRENT").font(.caption2.weight(.medium)).tracking(1).foregroundStyle(.secondary)
                        HStack(spacing: 6) {
                            Text(MeasurementFormatter.number(item.currentStock)).font(.title.weight(.medium).monospacedDigit())
                            Image(systemName: "pencil").font(.caption)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.buttonStyle(.plain).accessibilityLabel("Edit \(item.name) current count, \(MeasurementFormatter.number(item.currentStock)) \(item.unit)")
                VStack(alignment: .trailing, spacing: 5) {
                    Button { if store.role.canEditContent { editingPar = true } } label: {
                        HStack(spacing: 4) {
                            Text("Par \(MeasurementFormatter.number(item.parLevel))")
                            if store.role.canEditContent { Image(systemName: "pencil").font(.caption2) }
                        }.frame(minHeight: 24)
                    }.buttonStyle(.plain).disabled(!store.role.canEditContent)
                    Text(item.requiredStock > 0 ? "Short \(MeasurementFormatter.number(item.requiredStock))" : "At par")
                        .fontWeight(.semibold).foregroundStyle(BarTheme.olive)
                }.font(.subheadline)
            }
            HStack(spacing: 12) {
                Text(isBottle ? "Full bottles" : item.unit.capitalized).font(.subheadline)
                Spacer()
                Button { store.updateStock(id: item.id, count: max(0, item.currentStock - 1)) } label: {
                    Image(systemName: "minus").frame(width: 44, height: 44).background(BarTheme.stone.opacity(0.5), in: RoundedRectangle(cornerRadius: 11))
                }.buttonStyle(.plain).disabled(item.currentStock <= 0).accessibilityLabel("Remove one \(item.unit)")
                Text(MeasurementFormatter.number(isBottle ? floor(item.currentStock) : item.currentStock))
                    .font(.headline.monospacedDigit()).frame(minWidth: 26)
                Button { store.updateStock(id: item.id, count: item.currentStock + 1) } label: {
                    Image(systemName: "plus").frame(width: 44, height: 44).background(BarTheme.stone.opacity(0.5), in: RoundedRectangle(cornerRadius: 11))
                }.buttonStyle(.plain).accessibilityLabel("Add one full \(item.unit)")
            }
            if isBottle {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Open bottle").font(.caption).foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        ForEach(fractions, id: \.0) { label, value in
                            Button { store.updateStock(id: item.id, count: floor(item.currentStock) + value) } label: {
                                Text(label).font(.subheadline.weight(.medium)).frame(maxWidth: .infinity, minHeight: 44)
                                    .foregroundStyle(abs(fraction - value) < 0.001 ? .white : BarTheme.ink)
                                    .background(abs(fraction - value) < 0.001 ? BarTheme.olive : BarTheme.stone.opacity(0.55), in: Capsule())
                            }.buttonStyle(.plain).accessibilityLabel("Set open bottle to \(label)")
                                .accessibilityAddTraits(abs(fraction - value) < 0.001 ? .isSelected : [])
                        }
                        Button { store.updateStock(id: item.id, count: floor(item.currentStock) + 1) } label: {
                            Text("Full").font(.subheadline.weight(.medium)).frame(maxWidth: .infinity, minHeight: 44)
                                .background(BarTheme.stone.opacity(0.55), in: Capsule())
                        }.buttonStyle(.plain).accessibilityLabel("Count open bottle as full")
                    }
                }
            }
            if !item.notes.isEmpty { Text(item.notes).font(.caption).foregroundStyle(.secondary) }
        }.barCard()
        .sheet(isPresented: $editingCount) {
            AmountEditor(title: item.name, amount: item.currentStock, unit: item.unit) { store.updateStock(id: item.id, count: $0) }
        }
        .sheet(isPresented: $editingPar) {
            AmountEditor(title: "Par · \(item.name)", amount: item.parLevel, unit: item.unit) { store.updatePar(id: item.id, par: $0) }
        }
    }
}

struct SuggestedOrderView: View {
    @Environment(AppStore.self) private var store
    @State private var copied = false
    private var lines: [StockOrderLine] { StockCalculator.order(items: store.stock) }
    private var orderText: String { "\(store.venue.name) — suggested order\n\(Date.now.formatted(date: .abbreviated, time: .omitted))\n\n" + StockCalculator.orderText(items: store.stock) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Ready to restock.").font(BarTheme.title(30))
                Text("Based on your latest counts and venue par levels. Quantities round up so the bar reaches par.").font(.subheadline).foregroundStyle(.secondary).lineSpacing(3)
                if lines.isEmpty {
                    EmptyStateView(title: "Everything is at par", message: "There’s nothing to order. Your list updates automatically when stock counts change.", systemImage: "checkmark.seal")
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(lines.enumerated()), id: \.element.id) { index, line in
                            HStack(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(line.name).font(BarTheme.title(20))
                                    Text("Shortfall \(MeasurementFormatter.number(line.shortfall))").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("× \(line.quantity)").font(.title3.weight(.semibold).monospacedDigit())
                            }.padding(.vertical, 14)
                            if index < lines.count - 1 { Divider() }
                        }
                    }.barCard()
                    PrimaryButton(title: copied ? "Copied to clipboard" : "Copy order", systemImage: copied ? "checkmark" : "doc.on.doc") {
                        UIPasteboard.general.string = orderText
                        copied = true
                        Haptics.success()
                    }
                    ShareLink(item: orderText) {
                        Label("Share order", systemImage: "square.and.arrow.up").font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 52).overlay(RoundedRectangle(cornerRadius: 13).stroke(BarTheme.olive, lineWidth: 1))
                    }.buttonStyle(.plain)
                }
                Text("Sharing prepares an order summary. Review it before sending to your supplier.").font(.caption).foregroundStyle(.secondary)
            }.padding(20)
        }.barScreen().navigationTitle("Suggested order").navigationBarTitleDisplayMode(.inline)
    }
}

struct AmountEditor: View {
    let title: String
    let unit: String
    let save: (Double) -> Void
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool
    @State private var text: String

    init(title: String, amount: Double, unit: String, save: @escaping (Double) -> Void) {
        self.title = title
        self.unit = unit
        self.save = save
        // Editable values omit display grouping so 1,000.5 cannot become 1.0005.
        _text = State(initialValue: MeasurementFormatter.number(amount).replacingOccurrences(of: ",", with: ""))
    }

    private var amount: Double? {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized), value.isFinite, value >= 0, value <= 100_000 else { return nil }
        return value
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text(title).font(BarTheme.title(26))
                HStack(alignment: .firstTextBaseline) {
                    TextField("0", text: $text).font(.largeTitle.monospacedDigit()).keyboardType(.decimalPad).focused($focused).accessibilityLabel("Amount")
                    Text(unit).font(.headline).foregroundStyle(.secondary)
                }.barCard()
                if amount == nil { Text("Enter a number from 0 to 100,000.").font(.caption).foregroundStyle(.red) }
                PrimaryButton(title: "Save amount", systemImage: "checkmark") {
                    guard let amount else { return }
                    save(amount)
                    dismiss()
                }.disabled(amount == nil).opacity(amount == nil ? 0.5 : 1)
                Spacer()
            }.padding(20).barScreen().navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
                .onAppear { focused = true }
        }.presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
    }
}
