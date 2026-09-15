import SwiftUI
import UniformTypeIdentifiers
import BARCore

struct ProfileView: View {
    @Environment(AppStore.self) private var store
    @State private var confirmReset = false
    @State private var importing = false
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
                if store.role.canEditContent {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "Manager tools")
                        NavigationLink { ProductCatalogueView() } label: { profileRow("Product catalogue", subtitle: "Add, edit and remove products", symbol: "square.grid.2x2") }.buttonStyle(.plain)
                        NavigationLink { StocktakeView() } label: { profileRow("Stocktake", subtitle: "Counts, par levels and suggested orders", symbol: "shippingbox") }.buttonStyle(.plain)
                        Text("Import a validated BAR content snapshot to replace the loaded venue records, prep and stock. Your profile, favourites and learning progress are preserved.")
                            .font(.subheadline).foregroundStyle(.secondary).lineSpacing(3)
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
                Button(role: .destructive) { confirmReset = true } label: {
                    Label("Reset local data", systemImage: "arrow.counterclockwise").font(.subheadline).frame(minHeight: 44)
                }
            }.padding(20)
        }.barScreen().navigationTitle("Profile").navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .confirmationDialog("Reset all local data?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Reset local data", role: .destructive) { store.resetLocalData() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This removes your name, preferences, favourites, history, training progress, saved batches, prep and stock changes, restock and order lists, then restores the bundled menu and reference content.")
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

private struct AboutBARView: View {
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
                    Text("Venue drinks and wines come from Rockwater Hove’s official drinks menu, checked 11 September 2026. House recipes use the supplied PDF and spreadsheet specifications, imported 15 September 2026. Source exceptions are noted in the recipe. Wine matching uses approximate style guidance. Classic recipes are common modern starting points; house specifications can override them.").font(.subheadline).lineSpacing(4)
                    Text("Always follow your venue’s verified allergen, storage and service procedures.").font(.subheadline).lineSpacing(4)
                }.barCard()
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "On your device")
                    Text("BAR works offline with bundled recipes and local storage. This version has no sign-in, analytics or cloud sync. Counts, favourites and learning progress remain on your device.").font(.subheadline).lineSpacing(4)
                }.barCard()
                Text("Version \(version) (\(build)) · iOS 17+").font(.caption).foregroundStyle(.secondary)
            }.padding(24)
        }.barScreen().navigationTitle("About BAR").navigationBarTitleDisplayMode(.inline)
    }
}
