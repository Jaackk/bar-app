import SwiftUI
import BARCore

struct BatchCalculatorView: View {
    @Environment(AppStore.self) var store
    var cocktailID: String
    var initialServes: Int = 25
    var initialWastage: Double? = nil
    @State private var serves = 25
    @State private var wastage = 3.0
    @State private var includeWastage = true
    @State private var saved = false
    @State private var prepAdded = false
    @State private var didLoad = false
    @FocusState private var editing: Bool
    private var result: BatchResult? { guard let drink = store.cocktail(cocktailID) else { return nil }; return BatchCalculator.calculate(cocktail: drink, serves: serves, wastagePercent: includeWastage ? wastage : 0) }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if let drink = store.cocktail(cocktailID), let batch = result {
                    HStack(spacing: 16) { DrinkArtwork(name: drink.imageName, spirit: drink.baseSpirit, height: 100).frame(width: 82).clipShape(RoundedRectangle(cornerRadius: 13)); VStack(alignment: .leading, spacing: 7) { Text(drink.name).font(BarTheme.title(27)); Text(drink.subtitle).font(.caption).foregroundStyle(BarTheme.muted); if drink.isSample { SampleLabel() } } }
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "Number of serves")
                        HStack {
                            Button { serves = max(0, serves - 1) } label: { Image(systemName: "minus").frame(width: 52, height: 52) }.accessibilityLabel("Decrease serves")
                            TextField("Serves", value: $serves, format: .number).keyboardType(.numberPad).multilineTextAlignment(.center).font(BarTheme.title(32)).focused($editing).accessibilityIdentifier("batch-serves")
                            Button { serves = min(10_000, serves + 1) } label: { Image(systemName: "plus").frame(width: 52, height: 52) }.accessibilityLabel("Increase serves")
                        }.background(BarTheme.card, in: RoundedRectangle(cornerRadius: 13))
                        HStack { ForEach([10, 25, 50, 100], id: \.self) { amount in Button { serves = amount; editing = false } label: { Text("\(amount)").font(.subheadline.weight(.medium)).frame(maxWidth: .infinity, minHeight: 44).background(serves == amount ? BarTheme.olive : BarTheme.stone.opacity(0.6), in: Capsule()).foregroundStyle(serves == amount ? .white : BarTheme.ink) }.accessibilityLabel("\(amount) serves") } }
                        Toggle("Include wastage", isOn: $includeWastage).font(.subheadline).tint(BarTheme.olive)
                        if includeWastage { HStack { Text("Wastage allowance").font(.caption).foregroundStyle(BarTheme.muted); Spacer(); Stepper("\(MeasurementFormatter.number(wastage))%", value: $wastage, in: 0...30, step: 1).font(.subheadline).fixedSize() } }
                    }
                    if serves == 0 { EmptyStateView(title: "How many are we making?", message: "Choose at least one serve to calculate your batch.", systemImage: "flask") }
                    else {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: "Total ingredients", subtitle: includeWastage ? "Including \(MeasurementFormatter.number(wastage))% wastage on batch ingredients" : "No wastage allowance")
                            VStack(spacing: 0) { ForEach(batch.lines) { line in BatchIngredientRow(line: line); if line.id != batch.lines.last?.id { Divider() } } }.barCard()
                            HStack { Text("Combined batch volume").font(.caption); Spacer(); Text("\(MeasurementFormatter.number(batch.totalVolumeML / 1000))L").font(.headline).monospacedDigit() }
                            Text("Excludes separate preparations, garnishes and additions at service.").font(.caption2).foregroundStyle(BarTheme.muted)
                        }
                        if batch.lines.contains(where: { $0.bottles != nil }) {
                            VStack(alignment: .leading, spacing: 12) { SectionHeader(title: "Bottles needed", subtitle: "Whole bottles, rounded up"); VStack(spacing: 0) { ForEach(batch.lines.filter { $0.bottles != nil }) { line in HStack(alignment: .firstTextBaseline) { VStack(alignment: .leading, spacing: 3) { Text(line.ingredient.name).font(.subheadline); if let size = line.ingredient.bottleSize { Text("\(MeasurementFormatter.number(size / 10))cl bottle").font(.caption2).foregroundStyle(BarTheme.muted) } }; Spacer(); Text("\(line.bottles ?? 0) \((line.bottles ?? 0) == 1 ? "bottle" : "bottles")").font(.subheadline.weight(.semibold)).monospacedDigit() }.padding(.vertical, 9) } }.barCard() }
                        }
                        VStack(alignment: .leading, spacing: 10) { SectionHeader(title: "Batch notes"); ForEach(batch.notes, id: \.self) { note in Label { Text(note) } icon: { Image(systemName: "checkmark").font(.caption) }.font(.subheadline).foregroundStyle(BarTheme.muted) } }.barCard()
                        Button { store.saveBatch(cocktailID: cocktailID, serves: serves, wastage: includeWastage ? wastage : 0); saved = true } label: { Label(saved ? "Batch saved" : "Save batch", systemImage: saved ? "checkmark" : "bookmark").frame(maxWidth: .infinity, minHeight: 52).overlay(RoundedRectangle(cornerRadius: 13).stroke(BarTheme.olive)) }.disabled(saved).buttonStyle(.plain)
                        PrimaryButton(title: prepAdded ? "Added to today’s prep" : "Start prep", systemImage: prepAdded ? "checkmark" : "play") { store.startPrep(cocktailID: cocktailID, serves: serves, wastage: includeWastage ? wastage : 0); prepAdded = true }.disabled(prepAdded)
                        if prepAdded { NavigationLink("Open today’s prep") { PrepView() }.frame(maxWidth: .infinity, minHeight: 44) }
                    }
                } else { EmptyStateView(title: "Recipe unavailable", message: "Return to the cocktail library to select a recipe.", systemImage: "flask") }
            }.padding(20)
        }.barScreen().navigationTitle("Batch Calculator").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { editing = false } } }
            .onAppear { if !didLoad { serves = initialServes; wastage = initialWastage ?? store.preferences.defaultWastage; includeWastage = wastage > 0; didLoad = true } }
            .onChange(of: serves) { _, value in serves = min(10_000, max(0, value)); saved = false; prepAdded = false }
            .onChange(of: wastage) { _, _ in saved = false; prepAdded = false }
            .onChange(of: includeWastage) { _, _ in saved = false; prepAdded = false }
    }
}
struct BatchIngredientRow: View {
    var line: BatchLine
    var note: String? {
        switch line.behaviour { case .normal: return nil; case .serviceOnly: return "Add at service"; case .prepareSeparately: return "Prepare separately"; case .garnishCount: return "Garnish · count only"; case .nonBatchable: return "Do not batch" }
    }
    var body: some View { HStack(alignment: .firstTextBaseline, spacing: 8) { VStack(alignment: .leading, spacing: 5) { Text(line.ingredient.name).font(.subheadline); if let note { Text(note).font(.caption2).foregroundStyle(BarTheme.olive) } }; Spacer(minLength: 4); VStack(alignment: .trailing, spacing: 3) { Text(line.measurement).font(.system(.subheadline, design: .rounded).weight(.semibold)).monospacedDigit(); if let litres = line.litres { Text("\(MeasurementFormatter.number(litres))L").font(.caption2).foregroundStyle(BarTheme.muted) } } }.padding(.vertical, 10).accessibilityElement(children: .combine) }
}
struct SavedBatchesView: View {
    @Environment(AppStore.self) var store
    var body: some View { ScrollView { LazyVStack(spacing: 12) { if store.batches.isEmpty { EmptyStateView(title: "Ready for your next batch", message: "Save a calculation to keep the serves and wastage allowance here.", systemImage: "bookmark") }; ForEach(store.batches) { batch in NavigationLink { BatchCalculatorView(cocktailID: batch.cocktailID, initialServes: batch.serves, initialWastage: batch.wastagePercent) } label: { HStack { VStack(alignment: .leading, spacing: 6) { Text(batch.name).font(BarTheme.title(22)); Text("\(batch.serves) serves · \(MeasurementFormatter.number(batch.wastagePercent))% wastage").font(.caption).foregroundStyle(BarTheme.muted) }; Spacer(); Image(systemName: "chevron.right") }.barCard() }.buttonStyle(.plain) } }.padding(20) }.barScreen().navigationTitle("Saved batches").navigationBarTitleDisplayMode(.inline) }
}
