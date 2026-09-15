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
    @State private var adding = false
    @State private var custom = false
    @State private var editing: StockListItem?
    @State private var clear = false
    @State private var copied = false
    private var items: [StockListItem] { store.listItems(kind) }
    private var quickPicks: [Product] {
        let selectedIDs = store.listItems(.restock).map(\.productID) + store.listItems(.order).map(\.productID)
        let usage = Dictionary(selectedIDs.compactMap { $0 }.map { ($0, 1) }, uniquingKeysWith: +)
        let nightEssentials = ["Ice Cubes", "Limes", "Lemons", "Soda Water", "Tonic Water", "Coca-Cola", "Pineapple Juice", "Mint", "Basil", "Cocktail Cherries"]
        return store.products.sorted {
            let left = usage[$0.id, default: 0], right = usage[$1.id, default: 0]
            if left != right { return left > right }
            let lEssential = nightEssentials.contains($0.name), rEssential = nightEssentials.contains($1.name)
            if lEssential != rEssential { return lEssential }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }.prefix(10).map { $0 }
    }
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(kind == .restock ? "What does the bar need?" : "Build the order list.").font(BarTheme.title(29))
                    Text(items.isEmpty ? "Add products as you go." : "\(items.count) products · \(items.reduce(0) { $0 + $1.quantity }) units").font(.subheadline).foregroundStyle(.secondary)
                }.padding(.vertical, 10)
                Button { adding = true } label: {
                    HStack { Image(systemName: "magnifyingglass"); Text("Search products…"); Spacer(); Image(systemName: "plus.circle.fill") }.foregroundStyle(BarTheme.olive).padding(.vertical, 10)
                }.accessibilityIdentifier("add-products")
            }.listRowBackground(BarTheme.card)
            Section("Quick add") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(quickPicks) { product in
                            Button { store.addProduct(product, to: kind) } label: {
                                VStack(alignment: .leading, spacing: 7) {
                                    ProductThumbnail(product: product).frame(width: 62, height: 62)
                                    Text(product.name).font(.caption.weight(.medium)).lineLimit(2).frame(width: 82, alignment: .leading)
                                    Text("Add").font(.caption2.weight(.semibold)).foregroundStyle(BarTheme.olive)
                                }.frame(width: 82, alignment: .leading)
                            }.buttonStyle(.plain)
                        }
                    }.padding(.vertical, 5)
                }
            }.listRowBackground(BarTheme.card)
            if items.isEmpty {
                Section {
                    EmptyStateView(title: kind == .restock ? "Nothing needed yet." : "No products added.", message: kind == .restock ? "Search for a product to start a restock list." : "Search or add an item to build the order.", systemImage: kind == .restock ? "tray" : "cart")
                }.listRowBackground(Color.clear)
            } else {
                Section(kind.heading) {
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
        }.listStyle(.insetGrouped).scrollContentBackground(.hidden).barScreen().navigationTitle(kind.title).navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { Menu {
                Button(copied ? "Copied" : "Copy List", systemImage: "doc.on.doc") { UIPasteboard.general.string = store.listText(kind); copied = true }
                ShareLink(item: store.listText(kind)) { Label("Share List", systemImage: "square.and.arrow.up") }
                Button(kind == .restock ? "Clear Restock List" : "Clear Order", systemImage: "trash", role: .destructive) { clear = true }
            } label: { Image(systemName: "ellipsis.circle") }.accessibilityLabel("List actions").disabled(items.isEmpty) }
        }
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: "Add products", systemImage: "plus") { adding = true }.padding(.horizontal, 20).padding(.vertical, 10).background(BarTheme.cream)
        }
        .confirmationDialog("Clear this list?", isPresented: $clear, titleVisibility: .visible) {
            Button(kind == .restock ? "Clear Restock List" : "Clear Order", role: .destructive) {
                Task { @MainActor in store.clearList(kind) }
            }
        }
        .sheet(isPresented: $adding) { ProductPicker(kind: kind) { adding = false } }
        .sheet(isPresented: $custom) { ListItemEditor { name, quantity in store.addCustomItem(name: name, quantity: quantity, kind: kind) } }
        .sheet(item: $editing) { item in ListItemEditor(item: item) { _, quantity in store.setListQuantity(id: item.id, quantity: quantity) } }
        .onChange(of: items) { _, _ in copied = false }
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
            Button(action: decrement) { Image(systemName: "minus").frame(width: 38, height: 44) }.accessibilityLabel("Decrease \(name)")
            Button { edit?() } label: { Text("\(quantity)").font(.subheadline.weight(.semibold).monospacedDigit()).frame(minWidth: 28, minHeight: 44) }.disabled(edit == nil).accessibilityLabel("Edit \(name) quantity").accessibilityValue("\(quantity)")
            Button(action: increment) { Image(systemName: "plus").frame(width: 38, height: 44) }.accessibilityLabel("Increase \(name)")
        }.buttonStyle(.borderless).foregroundStyle(BarTheme.olive).background(BarTheme.sage.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
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
