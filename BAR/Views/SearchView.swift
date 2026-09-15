import SwiftUI
import BARCore

struct SearchView: View {
    @Environment(AppStore.self) var store
    @State private var selectedKind = "All"
    @FocusState private var searchFocused: Bool
    private var results: [SearchResult] { SearchService.search(query: store.searchQuery, cocktails: store.cocktails, wines: store.wines, prep: store.prep, products: store.products, venueID: store.preferences.venueID).filter { selectedKind == "All" || $0.kind.rawValue.lowercased() == selectedKind.lowercased() } }
    private var resultGroups: [(SearchKind, [SearchResult])] { let kinds: [SearchKind] = [.cocktail, .product, .wine, .prep]; return kinds.compactMap { kind in let matches = results.filter { $0.kind == kind }; return matches.isEmpty ? nil : (kind, matches) } }
    var body: some View {
        @Bindable var store = store
        ScrollView { LazyVStack(alignment: .leading, spacing: 18) {
            SectionHeader(title: "Find it. Make it.", subtitle: "Every spec, ingredient and pairing.")
            SearchBar(text: $store.searchQuery, focus: $searchFocused)
            ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 8) { ForEach(["All", "Cocktail", "Wine", "Prep", "Product"], id: \.self) { kind in Button { selectedKind = kind } label: { TagChip(title: kind, selected: selectedKind == kind) }.frame(minHeight: 44) } } }
            if store.searchQuery.isEmpty {
                Text("QUICK SEARCH").font(.caption.weight(.semibold)).tracking(2).foregroundStyle(BarTheme.muted)
                ForEach(["gin citrus", "passionfruit", "no egg", "dry white", "steak"], id: \.self) { query in Button { store.searchQuery = query } label: { HStack { Image(systemName: "magnifyingglass"); Text(query); Spacer(); Image(systemName: "arrow.up.left").font(.caption) }.padding(.vertical, 10) }.buttonStyle(.plain) }
                SectionHeader(title: "Popular tonight")
                DrinkShelf(cocktails: store.cocktails.filter(\.isPopular))
            } else if results.isEmpty { EmptyStateView(title: "No matches yet", message: "Try a drink, ingredient, flavour or food pairing. Fewer words can help.", systemImage: "magnifyingglass") }
            else {
                Text("\(results.count) RESULTS").font(.caption.weight(.medium)).tracking(2).foregroundStyle(BarTheme.muted)
                ForEach(resultGroups, id: \.0) { group in
                    Text(group.0.rawValue.uppercased() + "S").font(.caption.weight(.semibold)).tracking(1.5).foregroundStyle(BarTheme.muted).padding(.top, 2)
                    ForEach(group.1, id: \.self) { result in
                        resultView(result)
                    }
                }
            }
        }.padding(20)
        }.barScreen().navigationTitle("Search").navigationBarTitleDisplayMode(.inline).scrollDismissesKeyboard(.interactively)
        .onAppear { focusFromHomeIfRequested() }
        .onChange(of: store.shouldFocusSearch) { _, requested in if requested { focusFromHomeIfRequested() } }
    }

    private func focusFromHomeIfRequested() {
        guard store.shouldFocusSearch else { return }
        Task { @MainActor in
            await Task.yield()
            guard store.shouldFocusSearch else { return }
            searchFocused = true
            store.shouldFocusSearch = false
        }
    }

    @ViewBuilder private func resultView(_ result: SearchResult) -> some View {
        switch result.kind {
        case .cocktail:
            if let cocktail = store.cocktail(result.id) { NavigationLink { CocktailDetailView(cocktailID: cocktail.id) } label: { CocktailListRow(cocktail: cocktail) } }
        case .wine:
            if let wine = store.wine(result.id) { NavigationLink { WineDetailView(wineID: wine.id) } label: { WineCard(wine: wine) } }
        case .product:
            if let product = store.products.first(where: { $0.id == result.id }) { NavigationLink { ProductDetailView(productID: product.id) } label: { ProductSearchRow(product: product) } }
        case .prep:
            NavigationLink { PrepDetailView(prepID: result.id) } label: { HStack { Image(systemName: "leaf").font(.title); VStack(alignment: .leading) { Text(result.title).font(BarTheme.title(19)); Text(result.subtitle).font(.caption) }; Spacer(); Image(systemName: "chevron.right").font(.caption) }.barCard() }
        }
    }
}

