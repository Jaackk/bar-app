import SwiftUI
import BARCore

struct StockView: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Keep service flowing.").font(BarTheme.title(32))
                Text("Two simple lists. Everything the bar needs.").font(.subheadline).foregroundStyle(.secondary)
                ForEach(StockListKind.allCases, id: \.self) { kind in
                    NavigationLink { StockListView(kind: kind) } label: {
                        VStack(alignment: .leading, spacing: 18) {
                            HStack {
                                Image(systemName: kind == .restock ? "arrow.down.to.line.compact" : "cart").font(.system(size: 34, weight: .light))
                                Spacer()
                                Image(systemName: "arrow.up.right").font(.title3)
                            }
                            Text(kind.title).font(BarTheme.title(29))
                            Text(kind == .restock ? "Make a quick list of what the bar needs." : "Build a list of products to order.").font(.subheadline)
                            Text(store.listItems(kind).isEmpty ? "Ready when you are" : "\(store.listItems(kind).count) items saved").font(.caption.weight(.medium))
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(24)
                            .foregroundStyle(kind == .restock ? Color.white : BarTheme.ink)
                            .background(kind == .restock ? BarTheme.olive : BarTheme.coral.opacity(0.65), in: RoundedRectangle(cornerRadius: 20))
                    }.buttonStyle(.plain).accessibilityIdentifier("open-\(kind.rawValue)")
                }
                Label("Lists save automatically on this iPhone.", systemImage: "checkmark.icloud").font(.caption).foregroundStyle(.secondary)
            }.padding(20)
        }.barScreen().navigationTitle("Stock").navigationBarTitleDisplayMode(.inline)
    }
}

struct StockListView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let kind: StockListKind
    @State private var query = ""
    @State private var category: String? = nil
    @State private var custom = false
    @State private var editing: StockListItem?
    @State private var clear = false
    @State private var copied = false
    private var items: [StockListItem] { store.listItems(kind) }
    private var matches: [Product] { StockListService.search(store.products, venueID: store.preferences.venueID, query: query, category: category) }
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                Text(kind == .restock ? "What does the bar need?" : "Build the order list.").font(BarTheme.title(29))
                SearchBar(text: $query, placeholder: "Search products…").accessibilityIdentifier("product-search")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Button { category = nil } label: { TagChip(title: "All", selected: category == nil) }
                        ForEach(StockListService.categories, id: \.self) { c in Button { category = c } label: { TagChip(title: c, selected: category == c) } }
                    }.frame(minHeight: 44)
                }.buttonStyle(.plain)
                Button { custom = true } label: { Label("Add custom item", systemImage: "plus.circle").frame(minHeight: 44) }
                if !query.isEmpty || category != nil { catalogue }
                SectionHeader(title: kind.heading, subtitle: "\(items.count) items · saved automatically")
                if items.isEmpty {
                    EmptyStateView(title: kind == .restock ? "Nothing needed yet." : "No products added.", message: kind == .restock ? "Search for a product to start a restock list." : "Search or add an item to build the order.", systemImage: kind == .restock ? "shippingbox" : "cart")
                }
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(item.name).font(BarTheme.title(21))
                                Text(item.productID == nil ? "Custom item" : item.unit.capitalized).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(role: .destructive) { store.setListQuantity(id: item.id, quantity: 0) } label: { Image(systemName: "trash").frame(width: 44, height: 44) }.accessibilityLabel("Remove \(item.name)")
                        }
                        HStack {
                            Text("Quantity").font(.subheadline)
                            Spacer()
                            Button { store.setListQuantity(id: item.id, quantity: item.quantity - 1) } label: { Image(systemName: "minus").frame(width: 44, height: 44).background(BarTheme.stone, in: RoundedRectangle(cornerRadius: 10)) }.accessibilityLabel("Decrease \(item.name)")
                            Button { editing = item } label: { Text("\(item.quantity)").font(.title3.monospacedDigit()).frame(minWidth: 44, minHeight: 44) }.accessibilityLabel("Edit \(item.name) quantity").accessibilityValue("\(item.quantity)")
                            Button { store.setListQuantity(id: item.id, quantity: item.quantity + 1) } label: { Image(systemName: "plus").frame(width: 44, height: 44).background(BarTheme.sage, in: RoundedRectangle(cornerRadius: 10)) }.accessibilityLabel("Increase \(item.name)")
                        }
                    }.barCard().buttonStyle(.plain)
                }
                if query.isEmpty && category == nil { catalogue }
            }.padding(20)
        }.barScreen().navigationTitle(kind.title).navigationBarTitleDisplayMode(.inline).scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 20) {
                Button { UIPasteboard.general.string = store.listText(kind); copied = true } label: { Label(copied ? "Copied" : (kind == .restock ? "Copy List" : "Copy Order"), systemImage: copied ? "checkmark" : "doc.on.doc") }
                ShareLink(item: store.listText(kind)) { Label(kind == .restock ? "Share List" : "Share Order", systemImage: "square.and.arrow.up") }
                Spacer(minLength: 0)
                Button(role: .destructive) { clear = true } label: { Image(systemName: "trash").frame(width: 44, height: 44) }.accessibilityLabel(kind == .restock ? "Clear Restock List" : "Clear Order")
            }.font(.caption.weight(.semibold)).padding(.horizontal, 20).padding(.vertical, 8).background(BarTheme.cream).disabled(items.isEmpty)
        }
        .onChange(of: items) { _, _ in copied = false }
        .confirmationDialog(kind == .restock ? "Clear Restock List?" : "Clear Order?", isPresented: $clear, titleVisibility: .visible) {
            Button(kind == .restock ? "Clear Restock List" : "Clear Order", role: .destructive) { store.clearList(kind) }
        }
        .sheet(isPresented: $custom) { ListItemEditor { name, quantity in store.addCustomItem(name: name, quantity: quantity, kind: kind) } }
        .sheet(item: $editing) { item in ListItemEditor(item: item) { _, quantity in store.setListQuantity(id: item.id, quantity: quantity) } }
    }
    private var catalogue: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Products", subtitle: "\(matches.count) matches · tap + to add")
            if matches.isEmpty { Text("No products found. Try another search or add a custom item.").font(.subheadline).foregroundStyle(.secondary) }
            ForEach(query.isEmpty && category == nil ? Array(matches.prefix(8)) : matches) { product in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(product.name).font(.body.weight(.medium))
                        Text(product.category + " · " + (kind == .order ? product.defaultOrderUnit : product.unit)).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 4)
                    Button { store.addProduct(product, to: kind) } label: { Image(systemName: "plus").font(.headline).frame(width: 48, height: 48).foregroundStyle(.white).background(BarTheme.olive, in: RoundedRectangle(cornerRadius: 12)) }.accessibilityLabel("Add \(product.name)")
                }.barCard()
            }
            if query.isEmpty && category == nil { Text("Search or choose a category to see the full catalogue.").font(.caption).foregroundStyle(.secondary) }
        }
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

