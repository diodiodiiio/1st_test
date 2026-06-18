import SwiftUI
import SwiftData

struct SettingsView: View {
    @StateObject private var vm = SettingsViewModel()
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Genre.sortOrder) private var genres: [Genre]
    @State private var newGenreName = ""
    @State private var showAddGenre = false

    var body: some View {
        NavigationStack {
            Form {
                notificationSection
                genreSection
                dataSection
            }
            .navigationTitle("設定")
            .task { await vm.onAppear() }
            .alert("ジャンルを追加", isPresented: $showAddGenre) {
                TextField("ジャンル名", text: $newGenreName)
                Button("追加") { addGenre() }
                Button("キャンセル", role: .cancel) { newGenreName = "" }
            }
        }
    }

    // MARK: - Notification Section

    private var notificationSection: some View {
        Section {
            Toggle("週次リマインダー", isOn: Binding(
                get: { vm.notificationEnabled },
                set: { Task { await vm.toggleNotification(enabled: $0) } }
            ))

            if vm.notificationEnabled {
                Picker("通知曜日", selection: $vm.notificationWeekday) {
                    Text("日曜日").tag(1)
                    Text("月曜日").tag(2)
                    Text("土曜日").tag(7)
                }
                .onChange(of: vm.notificationWeekday) { vm.updateSchedule() }

                Picker("通知時刻", selection: $vm.notificationHour) {
                    ForEach([8, 12, 18, 20, 21, 22], id: \.self) { h in
                        Text("\(h):00").tag(h)
                    }
                }
                .onChange(of: vm.notificationHour) { vm.updateSchedule() }
            }
        } header: {
            Text("通知")
        } footer: {
            Text("未レビューの写真がある週に通知します。")
        }
    }

    // MARK: - Genre Section

    private var genreSection: some View {
        Section {
            ForEach(genres) { genre in
                HStack(spacing: 12) {
                    Image(systemName: genre.icon)
                        .foregroundStyle(Color(hex: genre.colorHex) ?? .blue)
                        .frame(width: 24)
                    Text(genre.name)
                }
            }
            .onDelete(perform: deleteGenres)
            .onMove(perform: moveGenres)

            Button {
                showAddGenre = true
            } label: {
                Label("ジャンルを追加", systemImage: "plus.circle.fill")
            }
        } header: {
            Text("ジャンル")
        } footer: {
            Text("スワイプで削除、長押しで並び替えができます。")
        }
    }

    // MARK: - Data Section

    private var dataSection: some View {
        Section("データ") {
            Button("レビュー履歴をすべて削除", role: .destructive) {
                clearAllRecords()
            }
        }
    }

    // MARK: - Actions

    private func addGenre() {
        let name = newGenreName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let icons = ["star.fill", "heart.fill", "flag.fill", "bookmark.fill", "mappin"]
        let colors = ["#FF9800", "#9C27B0", "#2196F3", "#009688", "#F44336"]
        let genre = Genre(
            name: name,
            colorHex: colors.randomElement() ?? "#9C27B0",
            icon: icons.randomElement() ?? "tag.fill",
            sortOrder: (genres.last?.sortOrder ?? 0) + 1
        )
        modelContext.insert(genre)
        try? modelContext.save()
        newGenreName = ""
    }

    private func deleteGenres(at offsets: IndexSet) {
        offsets.forEach { modelContext.delete(genres[$0]) }
        try? modelContext.save()
    }

    private func moveGenres(from source: IndexSet, to destination: Int) {
        var sorted = genres
        sorted.move(fromOffsets: source, toOffset: destination)
        for (i, genre) in sorted.enumerated() { genre.sortOrder = i }
        try? modelContext.save()
    }

    private func clearAllRecords() {
        try? modelContext.delete(model: ReviewRecord.self)
        try? modelContext.save()
    }
}
