import SwiftUI

struct SlideshowView: View {
    @ObservedObject var viewModel: SlideshowViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showControls = true
    @State private var controlsTimer: Timer?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if viewModel.isLoading {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.5)
            } else if let image = viewModel.currentImage {
                imageView(image)
            } else if viewModel.images.isEmpty && !viewModel.isLoading {
                ContentUnavailableView(
                    "画像がありません",
                    systemImage: "photo.slash",
                    description: Text("選択したフォルダに画像ファイルがありません")
                )
                .colorScheme(.dark)
            }

            if showControls {
                controlsOverlay
            }
        }
        .statusBarHidden(true)
        .gesture(
            TapGesture()
                .onEnded { toggleControls() }
        )
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    if value.translation.width < 0 {
                        viewModel.advance(by: 1)
                    } else if value.translation.width > 0 {
                        viewModel.advance(by: -1)
                    }
                }
        )
        .onAppear { scheduleControlsHide() }
    }

    @ViewBuilder
    private func imageView(_ image: UIImage) -> some View {
        let style = viewModel.settings.transitionStyle
        switch style {
        case .crossfade:
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .transition(.opacity)
                .id(viewModel.currentIndex)
                .animation(.easeInOut(duration: 0.6), value: viewModel.currentIndex)
        case .slide:
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                .id(viewModel.currentIndex)
                .animation(.easeInOut(duration: 0.4), value: viewModel.currentIndex)
        case .none:
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .id(viewModel.currentIndex)
        }
    }

    private var controlsOverlay: some View {
        VStack {
            HStack {
                Button {
                    viewModel.stopSlideshow()
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .black.opacity(0.5))
                }
                Spacer()
                if viewModel.settings.showCaptions {
                    Text(viewModel.currentItemName)
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.5))
                        .clipShape(Capsule())
                }
                Text(viewModel.progress)
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.5))
                    .clipShape(Capsule())
            }
            .padding()

            Spacer()

            HStack(spacing: 48) {
                Button {
                    viewModel.advance(by: -1)
                    resetControlsTimer()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.title)
                        .foregroundStyle(.white)
                        .padding()
                        .background(.black.opacity(0.4))
                        .clipShape(Circle())
                }

                Button {
                    viewModel.togglePlayPause()
                    resetControlsTimer()
                } label: {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title)
                        .foregroundStyle(.white)
                        .padding()
                        .background(.black.opacity(0.4))
                        .clipShape(Circle())
                }

                Button {
                    viewModel.advance(by: 1)
                    resetControlsTimer()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.title)
                        .foregroundStyle(.white)
                        .padding()
                        .background(.black.opacity(0.4))
                        .clipShape(Circle())
                }
            }
            .padding(.bottom, 40)
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.3), value: showControls)
    }

    private func toggleControls() {
        withAnimation { showControls.toggle() }
        if showControls { scheduleControlsHide() }
    }

    private func scheduleControlsHide() {
        controlsTimer?.invalidate()
        controlsTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { _ in
            withAnimation { showControls = false }
        }
    }

    private func resetControlsTimer() {
        controlsTimer?.invalidate()
        scheduleControlsHide()
    }
}
