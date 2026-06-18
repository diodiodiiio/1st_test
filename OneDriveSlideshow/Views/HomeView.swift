import SwiftUI

struct HomeView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var slideshowVM: SlideshowViewModel
    @State private var showFolderBrowser = false
    @State private var showSlideshow = false
    @State private var showSettings = false

    init(authViewModel: AuthViewModel) {
        _slideshowVM = StateObject(wrappedValue: SlideshowViewModel(authViewModel: authViewModel))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                folderSection
                Divider()
                if let error = slideshowVM.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                }
                actionButtons
                Spacer()
            }
            .padding()
            .navigationTitle("OneDrive Slideshow")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("サインアウト") { authViewModel.signOut() }
                        .foregroundStyle(.red)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showFolderBrowser) {
                FolderBrowserView(
                    authViewModel: authViewModel,
                    onFolderSelected: { id, name in
                        slideshowVM.settings.selectedFolderID = id
                        slideshowVM.settings.selectedFolderName = name
                        slideshowVM.saveSettings()
                        showFolderBrowser = false
                    }
                )
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(settings: $slideshowVM.settings, onSave: { slideshowVM.saveSettings() })
            }
            .fullScreenCover(isPresented: $showSlideshow, onDismiss: {
                slideshowVM.stopSlideshow()
            }) {
                SlideshowView(viewModel: slideshowVM)
            }
        }
    }

    private var folderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("スライドショーフォルダ")
                .font(.headline)
            Button {
                showFolderBrowser = true
            } label: {
                HStack {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(.blue)
                    Text(slideshowVM.settings.selectedFolderName ?? "フォルダを選択してください")
                        .foregroundStyle(slideshowVM.settings.selectedFolderName != nil ? .primary : .secondary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private var actionButtons: some View {
        Button {
            showSlideshow = true
            Task {
                await slideshowVM.loadImages(folderID: slideshowVM.settings.selectedFolderID)
                slideshowVM.startSlideshow()
            }
        } label: {
            Label("スライドショー開始", systemImage: "play.fill")
                .frame(maxWidth: .infinity)
                .padding()
                .background(slideshowVM.settings.selectedFolderID != nil ? Color.blue : Color.gray)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(slideshowVM.settings.selectedFolderID == nil)
    }
}
