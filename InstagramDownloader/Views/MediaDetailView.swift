import SwiftUI

struct MediaDetailView: View {
    let media: InstagramMedia
    @ObservedObject var viewModel: MediaViewModel
    @Environment(\.dismiss) var dismiss

    var downloadService: MediaDownloadService { viewModel.downloadService }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    mediaPreview

                    VStack(alignment: .leading, spacing: 16) {
                        metaSection

                        if let caption = media.caption, !caption.isEmpty {
                            Text(caption)
                                .font(.body)
                        }

                        downloadButton
                    }
                    .padding()
                }
            }
            .navigationTitle("投稿の詳細")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    var mediaPreview: some View {
        AsyncImage(url: URL(string: media.thumbnailUrl ?? media.mediaUrl ?? "")) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            default:
                Rectangle()
                    .fill(Color(.systemGray5))
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(
                        Group {
                            if case .empty = phase {
                                ProgressView()
                            } else {
                                Image(systemName: "photo")
                                    .foregroundColor(.secondary)
                            }
                        }
                    )
            }
        }
        .frame(maxWidth: .infinity)
    }

    var metaSection: some View {
        HStack {
            Label(mediaTypeText, systemImage: mediaTypeIcon)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(8)

            Spacer()

            Text(formattedDate)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    var downloadButton: some View {
        Button {
            Task { await viewModel.downloadSingle(media) }
        } label: {
            HStack {
                if downloadService.isDownloading(media.id) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Text("ダウンロード中...")
                } else if downloadService.isCompleted(media.id) {
                    Label("ダウンロード済み", systemImage: "checkmark.circle.fill")
                } else if downloadService.hasFailed(media.id) {
                    Label("再試行", systemImage: "arrow.clockwise.circle.fill")
                } else {
                    Label("ダウンロード", systemImage: "arrow.down.circle.fill")
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(buttonColor)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(downloadService.isDownloading(media.id) || downloadService.isCompleted(media.id))
    }

    var buttonColor: Color {
        if downloadService.isCompleted(media.id) { return .green }
        if downloadService.hasFailed(media.id) { return .orange }
        if downloadService.isDownloading(media.id) { return .gray }
        return .blue
    }

    var mediaTypeText: String {
        switch media.mediaType {
        case .image: return "画像"
        case .video: return "動画"
        case .carouselAlbum: return "カルーセル"
        }
    }

    var mediaTypeIcon: String {
        switch media.mediaType {
        case .image: return "photo"
        case .video: return "play.circle"
        case .carouselAlbum: return "square.on.square"
        }
    }

    var formattedDate: String {
        let iso = ISO8601DateFormatter()
        if let date = iso.date(from: media.timestamp) {
            let fmt = DateFormatter()
            fmt.locale = Locale(identifier: "ja_JP")
            fmt.dateStyle = .medium
            fmt.timeStyle = .short
            return fmt.string(from: date)
        }
        return media.timestamp
    }
}
