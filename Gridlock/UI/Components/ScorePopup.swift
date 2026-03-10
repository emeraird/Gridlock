import SwiftUI

struct ScorePopup: View {
    let score: Int
    let position: CGPoint
    @State private var offset: CGFloat = 0
    @State private var opacity: Double = 1.0

    var body: some View {
        Text("+\(score)")
            .font(.system(size: 20, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
            .position(x: position.x, y: position.y + offset)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 0.8)) {
                    offset = -60
                }
                withAnimation(.easeIn(duration: 0.8).delay(0.3)) {
                    opacity = 0
                }
            }
    }
}
