import SwiftUI

struct HomeView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = LikedVideosViewModel()

    @State private var shareURL: URL?
    @State private var isSharePresented = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                dateRangeSection
                Divider()

                if viewModel.isLoading {
                    loadingView
                } else if viewModel.videos.isEmpty {
                    emptyView
                } else {
                    tagFilterBar
                    videoList
                }
            }
            .navigationTitle("いいね動画")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            share(.csv)
                        } label: {
                            Label("CSVをエクスポート", systemImage: "tablecells")
                        }
                        Button {
                            share(.json)
                        } label: {
                            Label("JSONをエクスポート", systemImage: "curlybraces")
                        }
                        Divider()
                        Button(role: .destructive) {
                            authViewModel.logout()
                        } label: {
                            Label("サインアウト", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .sheet(isPresented: $isSharePresented) {
                if let shareURL = shareURL {
                    ShareSheet(items: [shareURL])
                }
            }
        }
    }

    // MARK: - Sections

    private var dateRangeSection: some View {
        VStack(spacing: 12) {
            DatePicker("開始日", selection: $viewModel.startDate, displayedComponents: .date)
            DatePicker("終了日", selection: $viewModel.endDate, displayedComponents: .date)

            Button {
                Task { await viewModel.fetch() }
            } label: {
                HStack {
                    Image(systemName: "arrow.down.circle.fill")
                    Text("抽出する")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(hex: "FF0000"))
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(viewModel.isLoading)

            if let message = viewModel.successMessage {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }

    private var tagFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                TagChip(label: "すべて (\(viewModel.videos.count))",
                        isSelected: viewModel.selectedTag == nil) {
                    viewModel.selectedTag = nil
                }
                ForEach(viewModel.allTags, id: \.self) { tag in
                    TagChip(label: tag, isSelected: viewModel.selectedTag == tag) {
                        viewModel.selectedTag = tag
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    private var videoList: some View {
        List(viewModel.filteredVideos) { video in
            NavigationLink(destination: VideoDetailView(video: video)) {
                VideoRowView(video: video)
            }
        }
        .listStyle(.plain)
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            Spacer()
            ProgressView()
            Text("抽出中... \(viewModel.fetchedCount) 件")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "hand.thumbsup")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("期間を指定して「抽出する」を押してください")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    // MARK: - Actions

    private func share(_ format: ExportService.Format) {
        if let url = viewModel.export(format: format) {
            shareURL = url
            isSharePresented = true
        }
    }
}

struct TagChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color(hex: "FF0000") : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}

/// Bridges `UIActivityViewController` (share sheet) into SwiftUI.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
