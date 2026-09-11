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

    init(repository: any AppRepository = LocalAppRepository()) {
        self.repository = repository
        do { snapshot = try repository.load(); lastSavedSnapshot = snapshot }
        catch {
            snapshot = (try? SeedLoader.load()) ?? AppSnapshot()
            errorMessage = "Your saved data could not be opened. Sample content is available for reference. Reset local data in Profile to recover. \(error.localizedDescription)"
            persistenceBlocked = true
            lastSavedSnapshot = snapshot
        }
    }
    var venue: Venue { snapshot.venues.first(where: { $0.id == preferences.venueID }) ?? snapshot.venues.first ?? Venue(id: "unconfigured", name: "BAR") }
    var cocktails: [Cocktail] { VenueResolver.cocktails(snapshot.cocktails, venueID: preferences.venueID) }
    var wines: [Wine] { snapshot.wines.filter { $0.isActive && ($0.venueID == nil || $0.venueID == preferences.venueID) } }
    var prep: [PrepItem] { snapshot.prep.filter { $0.venueID == preferences.venueID } }
    var stock: [StockItem] { snapshot.stock.filter { $0.venueID == preferences.venueID } }
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
        guard !persistenceBlocked else { if let lastSavedSnapshot { snapshot = lastSavedSnapshot }; errorMessage = "Saved data needs recovery. Reset local data in Profile before making changes."; return }
        do { try repository.save(snapshot); lastSavedSnapshot = snapshot }
        catch { if let lastSavedSnapshot { snapshot = lastSavedSnapshot }; errorMessage = "This change could not be saved: \(error.localizedDescription)" }
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
    func updateStock(id: String, count: Double) {
        guard count.isFinite, count >= 0, let i = snapshot.stock.firstIndex(where: { $0.id == id && $0.venueID == preferences.venueID }) else { return }
        snapshot.stock[i].currentStock = min(count, 100_000); save(); Haptics.selection()
    }
    func updatePar(id: String, par: Double) {
        guard role.canEditContent, par.isFinite, par >= 0, let i = snapshot.stock.firstIndex(where: { $0.id == id && $0.venueID == preferences.venueID }) else { return }
        snapshot.stock[i].parLevel = min(par, 100_000); save()
    }
    func recordTraining(cocktailID: String, correct: Bool) { snapshot.training.record(correct: correct, cocktailID: cocktailID); save() }
    func resetLocalData() {
        do { snapshot = try repository.reset(); lastSavedSnapshot = snapshot; errorMessage = nil; persistenceBlocked = false; selectedTab = 0 }
        catch { errorMessage = "Reset failed: \(error.localizedDescription)" }
    }
    func saveBatch(cocktailID: String, serves: Int, wastage: Double) {
        guard serves > 0, let drink = cocktail(cocktailID) else { return }
        snapshot.batches.insert(SavedBatch(id: UUID().uuidString, cocktailID: cocktailID, name: drink.name, serves: serves, wastagePercent: wastage), at: 0)
        snapshot.batches = Array(snapshot.batches.prefix(30)); save(); Haptics.success()
    }
    func startPrep(cocktailID: String, serves: Int, wastage: Double) {
        guard let drink = cocktail(cocktailID), serves > 0 else { return }
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
