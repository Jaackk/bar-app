import SwiftUI
import BARCore

struct CocktailDetailView: View {
    @Environment(AppStore.self) private var store
    var cocktailID: String
    @State private var prepAdded = false
    @State private var editing = false
    var body: some View {
        Group {
            if let drink = store.cocktail(cocktailID) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        Text(drink.name).font(BarTheme.title(34)).accessibilityAddTraits(.isHeader)
                        Label(store.specificationLabel(drink), systemImage: drink.displaySpecification == .recommended ? "book.closed" : "building.2")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(BarTheme.olive).accessibilityIdentifier("active-specification")
                        if drink.isSample { SampleLabel() }
                        if drink.displaySpecification == .custom, !drink.trainingEligible, let reference = store.classicReference(drink.id) {
                            Text(reference.customReview).font(.subheadline).foregroundStyle(BarTheme.olive)
                        }
                        if let reference = store.classicReference(drink.id) {
                            if reference.recommended != nil {
                                Picker("Specification for this drink", selection: Binding<ClassicSpecification?>(get: { store.preferences.classicOverrides[reference.id] }, set: { store.setClassicOverride($0, cocktailID: drink.id); prepAdded = false })) {
                                    Text("Use global (\(store.preferences.classicDefault.label))").tag(Optional<ClassicSpecification>.none)
                                    Text("Custom · \(store.venue.name)").tag(Optional(ClassicSpecification.custom))
                                    Text("Recommended").tag(Optional(ClassicSpecification.recommended))
                                }.pickerStyle(.menu).frame(minHeight: 44).accessibilityIdentifier("classic-specification")
                                if store.rawCocktail(drink.id)?.venueID == nil { Text("No venue Custom has been supplied. Showing the Recommended reference.").font(.caption).foregroundStyle(.secondary) }
                            } else { Text("House variation · no verified Recommended specification").font(.caption).foregroundStyle(.secondary) }
                        }
                        VStack(alignment: .leading, spacing: 10) {
                            SectionHeader(title: "Per serve", subtitle: drink.recipeVerified ? nil : "Measures awaiting approval")
                            ForEach(drink.ingredients) { ingredient in
                                if drink.recipeVerified { IngredientRow(ingredient: ingredient, units: store.preferences.units) }
                                else { Text(ingredient.name).font(.body).padding(.vertical, 6) }
                                if ingredient.id != drink.ingredients.last?.id { Divider() }
                            }
                        }.barCard()
                        if drink.recipeVerified {
                            VStack(alignment: .leading, spacing: 14) {
                                Text(drink.method).font(.title3.weight(.semibold)).foregroundStyle(BarTheme.olive)
                                serviceLine("Glass", drink.glass); serviceLine("Ice", drink.ice); serviceLine("Garnish", drink.garnish)
                            }
                            ForEach(Array(drink.prepInstructions.enumerated()), id: \.offset) { index, step in
                                HStack(alignment: .top, spacing: 12) {
                                    Text(String(index + 1)).font(.caption.weight(.bold)).frame(width: 24, height: 24).background(BarTheme.sage.opacity(0.5), in: Circle())
                                    Text(step).font(.body).fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            NavigationLink { BatchCalculatorView(cocktailID: drink.id, initialSpecification: drink) } label: {
                                Label("Calculate a batch", systemImage: "flask").font(.headline).frame(maxWidth: .infinity, minHeight: 54).background(BarTheme.olive, in: RoundedRectangle(cornerRadius: 13)).foregroundStyle(.white)
                            }.buttonStyle(.plain).accessibilityIdentifier("batch-button")
                            Button { store.startPrep(cocktailID: drink.id, serves: 1, wastage: 0, specification: drink); prepAdded = store.errorMessage == nil } label: {
                                Label(prepAdded ? "Added to prep" : "Add to prep", systemImage: prepAdded ? "checkmark" : "leaf").frame(maxWidth: .infinity, minHeight: 48)
                            }.disabled(prepAdded)
                        } else { Text("Ask the manager for the approved measures before preparing or batching.").font(.subheadline).foregroundStyle(BarTheme.olive) }
                        if !drink.serviceNotes.isEmpty { SectionHeader(title: "Service notes"); Text(drink.serviceNotes).font(.subheadline) }
                        VStack(alignment: .leading, spacing: 8) {
                            SectionHeader(title: "Allergen information")
                            Text(drink.allergens.isEmpty ? "Not verified. Check the products used and your venue’s allergen record." : "Recorded: " + drink.allergens.joined(separator: " · ") + ". Check current product labels and the venue’s verified record.").font(.subheadline).foregroundStyle(.secondary)
                        }
                        DisclosureGroup("Specification & sources") {
                            VStack(alignment: .leading, spacing: 12) {
                                if let reference = store.classicReference(drink.id) {
                                    Text(reference.decision)
                                    if drink.displaySpecification == .custom, !reference.customReview.isEmpty { Text(reference.customReview) }
                                    if let old = reference.correctedLegacyMethod, store.rawCocktail(drink.id)?.method == old { Text("Technique corrected in the service view. Original wording retained for review: “\(old)”. House measures are unchanged.") }
                                    Text("Classic reference verified \(reference.verifiedOn) · revision \(reference.version)")
                                    ForEach(reference.sources, id: \.url) { source in
                                        if let url = URL(string: source.url), url.scheme == "https" { Link(source.name, destination: url) }
                                    }
                                }
                                if let raw = store.rawCocktail(drink.id), let reference = raw.sourceReference { Text("Venue source: \(reference)") }
                            }.font(.caption).foregroundStyle(.secondary).padding(.top, 12)
                        }.frame(minHeight: 44)
                        if !drink.imageName.isEmpty {
                            DisclosureGroup("Reference illustration") {
                                DrinkArtwork(name: drink.imageName, spirit: drink.baseSpirit, height: 240).clipShape(RoundedRectangle(cornerRadius: 14))
                                Text("Reference imagery, not a photograph of this venue’s serve.").font(.caption).foregroundStyle(.secondary)
                            }.frame(minHeight: 44)
                        }
                        if store.role.canEditContent, store.rawCocktail(drink.id)?.venueID == store.venue.id { Button("Edit venue Custom specification") { editing = true }.frame(minHeight: 44) }
                    }.padding(20)
                }.barScreen().navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button { store.toggleCocktailFavourite(drink.id) } label: { Image(systemName: store.isCocktailFavourite(drink.id) ? "heart.fill" : "heart").frame(width: 44, height: 44) }
                                .accessibilityLabel(store.isCocktailFavourite(drink.id) ? "Remove favourite" : "Favourite cocktail").accessibilityIdentifier("favourite-cocktail")
                        }
                    }.onAppear { store.recordRecent(id: drink.id, kind: .cocktail) }
                    .sheet(isPresented: $editing) { if let custom = store.rawCocktail(drink.id) { CustomRecipeEditor(recipe: custom) } }
            } else { EmptyStateView(title: "Drink unavailable", message: "This recipe is not active in the current venue.", systemImage: "wineglass").barScreen() }
        }
    }
    private func serviceLine(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) { Text(title.uppercased()).font(.caption.weight(.semibold)).foregroundStyle(.secondary); Text(value.isEmpty ? "Not specified" : value).font(.body) }.accessibilityElement(children: .combine)
    }
}

