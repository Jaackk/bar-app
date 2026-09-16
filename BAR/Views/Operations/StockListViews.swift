import SwiftUI
import PhotosUI
import Foundation
import BARCore

struct StockView: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Ready for service.").font(BarTheme.title(32))
                Text("A place for everything the bar needs.").foregroundStyle(.secondary)
                ForEach(StockListKind.allCases, id: \.self) { kind in
                    NavigationLink { StockListView(kind: kind) } label: {
                        VStack(alignment: .leading, spacing: 18) {
                            HStack { Image(systemName: kind == .restock ? "tray.and.arrow.down" : "cart").font(.system(size: 32, weight: .light)); Spacer(); Image(systemName: "arrow.up.right") }
                            Text(kind.title).font(BarTheme.title(30))
                            Text(kind == .restock ? "Make a quick list of what the bar needs." : "Build a list of products to order.").font(.subheadline)
                            Text(store.listItems(kind).isEmpty ? "Start a list" : "\(store.listItems(kind).count) items saved").font(.caption.weight(.semibold))
                        }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundStyle(kind == .restock ? Color.white : BarTheme.ink)
                            .background(kind == .restock ? BarTheme.olive : BarTheme.coral.opacity(0.65), in: RoundedRectangle(cornerRadius: 22))
                    }.buttonStyle(.plain).accessibilityIdentifier("open-\(kind.rawValue)")
                }
                NavigationLink { ProductCatalogueView() } label: {
                    Label("Products & photos", systemImage: "square.grid.2x2").font(.headline).frame(maxWidth: .infinity, minHeight: 54).barCard()
                }.buttonStyle(.plain)
                Text("Changes are saved automatically on this iPhone.").font(.caption).foregroundStyle(.secondary)
            }.padding(20)
        }.barScreen().navigationTitle("Stock").navigationBarTitleDisplayMode(.inline)
    }
}

