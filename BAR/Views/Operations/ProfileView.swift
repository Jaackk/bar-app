import SwiftUI
import UniformTypeIdentifiers
import BARCore

struct BARDataDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let contents = configuration.file.regularFileContents, contents.count <= BackupService.maximumBytes else { throw DataValidationError.invalid("Choose a BAR file under 256 MB.") }
        data = contents
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

private struct ContentReviewView: View {
    @Environment(AppStore.self) private var store
    @State private var selected: ContentConflict?
    @State private var confirming = false
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                Text("Your saved version stays active until you choose otherwise. Accept only approved venue content.").font(.subheadline).foregroundStyle(.secondary)
                if store.contentConflicts.isEmpty { EmptyStateView(title: "Nothing awaiting review", message: "Approved updates will appear here when they conflict with saved content.", systemImage: "checkmark.seal") }
                ForEach(store.contentConflicts) { conflict in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(conflict.name).font(BarTheme.title(24))
                        Text("Saved version").font(.headline)
                        Text(store.currentContentSummary(conflict)).font(.subheadline)
                        Divider()
                        Text("Proposed version").font(.headline)
                        Text(store.proposedContentSummary(conflict)).font(.subheadline)
                        Button("Keep my saved version") { store.resolveContent(conflict, acceptIncoming: false) }.frame(minHeight: 44)
                        Button("Accept proposed version…") { selected = conflict; confirming = true }.frame(minHeight: 44)
                    }.barCard()
                }
            }.padding(20)
        }.barScreen().navigationTitle("Content review").navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("Replace the saved content for this record?", isPresented: $confirming, titleVisibility: .visible) {
                Button("Accept proposed content", role: .destructive) { if let selected { store.resolveContent(selected, acceptIncoming: true) }; selected = nil }
                Button("Cancel", role: .cancel) { selected = nil }
            } message: { Text("Operational quantities and user photos remain intact. The previous state is preserved in a safety copy.") }
    }
}

