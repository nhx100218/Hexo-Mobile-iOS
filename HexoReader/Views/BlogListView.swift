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
                .navigationTitle(LocalizedStringKey("app.title"))
                .toolbar { toolbarContent }
                .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .background(.ultraThinMaterial)
                .glassEffect()
                .task {
                    if !viewModel.baseURL.isEmpty, viewModel.posts.isEmpty {
                        await viewModel.loadPosts()
                    }
                }
        }
        .tint(.accentColor)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private var contentView: some View {
        if viewModel.isLoading {
            ProgressView(LocalizedStringKey("common.loading_feed"))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage = viewModel.errorMessage {
            ContentUnavailableView(
                LocalizedStringKey("list.unable_to_load"),
                systemImage: "exclamationmark.triangle",
                description: Text(errorMessage)
            )
        } else if viewModel.posts.isEmpty {
            ContentUnavailableView(
                LocalizedStringKey("list.no_posts"),
                systemImage: "doc.text.magnifyingglass",
                description: Text(LocalizedStringKey("list.no_posts_desc"))
            )
        } else {
            postList
        }
    }

    private var postList: some View {
        List(viewModel.posts) { post in
            BlogPostRow(post: post)
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .glassEffect()
                        .padding(.vertical, 2)
                )
                .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(.ultraThinMaterial)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                Task { await viewModel.loadPosts() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .padding(8)
                    .background(.ultraThinMaterial, in: Circle())
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            NavigationLink(destination: SettingsView(viewModel: viewModel)) {
                Image(systemName: "gearshape")
                    .padding(8)
                    .background(.ultraThinMaterial, in: Circle())
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
            .padding(.vertical, 6)
        }
    }
}

#Preview {
    BlogListView(viewModel: BlogViewModel())
}
