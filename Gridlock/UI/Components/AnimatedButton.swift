import SwiftUI

struct AnimatedButton: View {
    let title: String
    let color: Color
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            HapticManager.shared.buttonTap()
            AudioManager.shared.play(.buttonTap)
            action()
        }) {
            Text(title)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(color)
                        .shadow(color: color.opacity(0.4), radius: isPressed ? 2 : 8, y: isPressed ? 1 : 4)
                )
                .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeInOut(duration: 0.1)) { isPressed = true }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { isPressed = false }
                }
        )
    }
}