struct ProfileView: View {
    @Environment(AppStore.self) private var store
    @State private var confirmReset = false
    @State private var importing = false
    @State private var restoring = false
    @State private var exporting = false
    @State private var exportDocument: BARDataDocument?
    @State private var pendingRestore: AppSnapshot?
    @State private var confirmRestore = false
    @FocusState private var editingName: Bool
    private var version: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 18) {
                    Image(systemName: "person.crop.circle").font(.system(size: 54, weight: .ultraLight)).foregroundStyle(BarTheme.olive)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(store.preferences.employeeName.isEmpty ? "Your bar companion" : store.preferences.employeeName).font(BarTheme.title(29))
                        Text(store.venue.name).font(.subheadline).foregroundStyle(.secondary)
                    }
                }.padding(.vertical, 6)
                VStack(alignment: .leading, spacing: 18) {
                    SectionHeader(title: "Your details")
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Employee name").font(.caption).foregroundStyle(.secondary)
                        TextField("Your name", text: preference(\.employeeName)).textContentType(.givenName)
                            .font(.body).submitLabel(.done).focused($editingName).onSubmit { editingName = false }.padding(.vertical, 9)
                            .accessibilityIdentifier("employee-name")
                    }
                    Divider()
                    HStack(alignment: .top) {
                        Label("Venue", systemImage: "mappin.and.ellipse")
                        Spacer()
                        VStack(alignment: .trailing, spacing: 5) {
                            Text(store.venue.name).fontWeight(.medium)
                            Text(store.venue.location).font(.caption).foregroundStyle(.secondary)
                        }
                    }.font(.subheadline)
                }.barCard()
                VStack(alignment: .leading, spacing: 18) {
                    SectionHeader(title: "Service preferences")
                    Picker("Default classic specification", selection: preference(\.classicDefault)) {
                        Text("Custom · venue").tag(ClassicSpecification.custom)
                        Text("Recommended").tag(ClassicSpecification.recommended)
                    }.pickerStyle(.segmented).accessibilityIdentifier("global-classic-specification")
                    Text("Custom is the Rockwater default. Individual drinks can override this choice. Switching never edits either recipe.").font(.caption).foregroundStyle(.secondary)
                    Divider()
                    HStack { Text("Recipe measurements"); Spacer(); Picker("Recipe measurements", selection: preference(\.units)) { Text("ml").tag("ml"); Text("cl").tag("cl") }.pickerStyle(.segmented).frame(width: 135) }
                    Divider()
                    Stepper(value: preference(\.defaultWastage), in: 0...20, step: 1) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Default batch wastage").font(.subheadline)
                            Text("\(MeasurementFormatter.number(store.preferences.defaultWastage))%").font(.title3.weight(.semibold).monospacedDigit()).foregroundStyle(BarTheme.olive)
                        }
                    }
                    Text("Used as the starting allowance when you open the batch calculator.").font(.caption).foregroundStyle(.secondary)
                }.barCard()
                VStack(spacing: 0) {
                    NavigationLink { FavouritesView() } label: { profileRow("Favourites", subtitle: "Your go-to cocktails and wines", symbol: "star") }
                    Divider()
                    NavigationLink { SavedBatchesView() } label: { profileRow("Saved batches", subtitle: "Reopen quantities for another service", symbol: "bookmark") }
                    Divider()
                    NavigationLink { LearnView() } label: { profileRow("Learning progress", subtitle: "Flashcards, quizzes and recipe confidence", symbol: "book") }
                }.barCard().buttonStyle(.plain)
                #if DEBUG
                VStack(alignment: .leading, spacing: 15) {
                    Text("DEVELOPMENT ONLY").font(.caption2.weight(.bold)).tracking(1.8).foregroundStyle(BarTheme.olive)
                    Text("Local role preview").font(BarTheme.title(23))
                    Picker("Development role", selection: Binding(get: { store.role }, set: { store.setRole($0) })) {
                        Text("Bartender").tag(UserRole.bartender)
                        Text("Manager").tag(UserRole.manager)
                        Text("Admin").tag(UserRole.admin)
                    }.pickerStyle(.segmented)
                    Text("Preview role-aware controls in this development build. This is local testing, with no sign-in or shared account.").font(.caption).foregroundStyle(.secondary).lineSpacing(3)
                }.barCard()
                #endif
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Owner tools")
                    Text("Unlock with this iPhone’s device authentication. This protects local maintenance controls; it is not a shared venue account or staff permission system.").font(.caption).foregroundStyle(.secondary)
                    if store.ownerUnlocked {
                        Button("Lock owner tools") { store.lockOwner() }.frame(minHeight: 44)
                    } else {
                        Button { Task { await store.unlockOwner() } } label: { Label(store.unlockingOwner ? "Unlocking…" : "Unlock owner tools", systemImage: "lock.open").frame(minHeight: 44) }.disabled(store.unlockingOwner)
                    }
                }.barCard()
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Backup & recovery")
                    Text("Export a complete copy to Files, including your photos, counts, lists and preferences. Keep a copy outside this iPhone.").font(.subheadline).foregroundStyle(.secondary)
                    Button("Export BAR backup") { exportData { try store.exportBackup() } }.frame(minHeight: 44).disabled(store.persistenceBlocked)
                    Button("Export previous safety copy") { exportData { try store.exportSafetyBackup() } }.frame(minHeight: 44)
                    if store.persistenceBlocked { Button("Export preserved recovery file") { exportData { try store.exportRecovery() } }.frame(minHeight: 44) }
                    if store.role.canEditContent { Button("Restore a BAR backup…") { restoring = true }.frame(minHeight: 44) }
                }.barCard()
                if store.role.canEditContent {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "Manager tools")
                        NavigationLink { ProductCatalogueView() } label: { profileRow("Product catalogue", subtitle: "Add, edit and remove products", symbol: "square.grid.2x2") }.buttonStyle(.plain)
                        NavigationLink { StocktakeView() } label: { profileRow("Stocktake", subtitle: "Counts, par levels and suggested orders", symbol: "shippingbox") }.buttonStyle(.plain)
                        Text("Import approved catalogue and recipe content. New records are added; conflicting saved records wait for review. Counts, pars, photos, lists and personal data stay intact.")
                            .font(.subheadline).foregroundStyle(.secondary).lineSpacing(3)
                        NavigationLink { ContentReviewView() } label: { profileRow("Content review", subtitle: "\(store.contentConflicts.count) saved records need a decision", symbol: "doc.text.magnifyingglass") }.buttonStyle(.plain)
                        PrimaryButton(title: "Import venue JSON", systemImage: "square.and.arrow.down") { importing = true }
                    }.barCard()
                }
                NavigationLink { AboutBARView() } label: {
                    profileRow("About BAR", subtitle: "Version \(version) · Built for service", symbol: "info.circle").barCard()
                }.buttonStyle(.plain)
                VStack(alignment: .leading, spacing: 12) {
                    Label("Available offline", systemImage: "checkmark.icloud").font(.subheadline.weight(.medium)).foregroundStyle(BarTheme.olive)
                    Text("Recipes and your changes are stored on this iPhone. Shared venue sync can be connected in a future version.").font(.caption).foregroundStyle(.secondary).lineSpacing(3)
                }
                if store.role.canEditContent { Button(role: .destructive) { confirmReset = true } label: {
                    Label("Reset local data", systemImage: "arrow.counterclockwise").font(.subheadline).frame(minHeight: 44)
                } }
            }.padding(20)
        }.barScreen().navigationTitle("Profile").navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .confirmationDialog("Reset all local data?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Reset local data", role: .destructive) { store.resetLocalData() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This removes your name, preferences, favourites, history, training progress, saved batches, prep, wastage and stock changes, restock and order lists, then restores the bundled menu and reference content.")
            }
            .fileExporter(isPresented: $exporting, document: exportDocument, contentType: .json, defaultFilename: "BAR-backup") { result in
                if case .failure(let error) = result { store.errorMessage = "The export could not be saved: \(error.localizedDescription)" }
            }
            .fileImporter(isPresented: $restoring, allowedContentTypes: [.json]) { result in
                do {
                    let url = try result.get()
                    let accessed = url.startAccessingSecurityScopedResource()
                    defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                    pendingRestore = try BackupService.read(BackupService.readFile(url))
                    confirmRestore = true
                } catch { store.errorMessage = "This backup could not be restored. Your current data is unchanged. \(error.localizedDescription)" }
            }
            .confirmationDialog("Replace this iPhone’s BAR data?", isPresented: $confirmRestore, titleVisibility: .visible) {
                Button("Restore validated backup", role: .destructive) { if let pendingRestore { store.restoreBackup(pendingRestore) }; pendingRestore = nil }
                Button("Cancel", role: .cancel) { pendingRestore = nil }
            } message: {
                Text("The backup contains \(pendingRestore?.stock.count ?? 0) saved counts, \(pendingRestore?.stockLists.count ?? 0) list entries and \(pendingRestore?.batches.count ?? 0) batches. A safety copy of your current data is saved before replacement. Export a backup to Files first if you want a separate copy.")
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                switch result {
                case .success(let url):
                    let accessed = url.startAccessingSecurityScopedResource()
                    defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                    store.importContent(url: url)
                case .failure(let error): store.errorMessage = "The file could not be opened: \(error.localizedDescription)"
                }
            }
    }

    private func exportData(_ make: () throws -> Data) {
        do { exportDocument = BARDataDocument(data: try make()); exporting = true }
        catch { store.errorMessage = "Export could not be prepared: \(error.localizedDescription)" }
    }
    private func preference<Value>(_ keyPath: WritableKeyPath<UserPreferences, Value>) -> Binding<Value> {
        Binding(get: { store.preferences[keyPath: keyPath] }, set: { value in
            var updated = store.preferences
            updated[keyPath: keyPath] = value
            store.updatePreferences(updated)
        })
    }

    private func profileRow(_ title: String, subtitle: String, symbol: String) -> some View {
        HStack(spacing: 13) {
            Image(systemName: symbol).font(.title3).foregroundStyle(BarTheme.olive).frame(width: 26)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.body.weight(.medium))
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
        }.padding(.vertical, 12).frame(minHeight: 56)
    }
}

