import SwiftUI

@main
struct HexoReaderApp: App {
    @StateObject private var viewModel = BlogViewModel()

    var body: some Scene {
        WindowGroup {
            TabView {
                BlogListView(viewModel: viewModel)
                    .tabItem {
                        Label(LocalizedStringKey("tab.posts"), systemImage: "newspaper")
                    }

                NavigationStack {
                    SettingsView(viewModel: viewModel, dismissAfterSave: false)
                }
                .tabItem {
                    Label(LocalizedStringKey("tab.settings"), systemImage: "gearshape")
                }
            }
            .toolbarBackground(.ultraThinMaterial, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
            .background(.ultraThinMaterial)
            .environment(\.locale, Locale(identifier: viewModel.selectedLanguage.localeIdentifier))
            .preferredColorScheme(nil)
        }
    }
}