struct StockListView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let kind: StockListKind
    @State private var selectedGroup: ProductBrowseGroup?
    @State private var wineFilter = "All"
    @State private var productSearch = ""
    @State private var custom = false
    @State private var editing: StockListItem?
    @State private var clear = false
    @State private var copied = false
    private var items: [StockListItem] { store.listItems(kind) }
    private var frequentProducts: [Product] { store.products.filter { store.preferences.productUsage[$0.id, default: 0] > 0 }.sorted { store.preferences.productUsage[$0.id, default: 0] == store.preferences.productUsage[$1.id, default: 0] ? ($0.name < $1.name) : (store.preferences.productUsage[$0.id, default: 0] > store.preferences.productUsage[$1.id, default: 0]) }.prefix(10).map { $0 } }
    private var essentials: [Product] {
        let ids = ["spec-absolut-vodka", "menu-casamigos-blanco", "menu-chardonnay-les-sardine-domaine-lafage", "menu-chenin-blanc-wild-garden", "menu-double-dutch-indian-tonic-water", "menu-double-dutch-skinny-tonic", "spec-whole-milk", "service-skimmed-milk", "service-oat-milk", "menu-orange-juice", "menu-pineapple-juice", "menu-limes"]
        return ids.compactMap { id in store.products.first { $0.id == id } }
    }
    private var displayedProducts: [Product] {
        let query = productSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = query.isEmpty ? store.products : StockListService.search(store.products, venueID: store.preferences.venueID, query: query)
        let filtered = selectedGroup.map { group in base.filter { group.includes($0) } } ?? base
        if query.isEmpty, selectedGroup == nil {
            var seen = Set<String>()
            let preferred = (essentials + frequentProducts).filter { seen.insert($0.id).inserted }
            let ids = Set(preferred.map(\.id))
            return Array((preferred + filtered.filter { !ids.contains($0.id) }.sorted { lhs, rhs in
                let left = store.preferences.productUsage[lhs.id, default: 0] + ProductBrowseGroup.servicePriority(lhs, in: .other)
                let right = store.preferences.productUsage[rhs.id, default: 0] + ProductBrowseGroup.servicePriority(rhs, in: .other)
                return left == right ? lhs.name < rhs.name : left > right
            }).prefix(12))
        }
        let wineFiltered = wineFilter == "All" || selectedGroup != .wine ? filtered : filtered.filter { product in
            if wineFilter == "Sparkling" { return product.category == "Sparkling / Champagne" }
            guard let wine = store.wines.first(where: { $0.productID == product.id }) else { return false }
            switch wineFilter { case "White": return wine.colour == .white; case "Red": return wine.colour == .red; case "Rosé": return wine.colour == .rose; default: return true }
        }
        return wineFiltered.sorted { lhs, rhs in
            let left = store.preferences.productUsage[lhs.id, default: 0] + ProductBrowseGroup.servicePriority(lhs, in: selectedGroup ?? .other)
            let right = store.preferences.productUsage[rhs.id, default: 0] + ProductBrowseGroup.servicePriority(rhs, in: selectedGroup ?? .other)
            return left == right ? lhs.name < rhs.name : left > right
        }
    }
    var body: some View {
        List {
            Section {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(BarTheme.muted)
                    TextField(kind == .restock ? "What does the bar need?" : "What do we need to order?", text: $productSearch).textInputAutocapitalization(.never).accessibilityIdentifier("restock-search")
                    if !productSearch.isEmpty { Button { productSearch = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(BarTheme.muted) }.buttonStyle(.plain) }
                }.padding(.horizontal, 12).frame(minHeight: 44).background(BarTheme.cream, in: RoundedRectangle(cornerRadius: 13))
            }.listRowBackground(Color.clear)
            Section {
                ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 8) {
                    CategoryFilterButton(title: "All", symbol: "square.grid.2x2", selected: selectedGroup == nil) { selectedGroup = nil }
                    ForEach(ProductBrowseGroup.operationalGroups) { group in
                        CategoryFilterButton(title: group.shortTitle, symbol: group.symbol, selected: selectedGroup == group) { selectedGroup = selectedGroup == group ? nil : group; wineFilter = "All" }
                    }
                }.padding(.vertical, 2) }
            }.listRowBackground(Color.clear)
            if selectedGroup == .wine {
                Section { HStack(spacing: 7) { ForEach(["All", "White", "Red", "Rosé", "Sparkling"], id: \.self) { value in
                    Button { wineFilter = wineFilter == value ? "All" : value } label: { TagChip(title: value, selected: wineFilter == value) }.buttonStyle(.plain)
                } } }.listRowBackground(Color.clear)
            }
            Section {
                NavigationLink { StockListReviewView(kind: kind) } label: { HStack { Image(systemName: kind == .restock ? "tray.full" : "cart"); Text(kind == .restock ? "View Restock List" : "View Order").font(.subheadline.weight(.semibold)); Spacer(); Text("\(items.count) · \(items.reduce(0) { $0 + $1.quantity }) units").font(.caption).foregroundStyle(BarTheme.muted); Image(systemName: "chevron.right").font(.caption) }.frame(minHeight: 40) }.buttonStyle(.plain)
            }.listRowBackground(BarTheme.card)
            Section(productSearch.isEmpty ? (selectedGroup?.rawValue ?? "House & frequent") : "Results") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(displayedProducts) { product in ProductGridCell(product: product, kind: kind) }
                }.padding(.vertical, 2)
            }.listRowBackground(Color.clear)
            if !items.isEmpty {
                Section(kind == .restock ? "Current restock" : "Current order") {
                    ForEach(items) { item in
                        let product = store.products.first { $0.id == item.productID }
                        HStack(spacing: 12) {
                            ProductThumbnail(product: product).frame(width: 44, height: 58)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.name).font(.subheadline.weight(.medium)).fixedSize(horizontal: false, vertical: true)
                                Text(item.productID == nil ? "Custom item" : item.unit.capitalized).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            QuantityControl(name: item.name, quantity: item.quantity, decrement: { store.setListQuantity(id: item.id, quantity: item.quantity - 1) }, increment: { store.setListQuantity(id: item.id, quantity: item.quantity + 1) }, edit: { editing = item })
                        }.padding(.vertical, 5)
                        .swipeActions {
                            Button("Remove", role: .destructive) {
                                let id = item.id
                                Task { @MainActor in store.setListQuantity(id: id, quantity: 0) }
                            }
                        }
                        .contextMenu {
                            Button("Edit quantity") { editing = item }
                            Button("Remove", role: .destructive) {
                                let id = item.id
                                Task { @MainActor in store.setListQuantity(id: id, quantity: 0) }
                            }
                        }
                    }
                }.listRowBackground(BarTheme.card)
            }
            Section { Button { custom = true } label: { Label("Add custom item", systemImage: "pencil.line").frame(minHeight: 40) } }.listRowBackground(BarTheme.card)
        }.listStyle(.insetGrouped).listSectionSpacing(8).contentMargins(.top, 0, for: .scrollContent).scrollContentBackground(.hidden).barScreen().navigationTitle(kind.title).navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { Menu {
                Button(copied ? "Copied" : "Copy List", systemImage: "doc.on.doc") { UIPasteboard.general.string = store.listText(kind); copied = true }
                ShareLink(item: store.listText(kind)) { Label("Share List", systemImage: "square.and.arrow.up") }
                Button(kind == .restock ? "Clear Restock List" : "Clear Order", systemImage: "trash", role: .destructive) { clear = true }
            } label: { Image(systemName: "ellipsis.circle") }.accessibilityLabel("List actions").disabled(items.isEmpty) }
        }
        .confirmationDialog("Clear this list?", isPresented: $clear, titleVisibility: .visible) {
            Button(kind == .restock ? "Clear Restock List" : "Clear Order", role: .destructive) {
                Task { @MainActor in store.clearList(kind) }
            }
        }
        .sheet(isPresented: $custom) { ListItemEditor { name, quantity in store.addCustomItem(name: name, quantity: quantity, kind: kind) } }
        .sheet(item: $editing) { item in ListItemEditor(item: item) { _, quantity in store.setListQuantity(id: item.id, quantity: quantity) } }
        .onChange(of: items) { _, _ in copied = false }
    }
}

