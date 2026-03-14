import Foundation

struct Post: Identifiable, Hashable {
    let id: UUID
    let title: String
    let publishDate: Date?
    let summary: String
    let link: URL

    init(id: UUID = UUID(), title: String, publishDate: Date?, summary: String, link: URL) {
        self.id = id
        self.title = title
        self.publishDate = publishDate
        self.summary = summary
        self.link = link
    }
}
