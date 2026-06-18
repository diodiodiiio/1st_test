import SwiftUI
import Photos
import PhotosUI
import AVKit

struct ReviewCardView: View {
    let item: MediaItem
    let isTop: Bool

    @State private var image: UIImage? = nil
    @State private var isLoadingImage = true
    @State private var showVideoPlayer = false
    @State private var playerItem: AVPlayerItem? = nil

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 4)

            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 20))
            } else if isLoadingImage {
                ProgressView()
            }

            // Media type badge
            VStack {
                HStack {
                    Spacer()
                    mediaBadge
                        .padding(12)
                }
                Spacer()

                // Bottom metadata
                if let date = item.creationDate {
                    HStack {
                        Text(date, style: .date)
                            .font(.caption)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(.black.opacity(0.5))
                            .clipShape(Capsule())
                        Spacer()
                    }
                    .padding(12)
                }
            }

            // Video play button overlay
            if item.isVideo && !showVideoPlayer {
                Button {
                    showVideoPlayer = true
                } label: {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.white.opacity(0.9))
                        .shadow(radius: 4)
                }
            }
        }
        .task {
            guard isTop else { return }
            await loadMedia()
        }
        .onChange(of: isTop) { _, newValue in
            if newValue && image == nil {
                Task { await loadMedia() }
            }
        }
        .sheet(isPresented: $showVideoPlayer) {
            if let pi = playerItem {
                VideoPlayer(player: AVPlayer(playerItem: pi))
                    .ignoresSafeArea()
            }
        }
    }

    @ViewBuilder
    private var mediaBadge: some View {
        if item.isVideo {
            Label(formatDuration(item.duration), systemImage: "video.fill")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.black.opacity(0.6))
                .clipShape(Capsule())
        } else if item.isLivePhoto {
            Label("Live", systemImage: "livephoto")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.black.opacity(0.6))
                .clipShape(Capsule())
        }
    }

    private func loadMedia() async {
        let size = CGSize(width: UIScreen.main.bounds.width * 2,
                          height: UIScreen.main.bounds.height * 2)
        let img = await PhotoLibraryService().loadImage(for: item.asset, targetSize: size)
        image = img
        isLoadingImage = false

        if item.isVideo {
            let options = PHVideoRequestOptions()
            options.isNetworkAccessAllowed = true
            PHImageManager.default().requestAVAsset(forVideo: item.asset, options: options) { avAsset, _, _ in
                if let avAsset = avAsset {
                    DispatchQueue.main.async {
                        playerItem = AVPlayerItem(asset: avAsset)
                    }
                }
            }
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
