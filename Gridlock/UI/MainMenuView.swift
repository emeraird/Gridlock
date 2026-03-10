import SwiftUI

struct MainMenuView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var streakManager = StreakManager.shared
    @StateObject private var progress = UserProgressManager.shared
    @State private var showGame = false
    @State private var showDailyChallenge = false
    @State private var showStats = false
    @State private var showSettings = false
    @State private var showThemeStore = false
    @State private var showLeaderboard = false
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0

    private var theme: GameTheme { themeManager.currentTheme }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(uiColor: theme.backgroundColor)
                    .ignoresSafeArea()

                // Animated background particles
                ParticleBackgroundView(theme: theme)

                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: 80)

                    // Logo
                    Text("GRIDLOCK")
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .foregroundColor(Color(uiColor: theme.uiAccentColor))
                        .shadow(color: Color(uiColor: theme.uiAccentColor).opacity(0.5), radius: 10)
                        .scaleEffect(logoScale)
                        .opacity(logoOpacity)
                        .onAppear {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                                logoScale = 1.0
                                logoOpacity = 1.0
                            }
                        }

                    // High score
                    Text("High Score: \(progress.highScore)")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(uiColor: theme.scoreTextColor).opacity(0.6))
                        .padding(.top, 8)

                    // Streak display
                    if streakManager.currentStreak > 0 {
                        HStack(spacing: 6) {
                            Image(systemName: "flame.fill")
                                .foregroundColor(.orange)
                            Text("\(streakManager.currentStreak) day streak")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.orange)
                        }
                        .padding(.top, 12)
                        .onTapGesture {
                            HapticManager.shared.buttonTap()
                        }
                    }

                    Spacer()

                    // Play button
                    AnimatedButton(title: "PLAY", color: Color(uiColor: theme.buttonColor)) {
                        showGame = true
                    }
                    .frame(width: 220, height: 56)
                    .padding(.bottom, 16)

                    // Secondary buttons
                    HStack(spacing: 16) {
                        SecondaryButton(title: "Daily", icon: "calendar", badge: !streakManager.playedToday ? "!" : nil) {
                            showDailyChallenge = true
                        }

                        SecondaryButton(title: "Stats", icon: "chart.bar.fill") {
                            showStats = true
                        }
                    }
                    .padding(.bottom, 24)

                    Spacer()

                    // Bottom bar
                    HStack(spacing: 40) {
                        BottomBarButton(icon: "gearshape.fill") { showSettings = true }
                        BottomBarButton(icon: "paintpalette.fill") { showThemeStore = true }
                        BottomBarButton(icon: "trophy.fill") { showLeaderboard = true }
                    }
                    .padding(.bottom, 40)
                }
            }
            .fullScreenCover(isPresented: $showGame) {
                GameContainerView()
                    .environmentObject(themeManager)
            }
            .sheet(isPresented: $showDailyChallenge) {
                DailyChallengeView()
                    .environmentObject(themeManager)
            }
            .sheet(isPresented: $showStats) {
                StatsView()
                    .environmentObject(themeManager)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(themeManager)
            }
            .sheet(isPresented: $showThemeStore) {
                ThemeStoreView()
                    .environmentObject(themeManager)
            }
            .sheet(isPresented: $showLeaderboard) {
                LeaderboardView()
            }
        }
    }
}

// MARK: - Secondary Button

struct SecondaryButton: View {
    let title: String
    let icon: String
    var badge: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticManager.shared.buttonTap()
            AudioManager.shared.play(.buttonTap)
            action()
        }) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(.white.opacity(0.9))
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.1))
            .clipShape(Capsule())
            .overlay(
                Group {
                    if let badge = badge {
                        Text(badge)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 18, height: 18)
                            .background(Color.red)
                            .clipShape(Circle())
                            .offset(x: 10, y: -10)
                    }
                },
                alignment: .topTrailing
            )
        }
    }
}

// MARK: - Bottom Bar Button

struct BottomBarButton: View {
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticManager.shared.buttonTap()
            AudioManager.shared.play(.buttonTap)
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 44, height: 44)
        }
    }
}

// MARK: - Particle Background

struct ParticleBackgroundView: View {
    let theme: GameTheme
    @State private var particles: [(CGPoint, CGFloat, Double)] = []

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                for (position, radius, opacity) in particles {
                    context.fill(
                        Path(ellipseIn: CGRect(x: position.x - radius, y: position.y - radius,
                                               width: radius * 2, height: radius * 2)),
                        with: .color(Color(uiColor: theme.particleColor).opacity(opacity))
                    )
                }
            }
            .onAppear {
                generateParticles(in: geometry.size)
            }
        }
    }

    private func generateParticles(in size: CGSize) {
        particles = (0..<20).map { _ in
            (
                CGPoint(x: CGFloat.random(in: 0...size.width),
                        y: CGFloat.random(in: 0...size.height)),
                CGFloat.random(in: 1...3),
                Double.random(in: 0.05...0.15)
            )
        }
    }
}