private struct CustomRecipeEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var recipe: Cocktail
    var body: some View {
        NavigationStack {
            Form {
                Section { Text("Edits apply only to venue Custom. Recommended stays unchanged. Confirm changes against the approved venue recipe.") }
                Section("Ingredients · per serve") {
                    ForEach($recipe.ingredients) { $ingredient in
                        VStack(alignment: .leading) {
                            Text(ingredient.name).font(.headline)
                            HStack {
                                TextField("Amount", value: $ingredient.amount, format: .number).keyboardType(.decimalPad)
                                Picker("Unit", selection: $ingredient.unit) { ForEach(MeasurementUnit.allCases, id: \.self) { Text($0.label).tag($0) } }
                            }
                            if ingredient.quantityDisplay != nil { Text("Source wording: \(ingredient.quantityDisplay ?? "")").font(.caption); Button("Use numeric amount instead") { ingredient.quantityDisplay = nil } }
                            Picker("Batch handling", selection: $ingredient.batchBehaviour) { ForEach(BatchBehaviour.allCases, id: \.self) { Text($0.label).tag($0) } }
                        }
                    }
                }
                Section("Service") {
                    TextField("Technique", text: $recipe.method, axis: .vertical)
                    TextField("Glass", text: $recipe.glass); TextField("Ice", text: $recipe.ice)
                    TextField("Garnish", text: $recipe.garnish, axis: .vertical)
                    TextField("Steps (one per line)", text: Binding(get: { recipe.prepInstructions.joined(separator: "\n") }, set: { recipe.prepInstructions = $0.components(separatedBy: .newlines) }), axis: .vertical)
                    TextField("Service notes", text: $recipe.serviceNotes, axis: .vertical)
                }
            }.navigationTitle("Edit Custom").navigationBarTitleDisplayMode(.inline).scrollDismissesKeyboard(.interactively)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Save") {
                        recipe.updatedAt = Date()
                        for i in recipe.ingredients.indices { recipe.ingredients[i].batchable = recipe.ingredients[i].batchBehaviour == .normal || recipe.ingredients[i].batchBehaviour == .prepareSeparately }
                        store.updateCocktail(recipe)
                        if store.errorMessage == nil { dismiss() }
                    }.disabled(!store.role.canEditContent || recipe.ingredients.contains { !$0.amount.isFinite || $0.amount < 0 }) }
                }
        }
    }
}
