import SwiftUI

private enum AppTab: Hashable {
    case posts
    case about
}

@main
struct HexoReaderApp: App {
    @StateObject private var viewModel = BlogViewModel()
    @State private var selectedTab: AppTab = .posts

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
            .background(.ultraThinMaterial)
            .environment(\.locale, Locale(identifier: viewModel.selectedLanguage.localeIdentifier))
        }
        .buttonStyle(.plain)
    }
}
