import SwiftUI
import SwiftData

struct WeekPickerView: View {
    @EnvironmentObject private var photoService: PhotoLibraryService
    @Environment(\.modelContext) private var modelContext
    @Query private var allRecords: [ReviewRecord]
    @State private var weekStats: [(weekID: String, label: String, unreviewed: Int, total: Int)] = []
    @State private var selectedWeek: String? = nil
    @State private var isLoading = false

    private var reviewedByWeek: [String: Set<String>] {
        Dictionary(grouping: allRecords, by: \.weekID)
            .mapValues { Set($0.map(\.assetLocalIdentifier)) }
    }

    var body: some View {
        NavigationStack {
            Group {
                switch photoService.authorizationStatus {
                case .notDetermined:
                    permissionRequestView
                case .denied, .restricted:
                    permissionDeniedView
                default:
                    weekListView
                }
            }
            .navigationTitle("写真レビュー")
            .navigationDestination(item: $selectedWeek) { weekID in
                SwipeReviewView(
                    weekID: weekID,
                    reviewedIDs: reviewedByWeek[weekID] ?? []
                )
            }
        }
        .task {
            let status = await photoService.requestAuthorization()
            if status == .authorized || status == .limited {
                await loadWeekStats()
            }
        }
        .onChange(of: allRecords.count) { _, _ in
            Task { await loadWeekStats() }
        }
    }

    // MARK: - Week List

    private var weekListView: some View {
        List {
            if isLoading {
                HStack { Spacer(); ProgressView(); Spacer() }
                    .listRowBackground(Color.clear)
            } else if weekStats.isEmpty {
                ContentUnavailableView(
                    "レビュー対象なし",
                    systemImage: "photo.badge.checkmark",
                    description: Text("最近8週間に撮影した未レビューの写真はありません")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(weekStats, id: \.weekID) { stat in
                    Button {
                        selectedWeek = stat.weekID
                    } label: {
                        WeekRowView(stat: stat)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .refreshable { await loadWeekStats() }
    }

    // MARK: - Permission Views

    private var permissionRequestView: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 64))
                .foregroundStyle(.blue)
            Text("写真へのアクセス許可が必要です")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text("カメラロールの写真を整理するために、アクセス許可が必要です。")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("アクセスを許可する") {
                Task { await photoService.requestAuthorization() }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
    }

    private var permissionDeniedView: some View {
        ContentUnavailableView(
            "写真へのアクセスが必要です",
            systemImage: "photo.slash",
            description: Text("設定アプリ > プライバシーとセキュリティ > 写真 から許可してください。")
        )
    }

    // MARK: - Data Loading

    private func loadWeekStats() async {
        isLoading = true
        let reviewed = reviewedByWeek
        let weekIDs = WeekHelper.recentWeekIDs(count: 8)

        var stats: [(weekID: String, label: String, unreviewed: Int, total: Int)] = []
        for wid in weekIDs {
            let rid = reviewed[wid] ?? []
            let unreviewed = photoService.unreviewedCount(for: wid, reviewedIDs: rid)
            let total = photoService.totalCount(for: wid)
            if total > 0 {
                stats.append((weekID: wid, label: WeekHelper.weekLabel(for: wid), unreviewed: unreviewed, total: total))
            }
        }
        weekStats = stats
        isLoading = false
    }
}

struct WeekRowView: View {
    let stat: (weekID: String, label: String, unreviewed: Int, total: Int)

    var reviewedCount: Int { stat.total - stat.unreviewed }
    var progress: Double { stat.total > 0 ? Double(reviewedCount) / Double(stat.total) : 0 }
    var isCompleted: Bool { stat.unreviewed == 0 }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isCompleted ? .green : .secondary)
                .font(.title2)

            VStack(alignment: .leading, spacing: 4) {
                Text(stat.label)
                    .font(.headline)
                HStack(spacing: 6) {
                    if stat.unreviewed > 0 {
                        Text("未レビュー \(stat.unreviewed)枚")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    } else {
                        Text("完了")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                    Text("/ 計\(stat.total)枚")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                ProgressView(value: progress)
                    .tint(isCompleted ? .green : .blue)
            }

            Spacer()

            if stat.unreviewed > 0 {
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
                    .font(.caption)
            }
        }
        .contentShape(Rectangle())
        .padding(.vertical, 4)
        .opacity(stat.unreviewed == 0 ? 0.6 : 1.0)
    }
}