private struct StockListReviewView: View {
    @Environment(AppStore.self) private var store
    let kind: StockListKind
    @State private var clear = false
    private var items: [StockListItem] { store.listItems(kind) }
    var body: some View {
        List {
            Section("Your list") {
                ForEach(items) { item in
                    let product = store.products.first { $0.id == item.productID }
                    HStack(spacing: 10) {
                        ProductThumbnail(product: product).frame(width: 38, height: 50)
                        VStack(alignment: .leading) { Text(item.name).font(.subheadline.weight(.semibold)); Text(item.unit.capitalized).font(.caption).foregroundStyle(.secondary) }
                        Spacer()
                        QuantityControl(name: item.name, quantity: item.quantity, decrement: { store.setListQuantity(id: item.id, quantity: item.quantity - 1) }, increment: { store.setListQuantity(id: item.id, quantity: item.quantity + 1) })
                    }.swipeActions { Button("Remove", role: .destructive) { store.setListQuantity(id: item.id, quantity: 0) } }
                }
            }
        }.listStyle(.insetGrouped).scrollContentBackground(.hidden).barScreen().navigationTitle(kind == .restock ? "Restock List" : "Stock Order").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItemGroup(placement: .topBarTrailing) {
                ShareLink(item: store.listText(kind)) { Image(systemName: "square.and.arrow.up") }.accessibilityLabel(kind == .restock ? "Share Restock" : "Share Order")
                Button(role: .destructive) { clear = true } label: { Image(systemName: "trash") }.accessibilityLabel(kind == .restock ? "Clear Restock List" : "Clear Order")
            } }
            .confirmationDialog(kind == .restock ? "Clear Restock List?" : "Clear Stock Order?", isPresented: $clear, titleVisibility: .visible) {
                Button("Clear List", role: .destructive) { store.clearList(kind) }
            } message: { Text("This removes all products from this list, not from the catalogue.") }
    }
}

