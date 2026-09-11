import SwiftUI
import BARCore

struct CocktailDetailView: View {
    @Environment(AppStore.self) var store
    var cocktailID: String
    @State private var prepAdded = false
    var body: some View {
        Group {
            if let drink = store.cocktail(cocktailID) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        DrinkArtwork(name: drink.imageName, spirit: drink.baseSpirit, height: 250)
                        VStack(alignment: .leading, spacing: 20) {
                            VStack(alignment: .leading, spacing: 8) {
                                if drink.isSample { SampleLabel() }
                                Text(drink.name).font(BarTheme.title(36)).accessibilityAddTraits(.isHeader)
                                Text(drink.ingredients.map(\.name).joined(separator: ", ")).font(.subheadline).foregroundStyle(BarTheme.muted)
                                ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 7) { ForEach(drink.flavourTags, id: \.self) { TagChip(title: $0) } } }
                            }
                            VStack(alignment: .leading, spacing: 6) {
                                SectionHeader(title: "Ingredients", subtitle: "Per serve")
                                VStack(spacing: 0) { ForEach(drink.ingredients) { ingredient in IngredientRow(ingredient: ingredient, units: store.preferences.units); if ingredient.id != drink.ingredients.last?.id { Divider().overlay(BarTheme.stone.opacity(0.4)) } } }.padding(.horizontal, 12).background(BarTheme.card, in: RoundedRectangle(cornerRadius: 12))
                            }
                            ViewThatFits(in: .horizontal) {
                                HStack(alignment: .top, spacing: 7) { specCards(drink) }
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())]) { specCards(drink) }
                            }
                            if !drink.prepInstructions.isEmpty { VStack(alignment: .leading, spacing: 12) { SectionHeader(title: "Preparation"); ForEach(Array(drink.prepInstructions.enumerated()), id: \.offset) { index, step in HStack(alignment: .top, spacing: 12) { Text(String(index + 1)).font(.caption.weight(.semibold)).frame(width: 24, height: 24).background(BarTheme.sage.opacity(0.5), in: Circle()); Text(step).font(.subheadline).foregroundStyle(BarTheme.muted) } } } }
                            if !drink.serviceNotes.isEmpty { VStack(alignment: .leading, spacing: 10) { SectionHeader(title: "Service notes"); Text(drink.serviceNotes).font(.subheadline).foregroundStyle(BarTheme.muted) } }
                            VStack(alignment: .leading, spacing: 8) { SectionHeader(title: "Allergens"); Text(drink.allergens.isEmpty ? "No allergens listed. Check product labels and your venue’s verified allergen information." : drink.allergens.joined(separator: " · ")).font(.subheadline).foregroundStyle(BarTheme.muted) }
                            HStack(spacing: 12) {
                                NavigationLink { BatchCalculatorView(cocktailID: drink.id) } label: { Label("Batch", systemImage: "flask").font(.headline).frame(maxWidth: .infinity, minHeight: 54).background(BarTheme.olive, in: RoundedRectangle(cornerRadius: 13)).foregroundStyle(.white) }.accessibilityIdentifier("batch-button")
                                Button { store.startPrep(cocktailID: drink.id, serves: 1, wastage: 0); prepAdded = true } label: { Label(prepAdded ? "Added to prep" : "Prep", systemImage: prepAdded ? "checkmark" : "leaf").font(.headline).frame(maxWidth: .infinity, minHeight: 54).background(BarTheme.coral, in: RoundedRectangle(cornerRadius: 13)).foregroundStyle(BarTheme.ink) }.disabled(prepAdded)
                            }.buttonStyle(.plain)
                        }.padding(20).background(BarTheme.cream, in: UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24)).padding(.top, -24)
                    }
                }.barScreen().navigationBarTitleDisplayMode(.inline).toolbar {
                    ToolbarItem(placement: .principal) { Text(drink.name).font(BarTheme.title(18)) }
                    ToolbarItem(placement: .topBarTrailing) { Button { store.toggleCocktailFavourite(drink.id) } label: { Image(systemName: store.preferences.favouriteCocktailIDs.contains(drink.id) ? "heart.fill" : "heart") }.accessibilityLabel(store.preferences.favouriteCocktailIDs.contains(drink.id) ? "Remove favourite" : "Favourite cocktail").accessibilityIdentifier("favourite-cocktail") }
                }.onAppear { store.recordRecent(id: drink.id, kind: .cocktail) }
            } else { EmptyStateView(title: "Drink unavailable", message: "This recipe may have been removed from your venue menu.", systemImage: "wineglass").barScreen() }
        }
    }
    @ViewBuilder private func specCards(_ drink: Cocktail) -> some View {
        InfoCard(title: "Method", value: drink.method, systemImage: "waterbottle")
        InfoCard(title: "Glass", value: drink.glass, systemImage: "wineglass")
        InfoCard(title: "Ice", value: drink.ice, systemImage: "cube")
        InfoCard(title: "Garnish", value: drink.garnish, systemImage: "leaf")
    }
}
