import SwiftUI

struct FolderBrowserView: View {
    @StateObject private var viewModel: FolderBrowserViewModel
    @Environment(\.dismiss) private var dismiss
    let onFolderSelected: (String, String) -> Void

    init(authViewModel: AuthViewModel, onFolderSelected: @escaping (String, String) -> Void) {
        _viewModel = StateObject(wrappedValue: FolderBrowserViewModel(authViewModel: authViewModel))
        self.onFolderSelected = onFolderSelected
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("読み込み中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.errorMessage {
                    ContentUnavailableView(
                        "読み込み失敗",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                } else if viewModel.items.isEmpty {
                    ContentUnavailableView(
                        "ファイルがありません",
                        systemImage: "folder",
                        description: Text("このフォルダは空です")
                    )
                } else {
                    List(viewModel.items) { item in
                        itemRow(item)
                    }
                }
            }
            .navigationTitle(viewModel.currentFolderName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
                if viewModel.canGoBack {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            Task { await viewModel.navigateBack() }
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        let id = viewModel.currentFolderID
                        let name = viewModel.currentFolderName
                        if let id {
                            onFolderSelected(id, name)
                        }
                    } label: {
                        Text("このフォルダを選択")
                            .bold()
                    }
                    .disabled(viewModel.currentFolderID == nil)
                }
            }
            .safeAreaInset(edge: .top) {
                if viewModel.navigationPath.count > 1 {
                    breadcrumb
                }
            }
        }
        .task { await viewModel.loadItems() }
    }

    @ViewBuilder
    private func itemRow(_ item: DriveItem) -> some View {
        if item.isFolder {
            Button {
                Task { await viewModel.navigateInto(item: item) }
            } label: {
                HStack {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(.blue)
                    Text(item.name)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
        } else if item.isImage {
            HStack {
                Image(systemName: "photo")
                    .foregroundStyle(.green)
                Text(item.name)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
    }

    private var breadcrumb: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(viewModel.navigationPath.indices, id: \.self) { i in
                    let segment = viewModel.navigationPath[i]
                    Button {
                        Task { await viewModel.navigateTo(index: i) }
                    } label: {
                        Text(segment.name)
                            .font(.caption)
                            .foregroundStyle(i == viewModel.navigationPath.count - 1 ? .primary : .blue)
                    }
                    if i < viewModel.navigationPath.count - 1 {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
        .background(.ultraThinMaterial)
    }
}
