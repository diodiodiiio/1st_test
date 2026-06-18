import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        Group {
            if authViewModel.isSignedIn {
                HomeView(authViewModel: authViewModel)
            } else {
                LoginView()
            }
        }
        .animation(.easeInOut, value: authViewModel.isSignedIn)
    }
}
