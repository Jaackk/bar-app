import SwiftUI
import BARCore
import LocalAuthentication

@MainActor @Observable final class AppStore {
    private let persistence: SnapshotPersistenceCoordinator
    private var snapshot: AppSnapshot
    private(set) var classicLibrary: [ClassicReference] = []
    private(set) var ownerUnlocked = false
    private(set) var unlockingOwner = false
    private var stockSaveTask: Task<Void, Never>?
    private var hasPendingStockChanges = false
    var errorMessage: String?
    var persistenceBlocked = false
    var selectedTab = 0
    var searchQuery = ""
    var shouldFocusSearch = false
    var serviceDate = Date()

    init(repository: any AppRepository = LocalAppRepository()) {
        let initialSnapshot: AppSnapshot
        var initialError: String?
        do { initialSnapshot = try repository.load() }
        catch {
            initialSnapshot = (try? SeedLoader.load()) ?? AppSnapshot()
            initialError = "Your saved data could not be opened. BAR is showing its bundled reference content and your existing data has not been changed. Reset local data in Profile only if recovery is needed."
        }
        do { classicLibrary = try ClassicSpecifications.load() }
        catch { initialError = "The classic reference library could not be opened. Your saved data is preserved. \(error.localizedDescription)" }
        snapshot = initialSnapshot
        persistence = SnapshotPersistenceCoordinator(repository: repository, initialSnapshot: initialSnapshot)
        errorMessage = initialError
        persistenceBlocked = initialError != nil
    }
    var venue: Venue { snapshot.venues.first(where: { $0.id == preferences.venueID }) ?? snapshot.venues.first ?? Venue(id: "unconfigured", name: "BAR") }
    var rawCocktails: [Cocktail] {
        let visible = VenueResolver.cocktails(snapshot.cocktails, venueID: preferences.venueID)
        let venueReferences = Set(visible.filter { $0.venueID != nil }.compactMap { classicReference($0.id)?.id })
        let primary = visible.filter { drink in
            guard drink.venueID == nil, let reference = classicReference(drink.id) else { return true }
            return !venueReferences.contains(reference.id)
        }
        // Historical house supersession hid Dirty Martini alongside Dry Martini.
        // Distinct reference identities remain findable without duplicating specs.
        let visibleIDs = Set(primary.map(\.id))
        let distinctReferences = snapshot.cocktails.filter { drink in
            guard drink.isActive, drink.venueID == nil, !visibleIDs.contains(drink.id), let reference = classicReference(drink.id) else { return false }
            return !venueReferences.contains(reference.id)
        }
        return primary + distinctReferences
    }
    var cocktails: [Cocktail] { rawCocktails.map { ClassicSpecifications.resolve($0, preferences: preferences, library: classicLibrary) } }
    var alternativeClassicSearchTerms: [String: [String]] {
        Dictionary(uniqueKeysWithValues: rawCocktails.map { drink in
            (drink.id, drink.ingredients.map(\.name) + (classicReference(drink.id)?.recommended?.ingredients.map(\.name) ?? []))
        })
    }
    func rawCocktail(_ id: String) -> Cocktail? { snapshot.cocktails.first { $0.id == id } }
    func classicReference(_ id: String) -> ClassicReference? { ClassicSpecifications.reference(for: id, in: classicLibrary) }
    func setClassicOverride(_ value: ClassicSpecification?, cocktailID: String) {
        guard let reference = classicReference(cocktailID) else { return }
        var updated = preferences
        updated.classicOverrides[reference.id] = value
        updatePreferences(updated)
    }
    func specificationLabel(_ drink: Cocktail) -> String {
        drink.displaySpecification == .recommended ? "Recommended" : "Custom · \(venue.name)"
    }
    var contentConflicts: [ContentConflict] { snapshot.contentConflicts }
    func currentContentSummary(_ conflict: ContentConflict) -> String {
        switch conflict.kind {
        case "cocktail": return snapshot.cocktails.first(where: { $0.id == conflict.recordID }).map(recipeSummary) ?? "Record unavailable"
        case "product": return snapshot.products.first(where: { $0.id == conflict.recordID }).map(productSummary) ?? "Record unavailable"
        case "wine": return snapshot.wines.first(where: { $0.id == conflict.recordID }).map(wineSummary) ?? "Record unavailable"
        default: return "Unsupported content"
        }
    }
    func proposedContentSummary(_ conflict: ContentConflict) -> String {
        let decoder = SeedLoader.makeDecoder()
        switch conflict.kind {
        case "cocktail": return (try? decoder.decode(Cocktail.self, from: conflict.proposed)).map(recipeSummary) ?? "Cannot read proposed recipe"
        case "product": return (try? decoder.decode(Product.self, from: conflict.proposed)).map(productSummary) ?? "Cannot read proposed product"
        case "wine": return (try? decoder.decode(Wine.self, from: conflict.proposed)).map(wineSummary) ?? "Cannot read proposed wine"
        default: return "Unsupported content"
        }
    }
    private func recipeSummary(_ value: Cocktail) -> String {
        ([value.name] + value.ingredients.map { "\($0.measurement) · \($0.name) · \($0.batchBehaviour.label)" } + [value.method, "Glass: \(value.glass) · Ice: \(value.ice)", "Garnish: \(value.garnish)"] + value.prepInstructions + [value.serviceNotes]).filter { !$0.isEmpty }.joined(separator: "\n")
    }
    private func productSummary(_ value: Product) -> String {
        "\(value.name) · \(value.brand)\n\(value.category) · \(value.productType)\nCount: \(value.unit) · Order: \(value.defaultOrderUnit)\n\(value.menuDetails)\nImage reference: \(value.imageName.isEmpty ? "none" : value.imageName)"
    }
    private func wineSummary(_ value: Wine) -> String {
        "\(value.name) · \(value.producer)\n\(value.grape) · \(value.region), \(value.country)\n\(value.colour.label) · \(value.style)\n\(value.guestDescription)\n\(value.servingNotes)"
    }
    func unlockOwner() async {
        guard !unlockingOwner else { return }
        unlockingOwner = true; defer { unlockingOwner = false }
        let context = LAContext()
        do {
            ownerUnlocked = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock catalogue, recipe and recovery tools on this iPhone.")
        } catch { errorMessage = "Owner tools remain locked. Use this iPhone’s passcode or device authentication to unlock them." }
    }
    func lockOwner() { ownerUnlocked = false }
    func exportBackup() throws -> Data {
        flushPendingStockChanges()
        guard !persistenceBlocked else { throw DataValidationError.invalid("Export the preserved recovery file before restoring a backup.") }
        return try BackupService.export(snapshot)
    }
    func exportRecovery() throws -> Data {
        guard let data = try persistence.recoveryData() else { throw DataValidationError.invalid("There is no saved recovery file on this device.") }
        return data
    }
    func exportSafetyBackup() throws -> Data {
        guard let data = try persistence.safetyBackupData() else { throw DataValidationError.invalid("No previous safety copy is available yet.") }
        return data
    }
    private func prepareReplacement() -> Bool {
        // Capture the last tap, not merely the last completed debounce, in recovery.
        if hasPendingStockChanges && !persistenceBlocked && !commit(snapshot) { return false }
        cancelStockSave(); hasPendingStockChanges = false
        return true
    }
    func restoreBackup(_ value: AppSnapshot) {
        guard role.canEditContent else { return }
        guard prepareReplacement() else { return }
        do {
            try persistence.restore(value)
            snapshot = value; persistenceBlocked = false; errorMessage = nil
            selectedTab = 0; Haptics.success()
        } catch { errorMessage = "Restore was not applied. Your previous data is preserved. \(error.localizedDescription)" }
    }
    func resolveContent(_ conflict: ContentConflict, acceptIncoming: Bool) {
        guard role.canEditContent, !persistenceBlocked, prepareReplacement() else { return }
        do {
            let candidate = try ContentUpdateService.resolve(conflict, acceptIncoming: acceptIncoming, in: snapshot)
            // The restore path validates and preserves the complete previous state.
            try persistence.restore(candidate); snapshot = candidate; errorMessage = nil
        } catch { errorMessage = "The update was not applied. \(error.localizedDescription)" }
    }
    var wines: [Wine] { snapshot.wines.filter { $0.isActive && ($0.venueID == nil || $0.venueID == preferences.venueID) } }
    var prep: [PrepItem] { snapshot.prep.filter { $0.venueID == preferences.venueID } }
    var stock: [StockItem] {
        let saved = snapshot.stock.filter { $0.venueID == preferences.venueID }
        let ids = Set(saved.map(\.id))
        let uncounted = products.filter { !ids.contains($0.id) }.map { product in
            var item = StockItem(id: product.id, name: product.name, venueID: product.venueID, category: product.category, unit: product.unit)
            item.hasRecordedCount = false
            return item
        }
        return saved + uncounted
    }
    var preferences: UserPreferences { snapshot.preferences }
    var training: TrainingProgress { snapshot.training }
    var user: User { snapshot.user }
    var batches: [SavedBatch] { snapshot.batches }
    var wastage: [WastageEntry] { snapshot.wastage.filter { $0.venueID == preferences.venueID }.sorted { $0.createdAt > $1.createdAt } }
    var role: UserRole {
        if ownerUnlocked { return .manager }
        #if DEBUG
        return snapshot.user.role
        #else
        return .bartender
        #endif
    }
    func cocktail(_ id: String) -> Cocktail? {
        if let found = cocktails.first(where: { $0.id == id }) { return found }
        if let ref = classicReference(id), let found = cocktails.first(where: { ref.aliases.contains($0.id) }) { return found }
        return nil
    }
    func isCocktailFavourite(_ id: String) -> Bool {
        let aliases = classicReference(id)?.aliases ?? [id]
        return !preferences.favouriteCocktailIDs.isDisjoint(with: aliases)
    }
    func wine(_ id: String) -> Wine? { wines.first { $0.id == id } }
    private func cancelStockSave() {
        stockSaveTask?.cancel()
        stockSaveTask = nil
    }
    private func save() {
        _ = commit(snapshot)
    }
    /// Writes a complete candidate first, then publishes it.  Deletion is invoked from
    /// List swipe actions, where changing the observed source collection before a write
    /// succeeds can otherwise leave UIKit holding a stale row identity.
    private func commit(_ candidate: AppSnapshot) -> Bool {
        cancelStockSave()
        let revision = persistence.reserveWrite()
        hasPendingStockChanges = false
        guard !persistenceBlocked else {
            snapshot = persistence.lastConfirmedSnapshot
            errorMessage = "BAR could not save this change because local data needs recovery. Your existing data has not been changed."
            return false
        }
        do {
            guard try persistence.save(candidate, revision: revision) else { return false }
            snapshot = candidate
            errorMessage = nil
            return true
        } catch {
            snapshot = persistence.lastConfirmedSnapshot
            errorMessage = "This change could not be saved: \(error.localizedDescription)"
            return false
        }
    }
    /// Stock is edited at service speed. Publishing the small in-memory list change
    /// first avoids blocking the main actor on the repository's defensive full-file
    /// read/decode/validate/encode cycle. The repository lock serialises the final
    /// coalesced write. Revisions also cover ordinary saves, imports and resets.
    private func scheduleStockSave(persistAfterDelay: Bool = true) {
        cancelStockSave()
        let revision = persistence.reserveWrite()
        guard !persistenceBlocked else {
            snapshot = persistence.lastConfirmedSnapshot
            hasPendingStockChanges = false
            errorMessage = "BAR could not save this change because local data needs recovery. Your existing data has not been changed."
            return
        }
        hasPendingStockChanges = true
        guard persistAfterDelay else { return }
        let candidate = snapshot
        let persistence = persistence
        stockSaveTask = Task { @MainActor [weak self] in
            // Wait until a short burst of taps has finished before asking the
            // repository to read, validate and rewrite the full local snapshot.
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard !Task.isCancelled else { return }
            let failure = await Task.detached { () -> String? in
                do { try persistence.save(candidate, revision: revision); return nil }
                catch { return error.localizedDescription }
            }.value
            guard let self, persistence.isCurrent(revision) else { return }
            self.stockSaveTask = nil
            self.hasPendingStockChanges = false
            if let failure {
                self.snapshot = persistence.lastConfirmedSnapshot
                self.errorMessage = "This change could not be saved: \(failure)"
            }
        }
    }
    func toggleCocktailFavourite(_ id: String) {
        if isCocktailFavourite(id) { snapshot.preferences.favouriteCocktailIDs.subtract(classicReference(id)?.aliases ?? [id]) }
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
        snapshot.prep[i].completed = false // Count changes do not certify today’s preparation.
        save()
    }
    func completePrep(id: String) {
        guard let i = snapshot.prep.firstIndex(where: { $0.id == id && $0.venueID == preferences.venueID }) else { return }
        snapshot.prep[i].markComplete()
        save(); Haptics.success()
    }
    func reopenPrep(id: String) {
        guard let i = snapshot.prep.firstIndex(where: { $0.id == id && $0.venueID == preferences.venueID }) else { return }
        snapshot.prep[i].completed = false; save()
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
    var catalogueProducts: [Product] { snapshot.products.filter { $0.venueID == preferences.venueID } }
    var products: [Product] { catalogueProducts.filter(\.isActive) }
    func listItems(_ kind: StockListKind) -> [StockListItem] { snapshot.stockLists.filter { $0.kind == kind && $0.venueID == preferences.venueID } }
    func listText(_ kind: StockListKind) -> String { StockListService.text(snapshot.stockLists, kind: kind, venueID: preferences.venueID) }
    func addProduct(_ product: Product, to kind: StockListKind) {
        guard products.contains(where: { $0.id == product.id }) else { return }
        var candidate = snapshot
        StockListService.add(product, kind: kind, to: &candidate.stockLists)
        candidate.preferences.recordProductUse(product.id)
        snapshot = candidate
        scheduleStockSave()
        Haptics.selection()
    }
    func setProductQuantity(_ product: Product, kind: StockListKind, quantity: Int, feedback: Bool = true, persistImmediately: Bool = true) {
        guard products.contains(where: { $0.id == product.id }) else { return }
        var candidate = snapshot
        if let item = candidate.stockLists.first(where: { $0.venueID == product.venueID && $0.kind == kind && $0.productID == product.id }) {
            StockListService.setQuantity(quantity, id: item.id, venueID: product.venueID, in: &candidate.stockLists)
        } else if quantity > 0 {
            candidate.stockLists.append(StockListItem(venueID: product.venueID, kind: kind, productID: product.id, name: product.name, quantity: min(quantity, 100_000), unit: kind == .order ? product.defaultOrderUnit : product.unit))
        }
        if quantity > 0 { candidate.preferences.recordProductUse(product.id) }
        snapshot = candidate
        scheduleStockSave(persistAfterDelay: persistImmediately)
        if feedback { Haptics.selection() }
    }
    /// Used by accelerated steppers: values render immediately while a single final
    /// save is made when the finger lifts, avoiding disk work on every repeat tick.
    func flushStockWorkspaceChanges() { scheduleStockSave() }
    /// Finish a pending burst before iOS can suspend the app. Ordinary taps still
    /// use the debounced background path; only lifecycle transitions flush here.
    func flushPendingStockChanges() {
        guard hasPendingStockChanges else { return }
        save()
    }
    func setListQuantity(id: String, quantity: Int) {
        var candidate = snapshot
        StockListService.setQuantity(quantity, id: id, venueID: preferences.venueID, in: &candidate.stockLists)
        snapshot = candidate
        scheduleStockSave()
    }
    func clearList(_ kind: StockListKind) {
        var candidate = snapshot
        StockListService.clear(kind, venueID: preferences.venueID, in: &candidate.stockLists)
        snapshot = candidate
        scheduleStockSave()
    }
    func addCustomItem(name: String, quantity: Int, unit: String = "item", kind: StockListKind) {
        let clean = name.components(separatedBy: .newlines).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, clean.count <= 200, (1...100_000).contains(quantity) else { return }
        var candidate = snapshot
        candidate.stockLists.append(StockListItem(venueID: preferences.venueID, kind: kind, name: clean, quantity: quantity, unit: unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "item" : unit))
        snapshot = candidate
        scheduleStockSave()
    }
    func saveProduct(_ product: Product) {
        guard role.canEditContent, product.venueID == preferences.venueID, !product.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if let i = snapshot.stock.firstIndex(where: { $0.venueID == product.venueID && $0.id == product.id }) {
            snapshot.stock[i].name = product.name; snapshot.stock[i].category = product.category
            // Changing a catalogue unit cannot convert an already-recorded quantity.
        }
        if let i = snapshot.products.firstIndex(where: { $0.id == product.id && $0.venueID == preferences.venueID }) { snapshot.products[i] = product }
        else { snapshot.products.append(product) }
        for i in snapshot.stockLists.indices where snapshot.stockLists[i].productID == product.id {
            snapshot.stockLists[i].name = product.name
            // Preserve the unit attached to each existing list quantity.
        }
        save()
    }
    func deleteProduct(_ product: Product) {
        guard role.canEditContent, let i = snapshot.products.firstIndex(where: { $0.id == product.id && $0.venueID == preferences.venueID }) else { return }
        var candidate = snapshot
        candidate.products[i].isActive = false
        if commit(candidate) { Haptics.selection() }
    }
    private func storedStockIndex(_ id: String) -> Int? {
        if let i = snapshot.stock.firstIndex(where: { $0.venueID == preferences.venueID && $0.id == id }) { return i }
        guard let product = products.first(where: { $0.id == id }) else { return nil }
        var item = StockItem(id: id, name: product.name, venueID: product.venueID, category: product.category, unit: product.unit)
        item.hasRecordedCount = false
        snapshot.stock.append(item)
        return snapshot.stock.count - 1
    }
    func updateStock(id: String, count: Double) {
        guard count.isFinite, count >= 0, let i = storedStockIndex(id) else { return }
        snapshot.stock[i].hasRecordedCount = true; snapshot.stock[i].currentStock = min(count, 100_000); save(); Haptics.selection()
    }
    func updatePar(id: String, par: Double) {
        guard role.canEditContent, par.isFinite, par >= 0, let i = storedStockIndex(id) else { return }
        snapshot.stock[i].parLevel = min(par, 100_000); save()
    }
    func recordTraining(cocktailID: String, correct: Bool, specification: Cocktail? = nil) {
        snapshot.training.record(correct: correct, cocktailID: cocktailID)
        if correct, let drink = specification ?? cocktail(cocktailID) { snapshot.training.masteredRevisions[cocktailID] = TrainingProgress.revision(for: drink) }
        else { snapshot.training.masteredRevisions.removeValue(forKey: cocktailID) }
        save()
    }
    func resetLocalData() {
        guard role.canEditContent else { return }
        guard prepareReplacement() else { return }
        do { snapshot = try persistence.reset(); errorMessage = nil; persistenceBlocked = false; selectedTab = 0 }
        catch { snapshot = persistence.lastConfirmedSnapshot; errorMessage = "Reset failed: \(error.localizedDescription)" }
    }
    func saveBatch(cocktailID: String, serves: Int, wastage: Double, specification: Cocktail? = nil) {
        guard serves > 0, let drink = specification ?? cocktail(cocktailID), drink.recipeVerified, drink.id == cocktailID else { return }
        var batch = SavedBatch(cocktailID: cocktailID, name: drink.name, serves: serves, wastagePercent: wastage)
        batch.specification = drink
        snapshot.batches.insert(batch, at: 0)
        save(); Haptics.success()
    }
    func addWastage(itemName: String, quantity: Double, unit: String, reason: String) {
        let cleanName = itemName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanUnit = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty, cleanName.count <= 120, quantity.isFinite, (0...100_000).contains(quantity), quantity > 0, !cleanUnit.isEmpty else { return }
        var candidate = snapshot
        candidate.wastage.insert(WastageEntry(venueID: preferences.venueID, itemName: cleanName, quantity: quantity, unit: cleanUnit, reason: reason), at: 0)
        if commit(candidate) { Haptics.success() }
    }
    func deleteWastage(id: String) {
        let venueID = preferences.venueID
        guard snapshot.wastage.contains(where: { $0.id == id && $0.venueID == venueID }) else { return }
        var candidate = snapshot
        candidate.wastage.removeAll { $0.id == id && $0.venueID == venueID }
        if commit(candidate) { Haptics.selection() }
    }
    func startPrep(cocktailID: String, serves: Int, wastage: Double, specification: Cocktail? = nil) {
        guard let drink = specification ?? cocktail(cocktailID), drink.id == cocktailID, drink.recipeVerified, serves > 0 else { return }
        let result = BatchCalculator.calculate(cocktail: drink, serves: serves, wastagePercent: wastage)
        let recipe = result.lines.map { line in
            var ingredient = Ingredient(name: line.ingredient.name, amount: line.quantity, unit: line.unit, batchBehaviour: line.behaviour, notes: line.ingredient.notes, prepComponent: line.ingredient.prepComponent)
            if line.quantity == 0 { ingredient.quantityDisplay = line.ingredient.quantityDisplay }
            return ingredient
        }
        var item = PrepItem(id: UUID().uuidString, name: "\(drink.name) · \(serves) \(serves == 1 ? "serve" : "serves")")
        item.venueID = preferences.venueID; item.category = "Cocktail Batches"; item.targetAmount = Double(serves); item.unit = .piece
        item.recipeYieldAmount = Double(serves); item.recipe = recipe; item.method = result.notes
        item.storageInstructions = "Label with preparation date and keep refrigerated. Keep service additions separate."
        item.shelfLife = "Follow the verified venue specification; fresh citrus batches are best prepared for the current service."
        item.notes = "\(specificationLabel(drink)) · \(MeasurementFormatter.number(wastage))% wastage on batch ingredients. Planning only; no inventory deducted."
        item.isSample = drink.isSample
        snapshot.prep.insert(item, at: 0); save(); Haptics.success()
    }
    func updateCocktail(_ cocktail: Cocktail) {
        guard role.canEditContent, cocktail.venueID == preferences.venueID, cocktail.displaySpecification == nil else { return }
        if let i = snapshot.cocktails.firstIndex(where: { $0.id == cocktail.id }) { snapshot.cocktails[i] = cocktail; save() }
    }
    func importContent(url: URL) {
        guard role.canEditContent, !persistenceBlocked, prepareReplacement() else { return }
        do {
            let merged = try ContentImportService.merge(data: BackupService.readFile(url), preserving: snapshot)
            try persistence.restore(merged)
            snapshot = merged; errorMessage = nil; Haptics.success()
        } catch { errorMessage = "Import was not applied: \(error.localizedDescription)" }
    }
}

enum Haptics {
    static func selection() { UISelectionFeedbackGenerator().selectionChanged() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
}