struct AboutBARView: View {
    private var version: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0" }
    private var build: String { Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("BAR").font(.system(size: 52, weight: .light, design: .serif)).tracking(8)
                Text("Great drinks.\nConfident people.").font(BarTheme.title(32))
                Text("Your operating companion for a great service: cocktail specifications, thoughtful wine recommendations, accurate batches, fresh prep and clear stock counts.").font(.body).lineSpacing(5)
                VStack(alignment: .leading, spacing: 14) {
                    SectionHeader(title: "About the recipes")
                    Text("Venue content and professional classic references are separate. Custom shows venue measures; Recommended shows a researched reference. Each classic’s source panel records its verification date and meaningful variations. Wine descriptions and pairings are editorial guidance, not live availability. Always check the actual products and current venue specification.").font(.subheadline).lineSpacing(4)
                    Text("Always follow your venue’s verified allergen, storage and service procedures.").font(.subheadline).lineSpacing(4)
                }.barCard()
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "On your device")
                    Text("BAR works offline with bundled recipes and local storage. This version has no sign-in, analytics or cloud sync. Counts, favourites, user photos and learning progress are stored locally. Exported backups contain that data and are shared only through destinations you choose. Optional image downloads contact the URL you supply, which exposes your network address to that host. Imported images remain local. The repository menu checker does not run in the app.").font(.subheadline).lineSpacing(4)
                }.barCard()
                Text("Version \(version) (\(build)) · iOS 17+").font(.caption).foregroundStyle(.secondary)
            }.padding(24)
        }.barScreen().navigationTitle("About BAR").navigationBarTitleDisplayMode(.inline)
    }
}
