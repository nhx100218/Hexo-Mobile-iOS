import SwiftUI

struct BlogListView: View {
    @ObservedObject var viewModel: BlogViewModel

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading feed…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = viewModel.errorMessage {
                    ContentUnavailableView(
                        "Unable to Load Posts",
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                } else if viewModel.posts.isEmpty {
                    ContentUnavailableView(
                        "No Posts",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text("Add a Hexo blog URL in Settings and tap Refresh.")
                    )
                } else {
                    List(viewModel.posts) { post in
                        NavigationLink(destination: ArticleView(url: post.link)) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(post.title)
                                    .font(.headline)
                                    .foregroundStyle(.primary)

                                if let publishDate = post.publishDate {
                                    Text(Self.dateFormatter.string(from: publishDate))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Text(post.summary)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(.ultraThinMaterial)
                    }
                    .scrollContentBackground(.hidden)
                    .background(Color(.systemBackground))
                }
            }
            .navigationTitle("HexoReader")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if let feedURL = viewModel.detectedFeedURL {
                        Label(feedURL.path, systemImage: "dot.radiowaves.left.and.right")
                            .font(.caption)
                            .labelStyle(.titleAndIcon)
                            .foregroundStyle(.secondary)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: SettingsView(viewModel: viewModel)) {
                        Image(systemName: "gearshape")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await viewModel.loadPosts() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .task {
                if !viewModel.baseURL.isEmpty, viewModel.posts.isEmpty {
                    await viewModel.loadPosts()
                }
            }
        }
        .tint(.accentColor)
    }
}

#Preview {
    BlogListView(viewModel: BlogViewModel())
}