private struct QuantityControl: View {
    var name: String
    var quantity: Int
    var decrement: () -> Void
    var increment: () -> Void
    var edit: (() -> Void)? = nil
    var body: some View {
        HStack(spacing: 0) {
            RepeatQuantityButton(symbol: "minus", name: name, change: decrement).frame(width: 38, height: 44)
            Button { edit?() } label: { Text("\(quantity)").font(.subheadline.weight(.semibold).monospacedDigit()).frame(minWidth: 28, minHeight: 44) }.disabled(edit == nil).accessibilityLabel("Edit \(name) quantity").accessibilityValue("\(quantity)")
            RepeatQuantityButton(symbol: "plus", name: name, change: increment).frame(width: 38, height: 44)
        }.buttonStyle(.borderless).foregroundStyle(BarTheme.olive).background(BarTheme.sage.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct QuickAddProductRow: View {
    @Environment(AppStore.self) private var store
    let product: Product
    let kind: StockListKind
    private var item: StockListItem? { store.listItems(kind).first { $0.productID == product.id } }
    var body: some View {
        HStack(spacing: 12) {
            ProductThumbnail(product: product).frame(width: 42, height: 54)
            VStack(alignment: .leading, spacing: 3) {
                Text(product.name).font(.subheadline.weight(.semibold))
                Text(product.category).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if let item {
                QuantityControl(name: product.name, quantity: item.quantity, decrement: { store.setListQuantity(id: item.id, quantity: item.quantity - 1) }, increment: { store.addProduct(product, to: kind) })
            } else {
                Button { store.addProduct(product, to: kind) } label: { Image(systemName: "plus").frame(width: 42, height: 42).foregroundStyle(.white).background(BarTheme.olive, in: Circle()) }.buttonStyle(.borderless).accessibilityLabel("Add \(product.name)")
            }
        }.padding(.vertical, 4)
    }
}

private enum ProductBrowseGroup: String, CaseIterable, Identifiable {
    case beer = "Beer & Cider", wine = "Wine", sparkling = "Sparkling", spirits = "Spirits", mixers = "Mixers", milk = "Milk", softDrinks = "Soft Drinks", juices = "Juice", syrups = "Syrups & Cordials", fruit = "Fruit / Garnish", herbs = "Herbs", prep = "Prep", other = "Other"
    var id: String { rawValue }
    static let priorityGroups: [ProductBrowseGroup] = [.beer, .wine, .spirits, .mixers, .milk, .juices, .fruit]
    static let operationalGroups: [ProductBrowseGroup] = [.beer, .wine, .spirits, .mixers, .milk, .juices, .fruit, .syrups, .other]
    var shortTitle: String {
        switch self { case .beer: "Beer"; case .juices: "Juice"; case .fruit: "Fruit"; case .syrups: "Syrups"; default: rawValue }
    }
    var categories: Set<String> {
        switch self {
        case .beer: return ["Beer / Cider"]
        case .wine: return ["Wine", "Sparkling / Champagne"]
        case .sparkling: return ["Sparkling / Champagne"]
        case .spirits: return ["Vodka", "Gin", "Rum", "Tequila / Mezcal", "Whisky / Whiskey", "Brandy / Cognac", "Liqueurs / Aperitifs"]
        case .mixers: return ["Mixers"]
        case .softDrinks: return ["Soft Drinks", "Non-Alcoholic"]
        case .juices: return ["Juices"]
        case .syrups: return ["Syrups / Cordials", "Purees", "Bitters"]
        case .fruit: return ["Fresh Fruit", "Garnishes"]
        case .herbs: return ["Fresh Herbs"]
        case .prep: return ["Prep"]
        case .milk: return ["Other"]
        case .other: return ["Other"]
        }
    }
    func includes(_ product: Product) -> Bool {
        switch self {
        case .milk:
            return product.name.localizedCaseInsensitiveContains("milk") || product.name.localizedCaseInsensitiveContains("cream")
        case .other:
            return categories.contains(product.category) && !product.name.localizedCaseInsensitiveContains("milk") && !product.name.localizedCaseInsensitiveContains("cream")
        default: return categories.contains(product.category)
        }
    }
    var symbol: String {
        switch self {
        case .beer: return "mug"
        case .wine, .sparkling: return "wineglass"
        case .spirits: return "flask"
        case .mixers, .softDrinks: return "bubbles.and.sparkles"
        case .milk: return "cup.and.saucer"
        case .juices, .syrups: return "drop"
        case .fruit: return "carrot"
        case .herbs: return "leaf"
        case .prep: return "flask"
        case .other: return "shippingbox"
        }
    }
    static func servicePriority(_ product: Product, in group: ProductBrowseGroup) -> Int {
        let preferred: [String: Int] = [
            "menu-peroni-nastro-azzurro-5": 10_000,
            "menu-chenin-blanc-wild-garden": 10_000,
            "menu-chardonnay-les-sardine-domaine-lafage": 9_500,
            "spec-absolut-vodka": 10_000,
            "menu-casamigos-blanco": 9_500,
            "menu-double-dutch-indian-tonic-water": 10_000,
            "menu-double-dutch-skinny-tonic": 9_500,
            "spec-whole-milk": 10_000,
            "service-skimmed-milk": 9_500,
            "service-oat-milk": 9_000,
            "menu-orange-juice": 10_000,
            "menu-pineapple-juice": 9_500,
            "menu-limes": 10_000
        ]
        return preferred[product.id, default: 0]
    }
}

private struct RestockCategoryCard: View {
    @Environment(AppStore.self) private var store
    let group: ProductBrowseGroup
    let action: () -> Void
    private var products: [Product] { store.products.filter { group.includes($0) } }
    private var representative: Product? {
        let ids: [String] = switch group {
        case .beer: ["menu-peroni-nastro-azzurro-5"]
        case .wine: ["menu-chenin-blanc-wild-garden", "menu-chardonnay-les-sardine-domaine-lafage"]
        case .spirits: ["spec-absolut-vodka", "menu-casamigos-blanco"]
        case .mixers: ["menu-double-dutch-indian-tonic-water"]
        case .milk: ["spec-whole-milk"]
        case .juices: ["menu-orange-juice", "menu-pineapple-juice"]
        case .fruit: ["menu-limes"]
        case .syrups: ["menu-orgeat", "spec-gomme-syrup"]
        default: []
        }
        return ids.compactMap { id in products.first { $0.id == id } }.first ?? products.first
    }
    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                ProductThumbnail(product: representative).frame(maxWidth: .infinity).frame(height: 68)
                Text(group == .fruit ? "Fruit & Garnish" : group.rawValue).font(.caption.weight(.semibold)).foregroundStyle(BarTheme.ink).lineLimit(2).multilineTextAlignment(.center)
                Text("\(products.count) products").font(.system(size: 9, weight: .medium)).foregroundStyle(BarTheme.muted)
            }.frame(maxWidth: .infinity, minHeight: 122, alignment: .top).padding(8)
                .background(BarTheme.cream.opacity(0.78), in: RoundedRectangle(cornerRadius: 14))
                .contentShape(RoundedRectangle(cornerRadius: 14))
        }.buttonStyle(.plain).accessibilityIdentifier("restock-category-\(group.id)").accessibilityLabel("Browse \(group.rawValue)")
    }
}

private struct CategoryFilterButton: View {
    let title: String
    let symbol: String
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: symbol).font(.system(size: 17, weight: .medium))
                Text(title).font(.system(size: 10, weight: .semibold)).lineLimit(1)
            }.frame(width: 62, height: 54)
                .foregroundStyle(selected ? .white : BarTheme.ink)
                .background(selected ? BarTheme.olive : BarTheme.cream, in: RoundedRectangle(cornerRadius: 12))
        }.buttonStyle(.plain).accessibilityLabel("Filter \(title)")
    }
}