private struct ProductSearchRow: View {
    let product: Product
    var body: some View {
        HStack(spacing: 16) {
            ProductThumbnail(product: product).frame(width: 82, height: 100)
            VStack(alignment: .leading, spacing: 6) {
                Text(product.name).font(BarTheme.title(20))
                Text([product.brand, product.category].filter { !$0.isEmpty }.joined(separator: " · ")).font(.caption).foregroundStyle(BarTheme.muted)
                if !product.productType.isEmpty { Text(product.productType).font(.caption2).foregroundStyle(BarTheme.muted) }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(BarTheme.muted)
        }.barCard().accessibilityElement(children: .combine)
    }
}
struct CocktailLibraryView: View {
    @Environment(AppStore.self) var store
    var venueOnly: Bool
    @State private var query = ""
    @State private var spirit = "All"
    @State private var style = "All"
    var list: [Cocktail] {
        let base = store.cocktails.filter { venueOnly ? ($0.venueSpecific && !$0.isHouseClassic) : (!$0.venueSpecific || $0.isHouseClassic) }
        return base.filter { (spirit == "All" || $0.baseSpirit.localizedCaseInsensitiveContains(spirit)) && (style == "All" || $0.category == style) && (query.isEmpty || ($0.name + " " + $0.ingredients.map(\.name).joined(separator: " ")).localizedCaseInsensitiveContains(query)) }.sorted { $0.isPopular == $1.isPopular ? $0.name < $1.name : $0.isPopular }
    }
    var styles: [String] { ["All"] + Set(store.cocktails.filter { venueOnly ? ($0.venueSpecific && !$0.isHouseClassic) : (!$0.venueSpecific || $0.isHouseClassic) }.map(\.category)).sorted() }
    var body: some View { ScrollView { LazyVStack(alignment: .leading, spacing: 16) {
        SectionHeader(title: venueOnly ? "Made for the coast." : "Know the classics.", subtitle: venueOnly ? "Your supplied house specifications" : "The foundations of a great service.")
        SearchBar(text: $query, placeholder: "Search this collection…")
        ScrollView(.horizontal, showsIndicators: false) { HStack { ForEach(["All", "Gin", "Rum", "Vodka", "Tequila", "Whisky", "Brandy"], id: \.self) { value in Button { spirit = value } label: { TagChip(title: value, selected: spirit == value) }.frame(minHeight: 44) } } }
        ScrollView(.horizontal, showsIndicators: false) { HStack { ForEach(styles, id: \.self) { value in Button { style = value } label: { TagChip(title: value, selected: style == value) }.frame(minHeight: 44) } } }
        if list.isEmpty { EmptyStateView(title: "No drinks in this selection", message: "Try another spirit or style, or clear your search.", systemImage: "wineglass") }
        ForEach(list) { drink in NavigationLink { CocktailDetailView(cocktailID: drink.id) } label: { CocktailListRow(cocktail: drink) }.buttonStyle(.plain) }
    }.padding(20) }.barScreen().navigationTitle(venueOnly ? "Cocktails" : "Classics").navigationBarTitleDisplayMode(.inline).scrollDismissesKeyboard(.interactively) }
}
struct CocktailListRow: View {
    var cocktail: Cocktail
    var body: some View { HStack(spacing: 14) {
        DrinkArtwork(name: cocktail.imageName, spirit: cocktail.baseSpirit, height: 92).frame(width: 75).clipShape(RoundedRectangle(cornerRadius: 10))
        VStack(alignment: .leading, spacing: 6) { Text(cocktail.name).font(BarTheme.title(20)); Text(cocktail.subtitle.isEmpty ? cocktail.baseSpirit + " · " + cocktail.category : cocktail.subtitle).font(.caption).foregroundStyle(BarTheme.muted).lineLimit(2); if cocktail.isSample { SampleLabel() } }
        Spacer(minLength: 0); Image(systemName: "chevron.right").font(.caption).foregroundStyle(BarTheme.muted)
    }.barCard().accessibilityElement(children: .combine) }
}
