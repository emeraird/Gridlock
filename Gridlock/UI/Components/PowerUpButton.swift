import SwiftUI

struct PowerUpButtonView: View {
    let type: PowerUpType
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: {
            guard count > 0 else { return }
            HapticManager.shared.buttonTap()
            AudioManager.shared.play(.buttonTap)
            action()
        }) {
            ZStack {
                // Background circle
                Circle()
                    .fill(count > 0 ?
                          Color.accentGame.opacity(0.2) :
                          Color.gray.opacity(0.1))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle()
                            .stroke(count > 0 ?
                                    Color.accentGame :
                                    Color.gray.opacity(0.3), lineWidth: 1.5)
                    )

                // Icon
                Image(systemName: type.iconName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(count > 0 ? Color.accentGame : Color.gray)

                // Count badge
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 16, height: 16)
                        .background(Color.accentGame)
                        .clipShape(Circle())
                        .offset(x: 14, y: -14)
                }

                // "+" for empty slots (ad to earn)
                if count == 0 {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color.gray.opacity(0.5))
                        .offset(x: 14, y: -14)
                }
            }
        }
        .disabled(count == 0)
    }
}
