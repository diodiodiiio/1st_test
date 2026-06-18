import SwiftUI

struct SettingsView: View {
    @Binding var settings: SlideshowSettings
    @Environment(\.dismiss) private var dismiss
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("再生") {
                    Picker("切り替え間隔", selection: $settings.intervalSeconds) {
                        ForEach(SlideshowSettings.intervalOptions, id: \.value) { opt in
                            Text(opt.label).tag(opt.value)
                        }
                    }
                    Picker("トランジション", selection: $settings.transitionStyle) {
                        ForEach(SlideshowSettings.TransitionStyle.allCases) { style in
                            Text(style.displayName).tag(style)
                        }
                    }
                    Toggle("シャッフル再生", isOn: $settings.shuffle)
                }
                Section("表示") {
                    Toggle("ファイル名を表示", isOn: $settings.showCaptions)
                    Toggle("画面を常時オン", isOn: $settings.keepScreenOn)
                }
                Section {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.blue)
                        Text("設定は次回起動時にも保持されます")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        onSave()
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }
}
