import SwiftUI

struct DailyChallengeView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @State private var timeUntilNext: String = ""
    @State private var hasCompletedToday = false
    @State private var todayStars = 0
    @State private var showGame = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                // Calendar icon
                Image(systemName: "calendar.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(Color(uiColor: themeManager.currentTheme.uiAccentColor))

                Text("Daily Challenge")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)

                Text(dateString())
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))

                if hasCompletedToday {
                    // Show results
                    HStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { i in
                            Image(systemName: i < todayStars ? "star.fill" : "star")
                                .font(.system(size: 28))
                                .foregroundColor(.yellow)
                        }
                    }
                    .padding(.top, 8)

                    Text("Completed!")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.green)
                } else {
                    // Play button
                    AnimatedButton(title: "PLAY", color: Color(uiColor: themeManager.currentTheme.buttonColor)) {
                        showGame = true
                    }
                    .frame(width: 200, height: 50)
                }

                Spacer()

                // Countdown to next challenge
                VStack(spacing: 4) {
                    Text("Next challenge in")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.4))
                    Text(timeUntilNext)
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.bottom, 40)
            }
            .frame(maxWidth: .infinity)
            .background(Color(uiColor: themeManager.currentTheme.backgroundColor))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.white)
                }
            }
            .onReceive(timer) { _ in
                updateCountdown()
            }
            .onAppear {
                updateCountdown()
                checkTodayCompletion()
            }
            .fullScreenCover(isPresented: $showGame) {
                // TODO: Launch daily challenge game mode
                GameContainerView()
                    .environmentObject(themeManager)
            }
        }
    }

    private func dateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: Date())
    }

    private func updateCountdown() {
        let calendar = Calendar.current
        let now = Date()
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) else { return }
        let remaining = calendar.dateComponents([.hour, .minute, .second], from: now, to: tomorrow)

        let h = remaining.hour ?? 0
        let m = remaining.minute ?? 0
        let s = remaining.second ?? 0
        timeUntilNext = String(format: "%02d:%02d:%02d", h, m, s)
    }

    private func checkTodayCompletion() {
        let key = "dailyChallenge_\(dailySeed())"
        hasCompletedToday = UserDefaults.standard.bool(forKey: key)
        todayStars = UserDefaults.standard.integer(forKey: "\(key)_stars")
    }

    /// Generate a consistent seed for today's date
    static func dailySeed() -> UInt64 {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: Date())
        let dateValue = (components.year ?? 2024) * 10000 + (components.month ?? 1) * 100 + (components.day ?? 1)
        return UInt64(dateValue)
    }

    private func dailySeed() -> UInt64 {
        Self.dailySeed()
    }
}
