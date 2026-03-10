import SwiftUI

@main
struct GridlockApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var audioManager = AudioManager.shared

    var body: some Scene {
        WindowGroup {
            MainMenuView()
                .environmentObject(themeManager)
                .environmentObject(audioManager)
                .preferredColorScheme(.dark)
                .onAppear {
                    lockOrientation()
                    audioManager.preloadAll()
                }
        }
    }

    private func lockOrientation() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
    }
}