struct ProductCatalogueView: View {
    @Environment(AppStore.self) private var store
    @State private var query = ""
    @State private var editing: Product?
    var body: some View {
        List {
            Section { Text("Catalogue changes appear immediately in both lists. Saved list names and quantities are kept when a product is removed.").font(.caption).foregroundStyle(.secondary) }
            ForEach(StockListService.search(store.products, venueID: store.preferences.venueID, query: query)) { product in
                Button { editing = product } label: { VStack(alignment: .leading, spacing: 5) { Text(product.name); Text(product.category).font(.caption).foregroundStyle(.secondary) } }.tint(BarTheme.ink)
                    .swipeActions { Button("Delete", role: .destructive) { store.deleteProduct(product) } }
            }
        }.scrollContentBackground(.hidden).barScreen().searchable(text: $query, prompt: "Search products…").navigationTitle("Product catalogue").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { editing = Product(venueID: store.preferences.venueID, name: "") } label: { Label("Add Product", systemImage: "plus") } } }
        .sheet(item: $editing) { ProductEditor(product: $0) }
    }
}
private struct ProductEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var product: Product
    private var valid: Bool { !product.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !product.unit.isEmpty && !product.defaultOrderUnit.isEmpty }
    var body: some View {
        NavigationStack {
            Form {
                Section("Product") {
                    TextField("Name", text: $product.name)
                    TextField("Brand", text: $product.brand)
                    Picker("Category", selection: $product.category) { ForEach(StockListService.categories, id: \.self) { Text($0).tag($0) } }
                    TextField("Product type", text: $product.productType)
                }
                Section("List units") { TextField("Restock unit", text: $product.unit); TextField("Order unit", text: $product.defaultOrderUnit) }
                if !product.menuDetails.isEmpty { Section("Menu reference") { Text(product.menuDetails).font(.subheadline); if let source = product.sourceURL, let url = URL(string: source) { Link("Official menu · page \(product.sourcePage ?? 1)", destination: url) } } }
                if store.products.contains(where: { $0.id == product.id }) { Button("Delete Product", role: .destructive) { store.deleteProduct(product); dismiss() } }
            }.scrollContentBackground(.hidden).barScreen().navigationTitle("Product").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { product.name = product.name.trimmingCharacters(in: .whitespacesAndNewlines); store.saveProduct(product); dismiss() }.disabled(!valid) }
            }
        }
    }
}
