import SwiftUI

struct VideoRowView: View {
    let video: LikedVideo

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            thumbnail

            VStack(alignment: .leading, spacing: 4) {
                Text(video.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)

                Text(video.likedAt, style: .date)
                    .font(.caption2)
                    .foregroundColor(.secondary)

                if !video.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(video.tags.prefix(4), id: \.self) { tag in
                                Text(tag)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color(.systemGray6))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var thumbnail: some View {
        AsyncImage(url: video.thumbnailURL.flatMap(URL.init)) { phase in
            switch phase {
            case .success(let image):
                image.resizable().aspectRatio(contentMode: .fill)
            case .empty:
                Rectangle().fill(Color(.systemGray5)).overlay(ProgressView())
            case .failure:
                Rectangle().fill(Color(.systemGray4))
                    .overlay(Image(systemName: "play.rectangle").foregroundColor(.secondary))
            @unknown default:
                EmptyView()
            }
        }
        .frame(width: 120, height: 68)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
