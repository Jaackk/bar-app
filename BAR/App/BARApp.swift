import SwiftUI
import BARCore

@main struct BARApp: App {
    @State private var store: AppStore
    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--uitesting") {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("BAR-UITests")
            let repository = LocalAppRepository(directory: url)
            if !ProcessInfo.processInfo.arguments.contains("--keep-state") { _ = try? repository.reset() }
            _store = State(initialValue: AppStore(repository: repository))
        } else { _store = State(initialValue: AppStore()) }
        #else
        _store = State(initialValue: AppStore())
        #endif
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground(); appearance.backgroundColor = UIColor(BarTheme.card)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    var body: some Scene { WindowGroup { RootView().environment(store).tint(BarTheme.olive).preferredColorScheme(.light) } }
}
struct RootView: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        @Bindable var store = store
        TabView(selection: $store.selectedTab) {
            NavigationStack { HomeView() }.tabItem { Label("Home", systemImage: "house") }.tag(0)
            NavigationStack { SearchView() }.tabItem { Label("Search", systemImage: "magnifyingglass") }.tag(1)
            NavigationStack { PrepView() }.tabItem { Label("Prep", systemImage: "list.clipboard") }.tag(2)
            NavigationStack { StockView() }.tabItem { Label("Stock", systemImage: "shippingbox") }.tag(3)
            NavigationStack { WastageView() }.tabItem { Label("Wastage", systemImage: "drop.triangle") }.tag(4)
        }.font(.body).alert("Local data", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) { Button("OK") { store.errorMessage = nil } } message: { Text(store.errorMessage ?? "") }
    }
}
