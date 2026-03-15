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

                AboutView(viewModel: viewModel)
                    .tabItem {
                        Label(LocalizedStringKey("tab.about"), systemImage: "info.circle")
                    }
            }
            .toolbarBackground(.ultraThinMaterial, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
            .liquidGlassBackground()
            .environment(\.locale, Locale(identifier: viewModel.selectedLanguage.localeIdentifier))
        }
    }
}
