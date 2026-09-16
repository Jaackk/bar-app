import SwiftUI
import BARCore

struct WineFinderView: View {
    @Environment(AppStore.self) var store
    @State private var query = ""
    @State private var tastes: Set<String> = []
    @State private var colour: WineColour? = nil
    @State private var moreTastes = false
    private let tasteOptions = ["Dry", "Crisp", "Floral", "Rich", "Light", "Full", "Sweet", "Fruity", "Mineral", "Oaky"]
    private var recommendations: [WineRecommendation] { WineRecommender.recommend(wines: store.wines, query: query, tastes: tastes, colour: colour) }
    var body: some View {
        ScrollView { LazyVStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 16) {
                HStack { Text("A LITTLE GUIDANCE, A GREAT GLASS").font(.system(size: 9, weight: .semibold)).tracking(1.5); Spacer(); Image(systemName: "wineglass").font(.system(size: 28, weight: .ultraLight)) }.foregroundStyle(BarTheme.sage)
                Text("What does the guest like?").font(BarTheme.title(29)).foregroundStyle(.white)
                Text("Find the perfect wine for their taste.").font(.subheadline).foregroundStyle(.white.opacity(0.8))
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(moreTastes ? tasteOptions : Array(tasteOptions.prefix(6)), id: \.self) { taste in Button { if tastes.contains(taste) { tastes.remove(taste) } else { tastes.insert(taste) } } label: { Text(taste).font(.subheadline.weight(tastes.contains(taste) ? .semibold : .regular)).frame(maxWidth: .infinity, minHeight: 44).foregroundStyle(BarTheme.ink).background(tastes.contains(taste) ? BarTheme.sage : BarTheme.cream, in: Capsule()).overlay(Capsule().stroke(tastes.contains(taste) ? .white : .clear, lineWidth: 2)) }.accessibilityAddTraits(tastes.contains(taste) ? .isSelected : []) }
                }
                Button { moreTastes.toggle() } label: { Label(moreTastes ? "Fewer tastes" : "More tastes", systemImage: moreTastes ? "minus" : "plus").font(.caption).foregroundStyle(.white).frame(minHeight: 30) }
            }.padding(22).background(BarTheme.olive, in: RoundedRectangle(cornerRadius: 20))
            SearchBar(text: $query, placeholder: "e.g. Sauvignon Blanc, steak, seafood…")
            VStack(alignment: .leading, spacing: 8) {
                Text("PAIR WITH FOOD").font(.caption.weight(.semibold)).tracking(1.5).foregroundStyle(BarTheme.muted)
                ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 8) {
                    ForEach(["Steak", "Fish", "Chicken", "Spicy", "Pasta", "Seafood"], id: \.self) { food in
                        Button { query = food.lowercased() } label: { TagChip(title: food, selected: query.localizedCaseInsensitiveCompare(food) == .orderedSame) }.frame(minHeight: 44)
                    }
                } }
            }
            ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 8) { Button { colour = nil } label: { TagChip(title: "All wines", selected: colour == nil) }; ForEach(WineColour.allCases, id: \.self) { value in Button { colour = value } label: { TagChip(title: value == .rose ? "Rosé" : value.rawValue.capitalized, selected: colour == value) } } }.frame(minHeight: 44) }
            HStack { SectionHeader(title: "Recommended for you", subtitle: "Hove menu · \(recommendations.count) matches"); if !query.isEmpty || !tastes.isEmpty || colour != nil { Button("Reset") { query = ""; tastes = []; colour = nil }.font(.caption).frame(minHeight: 44) } }
            if recommendations.isEmpty { EmptyStateView(title: "Let’s broaden the choice", message: "Try fewer taste filters or search for a grape, region or food pairing.", systemImage: "wineglass") }
            ForEach(recommendations) { recommendation in NavigationLink { WineDetailView(wineID: recommendation.wine.id) } label: { WineCard(wine: recommendation.wine, reason: recommendation.reasons.first) }.buttonStyle(.plain) }
        }.padding(20) }.barScreen().navigationTitle("Wine Finder").navigationBarTitleDisplayMode(.inline).scrollDismissesKeyboard(.interactively)
    }
}
struct WineCard: View {
    var wine: Wine
    var reason: String? = nil
    var body: some View { HStack(alignment: .top, spacing: 12) {
        WineBottleArt(wine: wine)
            .frame(width: 90, height: 144)
            .padding(.vertical, 2)
        VStack(alignment: .leading, spacing: 7) {
            Text(wine.name).font(BarTheme.title(20)).foregroundStyle(BarTheme.ink)
            Text(wine.description).font(.caption).foregroundStyle(BarTheme.muted).lineLimit(3)
            HStack(spacing: 4) { ForEach(wineTags(wine).prefix(3), id: \.self) { Text($0).font(.system(size: 10)).padding(.horizontal, 9).padding(.vertical, 5).background(BarTheme.sage.opacity(0.5), in: Capsule()) } }
            Text((wine.foodPairings.isEmpty ? "Suggested pairing: " : "Pairs with: ") + WinePairingGuide.pairings(wine).prefix(3).joined(separator: ", ")).font(.caption2).foregroundStyle(BarTheme.muted)
            if let reason { Text(reason).font(.caption2.weight(.medium)).foregroundStyle(BarTheme.olive) }
        }; Spacer(minLength: 0)
    }.barCard().accessibilityElement(children: .combine) }
}
private func wineTags(_ wine: Wine) -> [String] { [wine.sweetness <= 2 ? "Dry" : "Sweet", wine.body <= 2 ? "Light" : wine.body >= 4 ? "Full" : "Medium", wine.acidity >= 4 ? "Crisp" : "Soft"] }
struct WineBottleArt: View {
    @Environment(AppStore.self) private var store
    let wine: Wine
    private var colour: Color { switch wine.colour { case .red: Color(red: 0.29, green: 0.13, blue: 0.19); case .rose: BarTheme.coral; case .white: Color(red: 0.62, green: 0.66, blue: 0.33); case .sparkling: BarTheme.olive; case .orange: Color.orange; case .dessert: Color(red: 0.65, green: 0.43, blue: 0.18) } }
    var body: some View { GeometryReader { proxy in
        switch WineProductResolver.imageSource(for: wine, products: store.products) {
        case .customProductImage(let product), .bundledProductImage(let product):
            ProductThumbnail(product: product)
        case .wineImage(let imageName) where UIImage(named: imageName) != nil:
            Image(imageName).resizable().scaledToFit()
        case .wineImage, .fallback:
            VStack(spacing: 0) { RoundedRectangle(cornerRadius: 3).fill(colour.opacity(0.95)).frame(width: proxy.size.width * 0.27, height: proxy.size.height * 0.3); ZStack { UnevenRoundedRectangle(topLeadingRadius: 12, bottomLeadingRadius: 5, bottomTrailingRadius: 5, topTrailingRadius: 12).fill(colour); RoundedRectangle(cornerRadius: 2).fill(BarTheme.cream).frame(width: proxy.size.width * 0.64, height: proxy.size.height * 0.27).overlay(Text(wine.grape.prefix(1)).font(BarTheme.title(15)).foregroundStyle(BarTheme.ink)) }.frame(height: proxy.size.height * 0.65) }.frame(maxWidth: .infinity).shadow(color: BarTheme.ink.opacity(0.08), radius: 3, y: 4)
        }
    }.clipped().accessibilityHidden(true) }
}
struct WineDetailView: View {
    @Environment(AppStore.self) var store
    var wineID: String
    var body: some View { Group { if let wine = store.wine(wineID) { ScrollView { VStack(alignment: .leading, spacing: 22) {
        HStack { Spacer(); WineBottleArt(wine: wine).frame(width: 156, height: 300); Spacer() }
            .padding(.vertical, 12).padding(.horizontal, 20)
            .frame(maxWidth: .infinity).background(BarTheme.stone.opacity(0.6), in: RoundedRectangle(cornerRadius: 20))
        VStack(alignment: .leading, spacing: 10) { if wine.isSample { SampleLabel() }; Text(wine.name).font(BarTheme.title(32)); Text([wine.producer, wine.region, wine.country].filter { !$0.isEmpty }.joined(separator: " · ")).font(.subheadline).foregroundStyle(BarTheme.muted); Text(wine.description).font(.body); HStack { ForEach(wineTags(wine), id: \.self) { TagChip(title: $0) } } }
        VStack(alignment: .leading, spacing: 12) { Label("How to describe it to a guest", systemImage: "quote.opening").font(.headline); Text("“\(wine.guestDescription)”").font(BarTheme.title(23)) }.barCard()
        VStack(alignment: .leading, spacing: 10) { SectionHeader(title: "At a glance", subtitle: wine.id.hasPrefix("hove-wine-") ? "Taste scales are approximate style guidance" : nil); LabeledContent("Grape", value: wine.grape.isEmpty ? "Not listed on menu" : wine.grape); LabeledContent("Style", value: wine.style); LabeledContent("Body", value: "\(wine.body) / 5"); LabeledContent("Acidity", value: "\(wine.acidity) / 5"); LabeledContent("Tannin", value: "\(wine.tannin) / 5") }.font(.subheadline).barCard()
        VStack(alignment: .leading, spacing: 12) { SectionHeader(title: "Food pairings", subtitle: wine.foodPairings.isEmpty ? "Suggested from wine style · confirm with the guest" : nil); ForEach(WinePairingGuide.pairings(wine), id: \.self) { Text($0.capitalized).font(.subheadline) } }
        VStack(alignment: .leading, spacing: 10) { SectionHeader(title: "Service notes"); Text(wine.servingNotes).font(.subheadline).foregroundStyle(BarTheme.muted) }
        if !wine.similarTo.isEmpty { VStack(alignment: .leading, spacing: 10) { SectionHeader(title: "If they usually enjoy…"); Text(wine.similarTo.joined(separator: ", ")).font(.subheadline) } }
    }.padding(20) }.barScreen().navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .principal) { Text("Wine detail").font(BarTheme.title(18)) }; ToolbarItem(placement: .topBarTrailing) { Button { store.toggleWineFavourite(wine.id) } label: { Image(systemName: store.preferences.favouriteWineIDs.contains(wine.id) ? "heart.fill" : "heart") }.accessibilityLabel(store.preferences.favouriteWineIDs.contains(wine.id) ? "Remove favourite" : "Favourite wine") } }.onAppear { store.recordRecent(id: wine.id, kind: .wine) } } else { EmptyStateView(title: "Wine unavailable", message: "This wine may have been removed from the current list.", systemImage: "wineglass").barScreen() } } }
}
