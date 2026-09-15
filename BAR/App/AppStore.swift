import SwiftUI
import BARCore

@MainActor @Observable final class AppStore {
    private let repository: any AppRepository
    private var snapshot: AppSnapshot
    private var lastSavedSnapshot: AppSnapshot?
    var errorMessage: String?
    var persistenceBlocked = false
    var selectedTab = 0
    var searchQuery = ""
    var shouldFocusSearch = false

    init(repository: any AppRepository = LocalAppRepository()) {
        self.repository = repository
        do { snapshot = try repository.load(); lastSavedSnapshot = snapshot }
        catch {
            snapshot = (try? SeedLoader.load()) ?? AppSnapshot()
            errorMessage = "Your saved data could not be opened. BAR is showing its bundled reference content and your existing data has not been changed. Reset local data in Profile only if recovery is needed."
            persistenceBlocked = true
            lastSavedSnapshot = snapshot
        }
    }
    var venue: Venue { snapshot.venues.first(where: { $0.id == preferences.venueID }) ?? snapshot.venues.first ?? Venue(id: "unconfigured", name: "BAR") }
    var cocktails: [Cocktail] { VenueResolver.cocktails(snapshot.cocktails, venueID: preferences.venueID) }
    var wines: [Wine] { snapshot.wines.filter { $0.isActive && ($0.venueID == nil || $0.venueID == preferences.venueID) } }
    var prep: [PrepItem] { snapshot.prep.filter { $0.venueID == preferences.venueID } }
    var stock: [StockItem] {
        products.map { product in
            var item = snapshot.stock.first { $0.venueID == preferences.venueID && ($0.id == product.id || SearchNormalizer.normalize($0.name) == SearchNormalizer.normalize(product.name)) } ?? StockItem(id: product.id, name: product.name, venueID: preferences.venueID)
            item.id = product.id; item.name = product.name; item.category = product.category; item.unit = product.unit
            return item
        }
    }
    var preferences: UserPreferences { snapshot.preferences }
    var training: TrainingProgress { snapshot.training }
    var user: User { snapshot.user }
    var batches: [SavedBatch] { snapshot.batches.filter { batch in cocktails.contains { $0.id == batch.cocktailID } } }
    var role: UserRole {
        #if DEBUG
        snapshot.user.role
        #else
        .bartender
        #endif
    }
    func cocktail(_ id: String) -> Cocktail? { cocktails.first { $0.id == id } }
    func wine(_ id: String) -> Wine? { wines.first { $0.id == id } }
    private func save() {
        guard !persistenceBlocked else { if let lastSavedSnapshot { snapshot = lastSavedSnapshot }; errorMessage = "BAR could not save this change because local data needs recovery. Your existing data has not been changed."; return }
        do { try repository.save(snapshot); lastSavedSnapshot = snapshot }
        catch { if let lastSavedSnapshot { snapshot = lastSavedSnapshot }; errorMessage = "This change could not be saved: \(error.localizedDescription)" }
    }
    /// Writes a complete candidate first, then publishes it.  Deletion is invoked from
    /// List swipe actions, where changing the observed source collection before a write
    /// succeeds can otherwise leave UIKit holding a stale row identity.
    private func commit(_ candidate: AppSnapshot) -> Bool {
        guard !persistenceBlocked else {
            errorMessage = "BAR could not save this change because local data needs recovery. Your existing data has not been changed."
            return false
        }
        do {
            try repository.save(candidate)
            snapshot = candidate
            lastSavedSnapshot = candidate
            return true
        } catch {
            errorMessage = "This change could not be saved: \(error.localizedDescription)"
            return false
        }
    }
    func toggleCocktailFavourite(_ id: String) {
        if snapshot.preferences.favouriteCocktailIDs.contains(id) { snapshot.preferences.favouriteCocktailIDs.remove(id) }
        else { snapshot.preferences.favouriteCocktailIDs.insert(id) }
        save(); Haptics.selection()
    }
    func toggleWineFavourite(_ id: String) {
        if snapshot.preferences.favouriteWineIDs.contains(id) { snapshot.preferences.favouriteWineIDs.remove(id) }
        else { snapshot.preferences.favouriteWineIDs.insert(id) }
        save(); Haptics.selection()
    }
    func recordRecent(id: String, kind: RecentKind) { snapshot.preferences.recordRecent(id: id, kind: kind); save() }
    func updatePreferences(_ value: UserPreferences) { snapshot.preferences = value; snapshot.user.name = value.employeeName; save() }
    func setRole(_ role: UserRole) {
        #if DEBUG
        snapshot.user.role = role; save()
        #endif
    }
    func updateRole(_ role: UserRole) { setRole(role) }
    func updatePrep(id: String, current: Double) {
        guard current.isFinite, current >= 0, let i = snapshot.prep.firstIndex(where: { $0.id == id && $0.venueID == preferences.venueID }) else { return }
        snapshot.prep[i].currentAmount = current
        snapshot.prep[i].completed = current >= snapshot.prep[i].targetAmount
        save()
    }
    func completePrep(id: String) {
        guard let i = snapshot.prep.firstIndex(where: { $0.id == id && $0.venueID == preferences.venueID }) else { return }
        snapshot.prep[i].currentAmount = snapshot.prep[i].targetAmount
        snapshot.prep[i].completed = true; snapshot.prep[i].lastPreparedDate = Date()
        save(); Haptics.success()
    }
    func reopenPrep(id: String) {
        guard let i = snapshot.prep.firstIndex(where: { $0.id == id && $0.venueID == preferences.venueID }) else { return }
        snapshot.prep[i].completed = false; snapshot.prep[i].currentAmount = 0; save()
    }
    func savePrep(_ item: PrepItem) {
        guard item.venueID == preferences.venueID,
              !item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              item.targetAmount >= 0 else { return }
        if let index = snapshot.prep.firstIndex(where: { $0.id == item.id }) {
            snapshot.prep[index] = item
        } else {
            snapshot.prep.append(item)
        }
        save()
    }
    func deletePrep(id: String) {
        let venueID = preferences.venueID
        guard snapshot.prep.contains(where: { $0.id == id && $0.venueID == venueID }) else { return }
        var candidate = snapshot
        candidate.prep.removeAll { $0.id == id && $0.venueID == venueID }
        if commit(candidate) { Haptics.selection() }
    }
    func removeExamplePrep() {
        let venueID = preferences.venueID
        guard snapshot.prep.contains(where: { $0.venueID == venueID && $0.isSample }) else { return }
        var candidate = snapshot
        candidate.prep.removeAll { $0.venueID == venueID && $0.isSample }
        if commit(candidate) { Haptics.selection() }
    }
    var products: [Product] { snapshot.products.filter { $0.venueID == preferences.venueID && $0.isActive } }
    func listItems(_ kind: StockListKind) -> [StockListItem] { snapshot.stockLists.filter { $0.kind == kind && $0.venueID == preferences.venueID } }
    func listText(_ kind: StockListKind) -> String { StockListService.text(snapshot.stockLists, kind: kind, venueID: preferences.venueID) }
    func addProduct(_ product: Product, to kind: StockListKind) {
        guard products.contains(where: { $0.id == product.id }) else { return }
        StockListService.add(product, kind: kind, to: &snapshot.stockLists)
        snapshot.preferences.recordProductUse(product.id)
        save(); Haptics.selection()
    }
    func setProductQuantity(_ product: Product, kind: StockListKind, quantity: Int) {
        guard products.contains(where: { $0.id == product.id }) else { return }
        var candidate = snapshot
        if let item = candidate.stockLists.first(where: { $0.venueID == product.venueID && $0.kind == kind && $0.productID == product.id }) {
            StockListService.setQuantity(quantity, id: item.id, venueID: product.venueID, in: &candidate.stockLists)
        } else if quantity > 0 {
            candidate.stockLists.append(StockListItem(venueID: product.venueID, kind: kind, productID: product.id, name: product.name, quantity: min(quantity, 100_000), unit: kind == .order ? product.defaultOrderUnit : product.unit))
        }
        if quantity > 0 { candidate.preferences.recordProductUse(product.id) }
        if commit(candidate) { Haptics.selection() }
    }
    func setListQuantity(id: String, quantity: Int) {
        var candidate = snapshot
        StockListService.setQuantity(quantity, id: id, venueID: preferences.venueID, in: &candidate.stockLists)
        _ = commit(candidate)
    }
    func clearList(_ kind: StockListKind) {
        var candidate = snapshot
        StockListService.clear(kind, venueID: preferences.venueID, in: &candidate.stockLists)
        _ = commit(candidate)
    }
    func addCustomItem(name: String, quantity: Int, kind: StockListKind) {
        let clean = name.components(separatedBy: .newlines).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, clean.count <= 200, (1...100_000).contains(quantity) else { return }
        snapshot.stockLists.append(StockListItem(venueID: preferences.venueID, kind: kind, name: clean, quantity: quantity)); save()
    }
    func saveProduct(_ product: Product) {
        guard product.venueID == preferences.venueID, !product.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if let previous = products.first(where: { $0.id == product.id }), let i = snapshot.stock.firstIndex(where: { $0.venueID == product.venueID && ($0.id == product.id || SearchNormalizer.normalize($0.name) == SearchNormalizer.normalize(previous.name)) }) {
            snapshot.stock[i].id = product.id; snapshot.stock[i].name = product.name; snapshot.stock[i].category = product.category; snapshot.stock[i].unit = product.unit
        }
        if let i = snapshot.products.firstIndex(where: { $0.id == product.id && $0.venueID == preferences.venueID }) { snapshot.products[i] = product }
        else { snapshot.products.append(product) }
        for i in snapshot.stockLists.indices where snapshot.stockLists[i].productID == product.id {
            snapshot.stockLists[i].name = product.name
            snapshot.stockLists[i].unit = snapshot.stockLists[i].kind == .order ? product.defaultOrderUnit : product.unit
        }
        save()
    }
    func deleteProduct(_ product: Product) {
        guard let i = snapshot.products.firstIndex(where: { $0.id == product.id && $0.venueID == preferences.venueID }) else { return }
        var candidate = snapshot
        candidate.products[i].isActive = false
        if commit(candidate) { Haptics.selection() }
    }
    private func storedStockIndex(_ id: String) -> Int? {
        guard let product = products.first(where: { $0.id == id }) else { return nil }
        if let i = snapshot.stock.firstIndex(where: { $0.venueID == preferences.venueID && ($0.id == id || SearchNormalizer.normalize($0.name) == SearchNormalizer.normalize(product.name)) }) {
            snapshot.stock[i].id = id; return i
        }
        snapshot.stock.append(StockItem(id: id, name: product.name, venueID: preferences.venueID))
        return snapshot.stock.count - 1
    }
    func updateStock(id: String, count: Double) {
        guard count.isFinite, count >= 0, let i = storedStockIndex(id) else { return }
        snapshot.stock[i].currentStock = min(count, 100_000); save(); Haptics.selection()
    }
    func updatePar(id: String, par: Double) {
        guard role.canEditContent, par.isFinite, par >= 0, let i = storedStockIndex(id) else { return }
        snapshot.stock[i].parLevel = min(par, 100_000); save()
    }
    func recordTraining(cocktailID: String, correct: Bool) { snapshot.training.record(correct: correct, cocktailID: cocktailID); save() }
    func resetLocalData() {
        do { snapshot = try repository.reset(); lastSavedSnapshot = snapshot; errorMessage = nil; persistenceBlocked = false; selectedTab = 0 }
        catch { errorMessage = "Reset failed: \(error.localizedDescription)" }
    }
    func saveBatch(cocktailID: String, serves: Int, wastage: Double) {
        guard serves > 0, let drink = cocktail(cocktailID), drink.recipeVerified else { return }
        snapshot.batches.insert(SavedBatch(id: UUID().uuidString, cocktailID: cocktailID, name: drink.name, serves: serves, wastagePercent: wastage), at: 0)
        snapshot.batches = Array(snapshot.batches.prefix(30)); save(); Haptics.success()
    }
    func startPrep(cocktailID: String, serves: Int, wastage: Double) {
        guard let drink = cocktail(cocktailID), drink.recipeVerified, serves > 0 else { return }
        let result = BatchCalculator.calculate(cocktail: drink, serves: serves, wastagePercent: wastage)
        let recipe = result.lines.map { line in Ingredient(name: line.ingredient.name, amount: line.quantity, unit: line.unit, batchBehaviour: line.behaviour, notes: line.ingredient.notes, prepComponent: line.ingredient.prepComponent) }
        var item = PrepItem(id: UUID().uuidString, name: "\(drink.name) · \(serves) serves")
        item.venueID = preferences.venueID; item.category = "Cocktail Batches"; item.targetAmount = Double(serves); item.unit = .piece
        item.recipeYieldAmount = Double(serves); item.recipe = recipe; item.method = result.notes
        item.storageInstructions = "Label with preparation date and keep refrigerated. Keep service additions separate."
        item.shelfLife = "Follow the verified venue specification; fresh citrus batches are best prepared for the current service."
        item.notes = "\(MeasurementFormatter.number(wastage))% wastage included in batch ingredients."
        item.isSample = drink.isSample
        snapshot.prep.insert(item, at: 0); save(); Haptics.success()
    }
    func updateCocktail(_ cocktail: Cocktail) {
        guard role.canEditContent, cocktail.venueID == preferences.venueID else { return }
        if let i = snapshot.cocktails.firstIndex(where: { $0.id == cocktail.id }) { snapshot.cocktails[i] = cocktail; save() }
    }
    func importContent(url: URL) {
        guard role.canEditContent else { return }
        do {
            let merged = try ContentImportService.merge(data: Data(contentsOf: url), preserving: snapshot)
            try repository.save(merged); snapshot = merged; lastSavedSnapshot = merged; Haptics.success()
        } catch { errorMessage = "Import was not applied: \(error.localizedDescription)" }
    }
}

enum Haptics {
    static func selection() { UISelectionFeedbackGenerator().selectionChanged() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
}
