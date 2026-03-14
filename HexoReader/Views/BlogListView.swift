import SwiftUI

struct BlogListView: View {
    @ObservedObject var viewModel: BlogViewModel

    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        NavigationStack {
            contentView
            .navigationTitle("HexoReader")
            .toolbar { toolbarContent }
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

    @ViewBuilder
    private var contentView: some View {
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
            postList
        }
    }

    private var postList: some View {
        List(viewModel.posts) { post in
            BlogPostRow(post: post)
                .listRowBackground(Rectangle().fill(.ultraThinMaterial))
        }
        .scrollContentBackground(.hidden)
        .background(Color(.systemBackground))
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if let detectedFeedPath = viewModel.detectedFeedURL?.path {
            ToolbarItem(placement: .topBarLeading) {
                Label(detectedFeedPath, systemImage: "dot.radiowaves.left.and.right")
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
}

private struct BlogPostRow: View {
    let post: Post

    var body: some View {
        NavigationLink(destination: ArticleView(url: post.link)) {
            VStack(alignment: .leading, spacing: 8) {
                Text(post.title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                if let publishDate = post.publishDate {
                    Text(BlogListView.dateFormatter.string(from: publishDate))
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
    }
}

#Preview {
    BlogListView(viewModel: BlogViewModel())
}
