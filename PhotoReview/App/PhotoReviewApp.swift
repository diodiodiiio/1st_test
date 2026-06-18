import SwiftUI
import SwiftData

@main
struct PhotoReviewApp: App {
    @StateObject private var photoService = PhotoLibraryService()
    private let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: ReviewRecord.self, Genre.self)
        } catch {
            fatalError("SwiftData ModelContainer の初期化に失敗しました: \(error)")
        }
        seedDefaultGenresIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(photoService)
                .modelContainer(container)
        }
    }

    private func seedDefaultGenresIfNeeded() {
        let ctx = container.mainContext
        let count = (try? ctx.fetchCount(FetchDescriptor<Genre>())) ?? 0
        guard count == 0 else { return }
        Genre.defaults.forEach { ctx.insert($0) }
        try? ctx.save()
    }
}