private struct ProductBrowser: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let kind: StockListKind
    @State private var group: ProductBrowseGroup?
    @State private var search = ""
    init(kind: StockListKind, initialGroup: ProductBrowseGroup? = nil) {
        self.kind = kind
        _group = State(initialValue: initialGroup)
    }
    private var groups: [ProductBrowseGroup] { ProductBrowseGroup.allCases.filter { value in store.products.contains { value.includes($0) } } }
    private var matches: [Product] {
        guard let group else { return [] }
        return StockListService.search(store.products, venueID: store.preferences.venueID, query: search)
            .filter { group.includes($0) }
            .sorted { lhs, rhs in
                let left = store.preferences.productUsage[lhs.id, default: 0] + ProductBrowseGroup.servicePriority(lhs, in: group)
                let right = store.preferences.productUsage[rhs.id, default: 0] + ProductBrowseGroup.servicePriority(rhs, in: group)
                return left == right ? lhs.name < rhs.name : left > right
            }
    }
    var body: some View {
        NavigationStack {
            Group {
                if let group {
                    VStack(spacing: 0) {
                        ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 10) { ForEach(ProductBrowseGroup.operationalGroups) { value in Button { self.group = value; search = "" } label: { TagChip(title: value == .fruit ? "Fruit" : value.rawValue, selected: group == value) }.frame(minHeight: 46) } }.padding(.horizontal, 16).padding(.vertical, 10) }.buttonStyle(.plain)
                        ScrollView { LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) { ForEach(matches) { product in ProductGridCell(product: product, kind: kind) } }.padding(20) }
                    }
                    .searchable(text: $search, prompt: "Filter (group.rawValue)…")
                    .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Categories") { self.group = nil; search = "" } } }
                    .navigationTitle(group.rawValue)
                } else {
                    ScrollView { LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(groups) { group in
                            Button { self.group = group } label: {
                                VStack(alignment: .leading, spacing: 14) {
                                    Image(systemName: group.symbol).font(.system(size: 31, weight: .light)).frame(width: 58, height: 58).background(BarTheme.sage.opacity(0.32), in: RoundedRectangle(cornerRadius: 16))
                                    Text(group.rawValue).font(BarTheme.title(22)).multilineTextAlignment(.leading)
                                    Text("\(store.products.filter { group.categories.contains($0.category) }.count) products").font(.caption).foregroundStyle(BarTheme.muted)
                                }.frame(maxWidth: .infinity, minHeight: 150, alignment: .leading).padding(16).background(BarTheme.card, in: RoundedRectangle(cornerRadius: 18))
                            }.buttonStyle(.plain).accessibilityIdentifier("browse-category-\(group.id)")
                        }
                    }.padding(20) }
                    .navigationTitle("Browse products")
                }
            }
            .barScreen()
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }
}

private struct ProductWorkspace: View {
    @Environment(AppStore.self) private var store
    let kind: StockListKind
    @State private var group: ProductBrowseGroup
    init(kind: StockListKind, initialGroup: ProductBrowseGroup) {
        self.kind = kind
        _group = State(initialValue: initialGroup)
    }
    private var products: [Product] {
        StockListService.search(store.products, venueID: store.preferences.venueID, query: "")
            .filter { group.includes($0) }
            .sorted { lhs, rhs in
                let left = store.preferences.productUsage[lhs.id, default: 0] + ProductBrowseGroup.servicePriority(lhs, in: group)
                let right = store.preferences.productUsage[rhs.id, default: 0] + ProductBrowseGroup.servicePriority(rhs, in: group)
                return left == right ? lhs.name < rhs.name : left > right
            }
    }
    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(ProductBrowseGroup.priorityGroups) { value in
                            Button { group = value } label: { WorkspaceCategoryButton(group: value, selected: group == value) }
                        }
                    }.padding(.horizontal, 16).padding(.vertical, 4)
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(products) { product in ProductGridCell(product: product, kind: kind) }
                }.padding(.horizontal, 16).padding(.bottom, 12)
            }
        }
        .barScreen()
        .navigationTitle(group.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            NavigationLink { StockListView(kind: kind) } label: {
                Text("View \(kind == .restock ? "Restock" : "Order") List (\(store.listItems(kind).count))  →")
                    .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 48)
                    .foregroundStyle(.white).background(BarTheme.olive, in: RoundedRectangle(cornerRadius: 13))
            }.padding(.horizontal, 16).padding(.vertical, 8).background(BarTheme.stone.opacity(0.94))
        }
    }
}

private struct WorkspaceCategoryButton: View {
    @Environment(AppStore.self) private var store
    let group: ProductBrowseGroup
    let selected: Bool
    private var product: Product? { store.products.first { group.includes($0) && ProductBrowseGroup.servicePriority($0, in: group) > 0 } ?? store.products.first { group.includes($0) } }
    var body: some View {
        VStack(spacing: 4) {
            ProductThumbnail(product: product).frame(width: 42, height: 50)
            Text(group == .fruit ? "Fruit" : group.rawValue).font(.system(size: 10, weight: .semibold)).lineLimit(1)
        }.frame(width: 70, height: 84).padding(5)
            .foregroundStyle(selected ? .white : BarTheme.ink)
            .background(selected ? BarTheme.olive : BarTheme.card, in: RoundedRectangle(cornerRadius: 12))
            .contentShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct ProductGridCell: View {
    @Environment(AppStore.self) private var store
    let product: Product
    let kind: StockListKind
    @State private var editing = false
    private var item: StockListItem? { store.listItems(kind).first { $0.productID == product.id } }
    private var quantity: Int { item?.quantity ?? 0 }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProductThumbnail(product: product).frame(maxWidth: .infinity).frame(height: 76)
            Text(product.name).font(.caption.weight(.semibold)).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading).frame(height: 32, alignment: .topLeading)
            HStack(spacing: 2) {
                RepeatQuantityButton(symbol: "minus", name: product.name) { change(by: -1) }
                    .frame(width: 28, height: 34)
                Button { editing = true } label: { Text("\(quantity)").font(.subheadline.weight(.semibold).monospacedDigit()).frame(maxWidth: .infinity, minHeight: 34).background(BarTheme.stone.opacity(0.55), in: RoundedRectangle(cornerRadius: 9)) }.accessibilityLabel("Set \(product.name) quantity")
                RepeatQuantityButton(symbol: "plus", name: product.name) { change(by: 1) }
                    .frame(width: 28, height: 34)
            }.foregroundStyle(BarTheme.olive).buttonStyle(.plain)
        }.padding(9).background(BarTheme.card, in: RoundedRectangle(cornerRadius: 14))
        .sheet(isPresented: $editing) { ProductQuantityEditor(product: product, kind: kind, current: quantity) }
    }

    private func change(by amount: Int, feedback: Bool = true) {
        store.setProductQuantity(product, kind: kind, quantity: max(0, quantity + amount), feedback: feedback)
    }
}

