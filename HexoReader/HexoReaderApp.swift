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
            ZStack {
                Group {
                    switch selectedTab {
                    case .posts:
                        BlogListView(viewModel: viewModel)
                    case .about:
                        AboutView(viewModel: viewModel)
                    }
                }
                .background(.ultraThinMaterial)

                VStack {
                    Spacer()
                    floatingTabBar
                }
                .padding(.bottom, 10)
            }
            .environment(\.locale, Locale(identifier: viewModel.selectedLanguage.localeIdentifier))
        }
    }

    private var floatingTabBar: some View {
        HStack(spacing: 14) {
            tabButton(titleKey: "tab.posts", icon: "newspaper", tab: .posts)
            tabButton(titleKey: "tab.about", icon: "info.circle", tab: .about)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.25), lineWidth: 0.6)
        )
        .shadow(color: .black.opacity(0.12), radius: 20, y: 8)
    }

    private func tabButton(titleKey: String, icon: String, tab: AppTab) -> some View {
        let isSelected = selectedTab == tab

        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                selectedTab = tab
            }
        } label: {
            Label(LocalizedStringKey(titleKey), systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? .primary : .secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? AnyShapeStyle(.regularMaterial) : AnyShapeStyle(.clear), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
