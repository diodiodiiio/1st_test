import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            WeekPickerView()
                .tabItem {
                    Label("レビュー", systemImage: "photo.stack")
                }

            SettingsView()
                .tabItem {
                    Label("設定", systemImage: "gear")
                }
        }
    }
}