/// A gesture-first control avoids SwiftUI Button's long-press competition inside
/// scrolling grids. A touch up before the delay is one tap; holding starts a single
/// cancellable repeat stream and stops on the same touch-up event.
private struct RepeatQuantityButton: View {
    let symbol: String
    let name: String
    let change: () -> Void
    @State private var task: Task<Void, Never>?
    @State private var repeated = false
    var body: some View {
        Image(systemName: symbol).frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { _ in begin() }
                .onEnded { _ in end() })
            .accessibilityLabel((symbol == "plus" ? "Increase " : "Decrease ") + name)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { change() }
            .onDisappear { task?.cancel() }
    }
    private func begin() {
        guard task == nil else { return }
        repeated = false
        task = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            repeated = true
            var step = 0
            while !Task.isCancelled {
                change(); step += 1
                let delay: UInt64 = step < 7 ? 105_000_000 : step < 19 ? 52_000_000 : 28_000_000
                try? await Task.sleep(nanoseconds: delay)
            }
        }
    }
    private func end() { let wasRepeated = repeated; task?.cancel(); task = nil; if !wasRepeated { change() } }
}

private struct ProductQuantityEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let product: Product
    let kind: StockListKind
    @State private var text: String
    @FocusState private var focused: Bool
    init(product: Product, kind: StockListKind, current: Int) { self.product = product; self.kind = kind; _text = State(initialValue: current == 0 ? "" : String(current)) }
    var body: some View {
        NavigationStack { VStack(spacing: 22) {
            ProductThumbnail(product: product).frame(width: 96, height: 124)
            Text(product.name).font(BarTheme.title(28)).multilineTextAlignment(.center)
            TextField("Quantity", text: $text).keyboardType(.numberPad).focused($focused).multilineTextAlignment(.center).font(.system(size: 42, weight: .medium, design: .rounded)).frame(maxWidth: .infinity).padding(18).background(BarTheme.card, in: RoundedRectangle(cornerRadius: 16))
            Text("Enter 0 to remove this item from the \(kind.title.lowercased()) list.").font(.caption).foregroundStyle(BarTheme.muted).multilineTextAlignment(.center)
            Spacer()
        }.padding(24).barScreen().navigationTitle("Set quantity").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Done") { store.setProductQuantity(product, kind: kind, quantity: Int(text) ?? 0); dismiss() }.accessibilityIdentifier("quantity-done") }; ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { focused = false } } }
        .onAppear { focused = true }
        }
    }
}

private struct ProductPicker: View {
    @Environment(AppStore.self) private var store
    let kind: StockListKind
    let done: () -> Void
    @State private var query = ""
    @State private var category: String? = nil
    @State private var creating = false
    private var matches: [Product] { StockListService.search(store.products, venueID: store.preferences.venueID, query: query, category: category) }
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Button { category = nil } label: { TagChip(title: "All", selected: category == nil) }
                        ForEach(StockListService.categories, id: \.self) { c in Button { category = c } label: { TagChip(title: c, selected: category == c) } }
                    }.padding(.horizontal, 20).padding(.vertical, 10)
                }.buttonStyle(.plain)
                List {
                    ForEach(matches) { product in
                        let item = store.listItems(kind).first { $0.productID == product.id }
                        HStack(spacing: 12) {
                            ProductThumbnail(product: product).frame(width: 42, height: 54)
                            VStack(alignment: .leading, spacing: 4) { Text(product.name).font(.subheadline.weight(.medium)); Text(product.category).font(.caption).foregroundStyle(.secondary) }
                            Spacer(minLength: 0)
                            if let item {
                                QuantityControl(name: product.name, quantity: item.quantity, decrement: { store.setListQuantity(id: item.id, quantity: item.quantity - 1) }, increment: { store.addProduct(product, to: kind) })
                            } else {
                                Button { store.addProduct(product, to: kind) } label: { Image(systemName: "plus").font(.headline).frame(width: 44, height: 44).foregroundStyle(.white).background(BarTheme.olive, in: Circle()) }.buttonStyle(.borderless).accessibilityLabel("Add \(product.name)")
                            }
                        }.padding(.vertical, 4).listRowBackground(BarTheme.card)
                    }
                    Section { Button { creating = true } label: { Label("Create new product", systemImage: "plus.square").frame(minHeight: 44) } }.listRowBackground(BarTheme.card)
                }.listStyle(.plain).scrollContentBackground(.hidden)
                Button(action: done) { Text("Done · \(store.listItems(kind).count) items in list").font(.headline).frame(maxWidth: .infinity, minHeight: 52).foregroundStyle(.white).background(BarTheme.olive, in: RoundedRectangle(cornerRadius: 14)) }.padding(16).accessibilityIdentifier("picker-done")
            }.barScreen().navigationTitle("Add to \(kind.title)").navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search products…")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { creating = true } label: { Label("New product", systemImage: "plus") } } }
            .sheet(isPresented: $creating) { ProductEditor(product: Product(venueID: store.preferences.venueID, name: query)) }
        }
    }
}

