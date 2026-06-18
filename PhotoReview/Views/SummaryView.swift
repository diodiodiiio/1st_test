import SwiftUI
import SwiftData

struct SummaryView: View {
    @ObservedObject var vm: ReviewViewModel
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Genre.sortOrder) private var genres: [Genre]

    @State private var isDeleting = false
    @State private var deleteError: String? = nil
    @State private var deleteCompleted = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.green)
                    Text("レビュー完了")
                        .font(.title.bold())
                    Text(WeekHelper.weekLabel(for: vm.weekID))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 24)

                // Stats
                HStack(spacing: 16) {
                    StatCard(
                        value: "\(vm.keptCount)",
                        label: "残す",
                        icon: "heart.fill",
                        color: .green
                    )
                    StatCard(
                        value: "\(vm.pendingDeleteIDs.count)",
                        label: "削除予定",
                        icon: "trash",
                        color: .red
                    )
                }
                .padding(.horizontal)

                // Genre breakdown
                if !vm.genreCountMap.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("ジャンル別")
                            .font(.headline)
                            .padding(.horizontal)

                        ForEach(genres.filter { vm.genreCountMap[$0.id] != nil }) { genre in
                            let count = vm.genreCountMap[genre.id] ?? 0
                            HStack {
                                Image(systemName: genre.icon)
                                    .foregroundStyle(Color(hex: genre.colorHex) ?? .blue)
                                    .frame(width: 24)
                                Text(genre.name)
                                Spacer()
                                Text("\(count)枚")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical, 12)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
                }

                // Delete confirmation
                if !vm.pendingDeleteIDs.isEmpty && !deleteCompleted {
                    VStack(spacing: 12) {
                        if let err = deleteError {
                            Text(err)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                        }

                        Button {
                            Task { await performDelete() }
                        } label: {
                            HStack {
                                if isDeleting {
                                    ProgressView()
                                        .tint(.white)
                                        .padding(.trailing, 4)
                                }
                                Text("\(vm.pendingDeleteIDs.count)枚を削除する")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.red)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(isDeleting)
                    }
                    .padding(.horizontal)
                }

                if deleteCompleted {
                    Label("削除完了", systemImage: "trash.fill")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }

                Button("ホームへ戻る") {
                    dismiss()
                }
                .fontWeight(.medium)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color(.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarBackButtonHidden()
    }

    private func performDelete() async {
        isDeleting = true
        deleteError = nil
        do {
            try await vm.deleteMarkedAssets()
            deleteCompleted = true
        } catch {
            deleteError = "削除に失敗しました: \(error.localizedDescription)"
        }
        isDeleting = false
    }
}

struct StatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.title2)
            Text(value)
                .font(.title.bold())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
