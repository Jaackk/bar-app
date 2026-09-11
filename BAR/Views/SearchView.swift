import SwiftUI
import BARCore

struct SearchView: View {
    @Environment(AppStore.self) var store
    @State private var selectedKind = "All"
    private var results: [SearchResult] { SearchService.search(query: store.searchQuery, cocktails: store.cocktails, wines: store.wines, prep: store.prep, venueID: store.preferences.venueID).filter { selectedKind == "All" || $0.kind.rawValue.lowercased() == selectedKind.lowercased() } }
    var body: some View {
        @Bindable var store = store
        ScrollView { LazyVStack(alignment: .leading, spacing: 18) {
            SectionHeader(title: "Find it. Make it.", subtitle: "Every spec, ingredient and pairing.")
            SearchBar(text: $store.searchQuery)
            HStack(spacing: 8) { ForEach(["All", "Cocktail", "Wine", "Prep"], id: \.self) { kind in Button { selectedKind = kind } label: { TagChip(title: kind, selected: selectedKind == kind) }.frame(minHeight: 44) } }
            if store.searchQuery.isEmpty {
                Text("QUICK SEARCH").font(.caption.weight(.semibold)).tracking(2).foregroundStyle(BarTheme.muted)
                ForEach(["gin citrus", "passionfruit", "no egg", "dry white", "steak"], id: \.self) { query in Button { store.searchQuery = query } label: { HStack { Image(systemName: "magnifyingglass"); Text(query); Spacer(); Image(systemName: "arrow.up.left").font(.caption) }.padding(.vertical, 10) }.buttonStyle(.plain) }
                SectionHeader(title: "Popular tonight")
                DrinkShelf(cocktails: store.cocktails.filter(\.isPopular))
            } else if results.isEmpty { EmptyStateView(title: "No matches yet", message: "Try a drink, ingredient, flavour or food pairing. Fewer words can help.", systemImage: "magnifyingglass") }
            else { Text("\(results.count) RESULTS").font(.caption.weight(.medium)).tracking(2).foregroundStyle(BarTheme.muted); ForEach(results, id: \.self) { result in
                switch result.kind {
                case .cocktail: if let cocktail = store.cocktail(result.id) { NavigationLink { CocktailDetailView(cocktailID: cocktail.id) } label: { CocktailListRow(cocktail: cocktail) } }
                case .wine: if let wine = store.wine(result.id) { NavigationLink { WineDetailView(wineID: wine.id) } label: { WineCard(wine: wine) } }
                case .prep: NavigationLink { PrepDetailView(prepID: result.id) } label: { HStack { Image(systemName: "leaf").font(.title); VStack(alignment: .leading) { Text(result.title).font(BarTheme.title(19)); Text(result.subtitle).font(.caption) }; Spacer(); Image(systemName: "chevron.right").font(.caption) }.barCard() }
                }
            }.buttonStyle(.plain) }
        }.padding(20) }.barScreen().navigationTitle("Search").navigationBarTitleDisplayMode(.inline).scrollDismissesKeyboard(.interactively)
    }
}
struct CocktailLibraryView: View {
    @Environment(AppStore.self) var store
    var venueOnly: Bool
    @State private var query = ""
    @State private var spirit = "All"
    @State private var style = "All"
    var list: [Cocktail] {
        let base = store.cocktails.filter { venueOnly ? $0.venueSpecific : !$0.venueSpecific }
        return base.filter { (spirit == "All" || $0.baseSpirit.localizedCaseInsensitiveContains(spirit)) && (style == "All" || $0.category == style) && (query.isEmpty || ($0.name + " " + $0.ingredients.map(\.name).joined(separator: " ")).localizedCaseInsensitiveContains(query)) }.sorted { $0.isPopular == $1.isPopular ? $0.name < $1.name : $0.isPopular }
    }
    var styles: [String] { ["All"] + Set(store.cocktails.filter { venueOnly ? $0.venueSpecific : !$0.venueSpecific }.map(\.category)).sorted() }
    var body: some View { ScrollView { LazyVStack(alignment: .leading, spacing: 16) {
        SectionHeader(title: venueOnly ? "Made for the coast." : "Know the classics.", subtitle: venueOnly ? "Sample menu · ready for your verified specs" : "The foundations of a great service.")
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
