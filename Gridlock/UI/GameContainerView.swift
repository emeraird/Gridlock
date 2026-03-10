import SwiftUI
import SpriteKit

struct GameContainerView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var gameViewModel = GameViewModel()
    @State private var showPauseMenu = false
    @State private var returnToMenuRequested = false

    var body: some View {
        ZStack {
            // SpriteKit game scene
            SpriteView(scene: gameViewModel.scene, preferredFramesPerSecond: 60)
                .ignoresSafeArea()
                .onAppear {
                    gameViewModel.scene.size = UIScreen.main.bounds.size
                    gameViewModel.scene.scaleMode = .resizeFill
                }

            // SwiftUI overlays can be added here
        }
        .onReceive(NotificationCenter.default.publisher(for: .returnToMenu)) { _ in
            returnToMenuRequested = true
        }
        .statusBarHidden()
    }
}

// MARK: - Game View Model

final class GameViewModel: ObservableObject {
    let scene: GameScene

    init() {
        let scene = GameScene()
        scene.size = UIScreen.main.bounds.size
        scene.scaleMode = .resizeFill
        scene.backgroundColor = ThemeManager.shared.currentTheme.backgroundColor
        self.scene = scene
    }
}
