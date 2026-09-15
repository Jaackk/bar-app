import SwiftUI
import BARCore

struct HomeView: View {
    @Environment(AppStore.self) private var store
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour < 12 ? "Good morning" : hour < 17 ? "Good afternoon" : "Good evening"
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    Menu { NavigationLink("Favourites", destination: FavouritesView()); NavigationLink("Saved batches", destination: SavedBatchesView()); NavigationLink("About your venue", destination: ProfileView()) } label: { Image(systemName: "line.3.horizontal").font(.title2).frame(width: 44, height: 44) }.accessibilityLabel("Open menu")
                    Spacer()
                    VStack(spacing: 1) { Text(store.venue.branding.displayName.isEmpty ? store.venue.name.uppercased() : store.venue.branding.displayName).font(.system(size: 21, weight: .regular, design: .serif)).tracking(4); Text(store.venue.branding.subtitle.isEmpty ? "Bar" : store.venue.branding.subtitle).font(.custom("SnellRoundhand", size: 32)) }
                    Spacer(); Color.clear.frame(width: 44, height: 1)
                }.padding(.top, 6)
                VStack(alignment: .leading, spacing: 5) { Text("\(greeting)\(store.preferences.employeeName.isEmpty ? "" : ", \(store.preferences.employeeName)"),").font(.subheadline).foregroundStyle(BarTheme.muted); Text("Let’s make it a great service.").font(.system(.headline, design: .rounded).weight(.medium)) }
                Button { store.shouldFocusSearch = true; store.selectedTab = 1 } label: { HStack { Image(systemName: "magnifyingglass").font(.title3); Text("Search cocktails, wine, ingredients…").font(.subheadline); Spacer() }.foregroundStyle(BarTheme.muted).padding(16).frame(minHeight: 55).background(BarTheme.card, in: RoundedRectangle(cornerRadius: 16)).shadow(color: .black.opacity(0.04), radius: 6, y: 3) }.buttonStyle(.plain).accessibilityIdentifier("home-search")
                if store.prep.contains(where: { !$0.completed }) || !store.listItems(.restock).isEmpty || !store.listItems(.order).isEmpty {
                    HStack(spacing: 10) {
                        if store.prep.contains(where: { !$0.completed }) { Button { store.selectedTab = 2 } label: { Label("\(store.prep.filter { !$0.completed }.count) prep remaining", systemImage: "leaf").font(.caption.weight(.medium)) }.buttonStyle(.plain) }
                        if !store.listItems(.restock).isEmpty { Button { store.selectedTab = 3 } label: { Label("\(store.listItems(.restock).count) restock", systemImage: "tray") .font(.caption.weight(.medium)) }.buttonStyle(.plain) }
                        if !store.listItems(.order).isEmpty { Button { store.selectedTab = 3 } label: { Label("\(store.listItems(.order).count) order", systemImage: "cart") .font(.caption.weight(.medium)) }.buttonStyle(.plain) }
                    }.foregroundStyle(BarTheme.olive).frame(maxWidth: .infinity, alignment: .leading)
                }
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    NavigationLink { CocktailLibraryView(venueOnly: true) } label: { CategoryCard(title: "Cocktails", subtitle: "Our signature drinks", symbol: "wineglass") }
                    NavigationLink { CocktailLibraryView(venueOnly: false) } label: { CategoryCard(title: "Classics", subtitle: "Timeless favourites", symbol: "wineglass.fill") }
                    NavigationLink { WineFinderView() } label: { CategoryCard(title: "Wine Finder", subtitle: "Find their next favourite", symbol: "wineglass") }
                    Button { store.selectedTab = 2 } label: { CategoryCard(title: "Prep", subtitle: "Today’s prep & recipes", symbol: "leaf") }
                    Button { store.selectedTab = 3 } label: { CategoryCard(title: "Stock", subtitle: "Count & order", symbol: "shippingbox") }
                    NavigationLink { LearnView() } label: { CategoryCard(title: "Learn", subtitle: "Build your knowledge", symbol: "book") }
                }.buttonStyle(.plain)
                VStack(alignment: .leading, spacing: 14) {
                    HStack { SectionHeader(title: "Popular tonight"); NavigationLink("See all ›") { CocktailLibraryView(venueOnly: true) }.font(.caption).fixedSize() }
                    DrinkShelf(cocktails: store.cocktails.filter(\.isPopular))
                }
                if !store.preferences.recentItems.isEmpty {
                    VStack(alignment: .leading, spacing: 14) { SectionHeader(title: "Recently viewed"); ForEach(Array(store.preferences.recentItems.prefix(5)), id: \.self) { recent in
                        if recent.kind == .cocktail, let drink = store.cocktail(recent.id) { NavigationLink { CocktailDetailView(cocktailID: drink.id) } label: { CocktailListRow(cocktail: drink) } }
                        else if recent.kind == .wine, let wine = store.wine(recent.id) { NavigationLink { WineDetailView(wineID: wine.id) } label: { WineCard(wine: wine) } }
                    } }.buttonStyle(.plain)
                } else { EmptyStateView(title: "Your service, at a glance", message: "Drinks you open will appear here for a faster second look.", systemImage: "clock") }
                NavigationLink { FavouritesView() } label: { HStack { Image(systemName: "heart"); Text("Your favourites"); Spacer(); Image(systemName: "chevron.right").font(.caption) }.barCard() }.buttonStyle(.plain)
                HStack { Spacer(); Label("READY OFFLINE", systemImage: "checkmark.circle").font(.system(size: 10, weight: .medium)).tracking(2).foregroundStyle(BarTheme.muted); Spacer() }.padding(.bottom, 8)
            }.padding(.horizontal, 20).padding(.bottom, 24)
        }.barScreen().toolbar(.hidden, for: .navigationBar).accessibilityIdentifier("home-screen")
    }
}
struct CategoryCard: View {
    var title: String; var subtitle: String; var symbol: String
    var body: some View { VStack(spacing: 9) { Image(systemName: symbol).font(.system(size: 29, weight: .ultraLight)).frame(height: 36); Text(title).font(BarTheme.title(21)); Text(subtitle).font(.system(size: 11)).foregroundStyle(BarTheme.muted).multilineTextAlignment(.center) }.frame(maxWidth: .infinity, minHeight: 112).background(BarTheme.card.opacity(0.92), in: RoundedRectangle(cornerRadius: 15)).foregroundStyle(BarTheme.ink).accessibilityElement(children: .combine) }
}
struct DrinkShelf: View {
    var cocktails: [Cocktail]
    var body: some View { ScrollView(.horizontal, showsIndicators: false) { LazyHStack(alignment: .top, spacing: 12) { ForEach(cocktails) { drink in NavigationLink { CocktailDetailView(cocktailID: drink.id) } label: { DrinkCard(cocktail: drink) }.buttonStyle(.plain) } } }.contentMargins(.bottom, 3) }
}
struct FavouritesView: View {
    @Environment(AppStore.self) var store
    var body: some View { ScrollView { LazyVStack(spacing: 12) {
        if store.preferences.favouriteCocktailIDs.isEmpty && store.preferences.favouriteWineIDs.isEmpty { EmptyStateView(title: "Keep the good ones close", message: "Tap the heart on a cocktail or wine to save it here.", systemImage: "heart") }
        ForEach(store.cocktails.filter { store.preferences.favouriteCocktailIDs.contains($0.id) }) { c in NavigationLink { CocktailDetailView(cocktailID: c.id) } label: { CocktailListRow(cocktail: c) } }
        ForEach(store.wines.filter { store.preferences.favouriteWineIDs.contains($0.id) }) { w in NavigationLink { WineDetailView(wineID: w.id) } label: { WineCard(wine: w) } }
    }.padding(20).buttonStyle(.plain) }.barScreen().navigationTitle("Favourites").navigationBarTitleDisplayMode(.inline) }
}
