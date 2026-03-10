import SwiftUI

struct StreakBanner: View {
    let streakCount: Int
    let reward: StreakReward?
    @Binding var isShowing: Bool

    var body: some View {
        if isShowing {
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.orange)

                    Text("\(streakCount) Day Streak!")
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                }

                if let reward = reward {
                    Text(reward.description)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [Color.orange, Color.red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .orange.opacity(0.3), radius: 10, y: 5)
            )
            .transition(.move(edge: .top).combined(with: .opacity))
            .onTapGesture {
                withAnimation { isShowing = false }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation { isShowing = false }
                }
            }
        }
    }
}
