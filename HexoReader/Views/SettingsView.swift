import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: BlogViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("Blog") {
                TextField("https://blog.example.com", text: $viewModel.baseURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
            }

            Section {
                Button("Save & Refresh") {
                    viewModel.saveBaseURL()
                    Task {
                        await viewModel.loadPosts()
                        dismiss()
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .scrollContentBackground(.hidden)
        .background(.ultraThinMaterial)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}

#Preview {
    NavigationStack {
        SettingsView(viewModel: BlogViewModel())
    }
}