struct ProductThumbnail: View {
    var product: Product?
    private var symbol: String {
        switch product?.category {
        case "Wine", "Sparkling / Champagne": "wineglass"
        case "Beer / Cider": "mug"
        case "Fresh Fruit": "apple.logo"
        case "Fresh Herbs", "Garnishes": "leaf"
        case "Juices", "Syrups / Cordials", "Purees", "Bitters": "drop"
        case "Mixers", "Soft Drinks": "bubbles.and.sparkles"
        case "Prep": "flask"
        default: "waterbottle"
        }
    }
    private var monogram: String {
        String(product?.name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1) ?? "P").uppercased()
    }
    private var bundledFallbackName: String? {
        guard (product?.brand.isEmpty ?? true) else { return nil }
        switch product?.category {
        case "Fresh Fruit": return "fresh-fruit"
        case "Fresh Herbs", "Garnishes": return "fresh-herbs"
        case "Juices", "Syrups / Cordials", "Purees", "Mixers", "Prep": return "bar-staples"
        default: return nil
        }
    }
    var body: some View {
        Group {
            if let data = product?.imageData, let image = UIImage(data: data) { Image(uiImage: image).resizable().scaledToFit() }
            else if let name = product?.imageName, !name.isEmpty, let image = UIImage(named: name) { Image(uiImage: image).resizable().scaledToFit() }
            else if let name = bundledFallbackName, let image = UIImage(named: name) { Image(uiImage: image).resizable().scaledToFill() }
            else {
                ZStack {
                    LinearGradient(colors: [BarTheme.sage.opacity(0.7), BarTheme.cream], startPoint: .topLeading, endPoint: .bottomTrailing)
                    Circle().fill(.white.opacity(0.52)).frame(width: 52, height: 52)
                    Image(systemName: symbol).font(.system(size: 23, weight: .medium)).foregroundStyle(BarTheme.olive)
                    Text(monogram).font(.caption2.bold()).foregroundStyle(BarTheme.olive.opacity(0.6)).offset(x: 18, y: 22)
                }
            }
        }.clipShape(RoundedRectangle(cornerRadius: 10)).accessibilityHidden(true)
    }
}

