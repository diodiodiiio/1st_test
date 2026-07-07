import SwiftUI

struct VideoDetailView: View {
    let video: LikedVideo

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                AsyncImage(url: video.thumbnailURL.flatMap(URL.init)) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fit)
                    case .empty:
                        Rectangle().fill(Color(.systemGray5))
                            .aspectRatio(16.0 / 9.0, contentMode: .fit)
                            .overlay(ProgressView())
                    case .failure:
                        Rectangle().fill(Color(.systemGray4))
                            .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    @unknown default:
                        EmptyView()
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Text(video.title)
                    .font(.title3)
                    .fontWeight(.bold)

                HStack(spacing: 8) {
                    Image(systemName: "hand.thumbsup.fill")
                        .foregroundColor(.secondary)
                    Text(video.likedAt, style: .date)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                if !video.tags.isEmpty {
                    tagsSection
                }

                Link(destination: URL(string: video.url) ?? URL(string: "https://youtube.com")!) {
                    HStack {
                        Image(systemName: "play.rectangle.fill")
                        Text("YouTubeで開く")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(hex: "FF0000"))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }

                if !video.description.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("内容")
                            .font(.headline)
                        Text(video.description)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("詳細")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("タグ")
                .font(.headline)
            FlexibleTagsView(tags: video.tags)
        }
    }
}

/// Simple wrapping layout for tag capsules.
struct FlexibleTagsView: View {
    let tags: [String]

    var body: some View {
        var width: CGFloat = 0
        var height: CGFloat = 0

        return GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                ForEach(tags, id: \.self) { tag in
                    tagView(tag)
                        .alignmentGuide(.leading) { dimension in
                            if abs(width - dimension.width) > geometry.size.width {
                                width = 0
                                height -= dimension.height
                            }
                            let result = width
                            if tag == tags.last {
                                width = 0
                            } else {
                                width -= dimension.width
                            }
                            return result
                        }
                        .alignmentGuide(.top) { _ in
                            let result = height
                            if tag == tags.last {
                                height = 0
                            }
                            return result
                        }
                }
            }
        }
        .frame(height: 120)
    }

    private func tagView(_ tag: String) -> some View {
        Text(tag)
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(.systemGray6))
            .clipShape(Capsule())
            .padding(.trailing, 4)
            .padding(.bottom, 4)
    }
}
