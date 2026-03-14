import SwiftUI

@main
struct HexoReaderApp: App {
    @StateObject private var viewModel = BlogViewModel()

    var body: some Scene {
        WindowGroup {
            BlogListView(viewModel: viewModel)
                .preferredColorScheme(nil)
        }
    }
}