struct ProductCatalogueView: View {
    @Environment(AppStore.self) private var store
    @State private var query = ""
    @State private var creating = false
    @State private var missingOnly = false
    private var products: [Product] {
        StockListService.search(store.products, venueID: store.preferences.venueID, query: query)
            .filter { !missingOnly || ($0.imageData == nil && $0.imageName.isEmpty) }
    }
    private var missingCount: Int { store.products.filter { $0.imageData == nil && $0.imageName.isEmpty }.count }
    var body: some View {
        List {
            Section {
                Text("One catalogue for Restock, Stock Order, Search and Stocktake. Tap a product to edit its details or photo.").font(.caption).foregroundStyle(.secondary)
                Toggle("Missing Images · \(missingCount)", isOn: $missingOnly).tint(BarTheme.olive)
            }
            ForEach(products) { product in
                NavigationLink { ProductDetailView(productID: product.id) } label: {
                    HStack(spacing: 14) { ProductThumbnail(product: product).frame(width: 44, height: 58); VStack(alignment: .leading, spacing: 5) { Text(product.name); Text(product.category).font(.caption).foregroundStyle(.secondary) } }
                }.listRowBackground(BarTheme.card).swipeActions {
                    Button("Delete", role: .destructive) {
                        let product = product
                        Task { @MainActor in store.deleteProduct(product) }
                    }
                }
            }
        }.scrollContentBackground(.hidden).barScreen().searchable(text: $query, prompt: "Search products…").navigationTitle("Products & photos").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { creating = true } label: { Label("Add Product", systemImage: "plus") } } }
        .sheet(isPresented: $creating) { ProductEditor(product: Product(venueID: store.preferences.venueID, name: "")) }
    }
}
struct ProductDetailView: View {
    @Environment(AppStore.self) private var store
    let productID: String
    @State private var editing = false
    @State private var added: StockListKind?
    var body: some View {
        Group {
            if let product = store.products.first(where: { $0.id == productID }) {
                ScrollView { VStack(alignment: .leading, spacing: 22) {
                    ProductThumbnail(product: product).frame(height: 220).frame(maxWidth: .infinity)
                    Text(product.name).font(BarTheme.title(30))
                    Text([product.brand, product.category, product.productType].filter { !$0.isEmpty }.joined(separator: " · ")).font(.subheadline).foregroundStyle(.secondary)
                    if !product.menuDetails.isEmpty { Text(product.menuDetails).font(.subheadline) }
                    ForEach(StockListKind.allCases, id: \.self) { kind in PrimaryButton(title: added == kind ? "Added to \(kind.title)" : "Add to \(kind.title)", systemImage: added == kind ? "checkmark" : "plus") { store.addProduct(product, to: kind); added = kind } }
                    Button("Edit details & photo") { editing = true }.frame(minHeight: 44)
                }.padding(20) }
                .sheet(isPresented: $editing) { ProductEditor(product: product) }
            } else { EmptyStateView(title: "Product removed", message: "Saved list entries are still available.", systemImage: "shippingbox") }
        }.barScreen().navigationTitle("Product").navigationBarTitleDisplayMode(.inline)
    }
}
struct ProductEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var product: Product
    @State private var photo: PhotosPickerItem?
    @State private var loading = false
    @State private var photoError: String?
    @State private var imageURL = ""
    private var valid: Bool { !product.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !product.unit.isEmpty && !product.defaultOrderUnit.isEmpty && !loading }
    var body: some View {
        NavigationStack {
            Form {
                Section("Photo") {
                    HStack(spacing: 20) {
                        ProductThumbnail(product: product).frame(width: 70, height: 90)
                        VStack(alignment: .leading, spacing: 12) {
                            PhotosPicker(selection: $photo, matching: .images) { Label(loading ? "Loading photo…" : "Choose photo", systemImage: "photo") }.disabled(loading)
                            if product.imageData != nil { Button("Remove replacement", role: .destructive) { photo = nil; product.imageData = nil } }
                        }
                    }
                    if let photoError { Text(photoError).font(.caption).foregroundStyle(.red) }
                    HStack {
                        TextField("Image URL", text: $imageURL).textInputAutocapitalization(.never).keyboardType(.URL).autocorrectionDisabled()
                        Button("Load") { Task { await loadImageURL() } }.disabled(imageURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || loading)
                    }
                    Text("Downloads once and stores a local replacement for offline use.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Product") {
                    TextField("Name", text: $product.name).accessibilityIdentifier("product-name")
                    TextField("Brand", text: $product.brand)
                    Picker("Category", selection: $product.category) { ForEach(StockListService.categories, id: \.self) { Text($0).tag($0) } }
                    TextField("Product type", text: $product.productType)
                    TextField("Search words, comma separated", text: Binding(
                        get: { product.aliases.joined(separator: ", ") },
                        set: { product.aliases = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty } }
                    ))
                }
                Section("List units") { TextField("Restock unit", text: $product.unit); TextField("Order unit", text: $product.defaultOrderUnit) }
                if !product.menuDetails.isEmpty { Section("Reference") { Text(product.menuDetails).font(.caption) } }
                if store.products.contains(where: { $0.id == product.id }) {
                    Button("Delete Product", role: .destructive) {
                        dismiss()
                        Task { @MainActor in store.deleteProduct(product) }
                    }
                }
            }.scrollContentBackground(.hidden).barScreen().navigationTitle(product.name.isEmpty ? "New product" : "Edit product").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { product.name = product.name.trimmingCharacters(in: .whitespacesAndNewlines); store.saveProduct(product); dismiss() }.disabled(!valid) }
            }
            .task(id: photo) {
                guard let photo else { return }; loading = true; photoError = nil
                defer { loading = false }
                do {
                    guard let data = try await photo.loadTransferable(type: Data.self), let image = UIImage(data: data) else { photoError = "This image could not be opened. Try another photo."; return }
                    try Task.checkCancellation()
                    let scale = min(1, 800 / max(image.size.width, image.size.height))
                    let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                    let format = UIGraphicsImageRendererFormat(); format.scale = 1
                    product.imageData = UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }.jpegData(compressionQuality: 0.75)
                } catch is CancellationError { } catch { photoError = "Photo could not be loaded. Please try again." }
            }
        }
    }
    @MainActor private func loadImageURL() async {
        let text = imageURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: text), ["https", "http"].contains(url.scheme?.lowercased() ?? "") else { photoError = "Enter a valid image URL."; return }
        loading = true; photoError = nil
        defer { loading = false }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode), data.count <= 12_000_000, let image = UIImage(data: data) else { photoError = "That URL did not return a usable image."; return }
            let scale = min(1, 800 / max(image.size.width, image.size.height))
            let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let format = UIGraphicsImageRendererFormat(); format.scale = 1
            product.imageData = UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }.jpegData(compressionQuality: 0.75)
        } catch { photoError = "Image download failed. Check the URL and try again." }
    }
}
private struct ListItemEditor: View {
    @Environment(\.dismiss) private var dismiss
    let item: StockListItem?
    let save: (String, Int) -> Void
    @State private var name: String
    @State private var quantity: String
    init(item: StockListItem? = nil, save: @escaping (String, Int) -> Void) {
        self.item = item; self.save = save
        _name = State(initialValue: item?.name ?? ""); _quantity = State(initialValue: String(item?.quantity ?? 1))
    }
    private var valid: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 200 && (1...100_000).contains(Int(quantity) ?? 0) }
    var body: some View {
        NavigationStack {
            Form {
                Section("Item") { TextField("Item name", text: $name).disabled(item != nil).accessibilityIdentifier("custom-name") }
                Section("Quantity") { TextField("Quantity", text: $quantity).keyboardType(.numberPad).accessibilityIdentifier("list-quantity") }
                Text("Enter a whole quantity from 1 to 100,000.").font(.caption).foregroundStyle(.secondary)
            }.scrollContentBackground(.hidden).barScreen().navigationTitle(item == nil ? "Custom item" : "Edit quantity").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { guard valid, let value = Int(quantity) else { return }; save(name, value); dismiss() }.disabled(!valid) }
            }
        }
    }
}
