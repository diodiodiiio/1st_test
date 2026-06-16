import SwiftUI

struct MediaGridView: View {
    @ObservedObject var viewModel: MediaViewModel

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)

    var body: some View {
        ScrollView {
            if viewModel.isLoading {
                loadingView
            } else if viewModel.mediaItems.isEmpty {
                emptyView
            } else {
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(viewModel.mediaItems) { media in
                        MediaGridCell(media: media, viewModel: viewModel)
                    }
                }
            }
        }
    }

    var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            if viewModel.fetchedCount > 0 {
                Text("\(viewModel.fetchedCount) 件取得中...")
                    .foregroundColor(.secondary)
            } else {
                Text("投稿を取得中...")
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 120)
    }

    var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("投稿がありません")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 120)
    }
}

struct MediaGridCell: View {
    let media: InstagramMedia
    @ObservedObject var viewModel: MediaViewModel
    @State private var showDetail = false

    var downloadService: MediaDownloadService { viewModel.downloadService }

    var body: some View {
        let url = URL(string: media.thumbnailUrl ?? media.mediaUrl ?? "")

        AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                Rectangle()
                    .fill(Color(.systemGray5))
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(ProgressView())
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(1, contentMode: .fill)
                    .clipped()
            case .failure:
                Rectangle()
                    .fill(Color(.systemGray4))
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.secondary)
                    )
            @unknown default:
                EmptyView()
            }
        }
        .overlay(alignment: .topTrailing) {
            statusBadge
        }
        .overlay(alignment: .bottomLeading) {
            mediaTypeBadge
        }
        .onTapGesture { showDetail = true }
        .sheet(isPresented: $showDetail) {
            MediaDetailView(media: media, viewModel: viewModel)
        }
    }

    @ViewBuilder
    var statusBadge: some View {
        if downloadService.isDownloading(media.id) {
            ProgressView()
                .scaleEffect(0.7)
                .padding(4)
                .background(Color.black.opacity(0.5))
                .cornerRadius(4)
                .padding(4)
        } else if downloadService.isCompleted(media.id) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .padding(4)
        } else if downloadService.hasFailed(media.id) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.red)
                .padding(4)
        }
    }

    @ViewBuilder
    var mediaTypeBadge: some View {
        switch media.mediaType {
        case .video:
            Image(systemName: "play.fill")
                .font(.caption)
                .foregroundColor(.white)
                .shadow(radius: 2)
                .padding(6)
        case .carouselAlbum:
            Image(systemName: "square.on.square.fill")
                .font(.caption)
                .foregroundColor(.white)
                .shadow(radius: 2)
                .padding(6)
        case .image:
            EmptyView()
        }
    }
}
