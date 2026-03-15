import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: BlogViewModel
    var dismissAfterSave: Bool = true

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section(LocalizedStringKey("settings.blog_section")) {
                TextField(LocalizedStringKey("settings.blog_placeholder"), text: $viewModel.baseURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
            }

            Section(LocalizedStringKey("settings.language_section")) {
                Picker(LocalizedStringKey("settings.language_label"), selection: $viewModel.selectedLanguage) {
                    Text(LocalizedStringKey("language.chinese")).tag(AppLanguage.chinese)
                    Text(LocalizedStringKey("language.english")).tag(AppLanguage.english)
                }
                .pickerStyle(.segmented)
            }

            Section {
                Button(LocalizedStringKey("settings.save_refresh")) {
                    viewModel.saveBaseURL()
                    Task {
                        await viewModel.loadPosts()
                        if dismissAfterSave {
                            dismiss()
                        }
                    }
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .liquidGlassCard(cornerRadius: 12)
            }
            .listRowBackground(Color.clear)
        }
        .scrollContentBackground(.hidden)
        .liquidGlassBackground()
        .navigationTitle(LocalizedStringKey("settings.title"))
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
