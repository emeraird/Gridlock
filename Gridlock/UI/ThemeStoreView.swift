import SwiftUI

struct ThemeStoreView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var iapManager = IAPManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(themeManager.availableThemes, id: \.id) { theme in
                        ThemeCard(
                            theme: theme,
                            isSelected: theme.id == themeManager.currentTheme.id,
                            isUnlocked: themeManager.isThemeUnlocked(theme),
                            price: priceForTheme(theme),
                            onSelect: {
                                if themeManager.isThemeUnlocked(theme) {
                                    themeManager.selectTheme(theme)
                                    HapticManager.shared.buttonTap()
                                }
                            },
                            onPurchase: {
                                Task {
                                    if let productID = theme.productID,
                                       let product = iapManager.product(for: productID) {
                                        _ = try? await iapManager.purchase(product)
                                    }
                                }
                            }
                        )
                    }
                }
                .padding()
            }
            .background(Color(uiColor: themeManager.currentTheme.backgroundColor))
            .navigationTitle("Themes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func priceForTheme(_ theme: GameTheme) -> String? {
        guard let productID = theme.productID,
              let product = iapManager.product(for: productID) else { return nil }
        return product.displayPrice
    }
}

// MARK: - Theme Card

struct ThemeCard: View {
    let theme: GameTheme
    let isSelected: Bool
    let isUnlocked: Bool
    let price: String?
    let onSelect: () -> Void
    let onPurchase: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            // Theme preview: mini grid
            HStack(spacing: 3) {
                ForEach(0..<5, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(uiColor: theme.blockColors[i]))
                        .frame(width: 40, height: 40)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(uiColor: theme.gridBackgroundColor))
            )

            // Theme name
            Text(theme.name)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)

            // Action button
            if isUnlocked {
                if isSelected {
                    Text("Selected")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.green)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.green.opacity(0.15))
                        .clipShape(Capsule())
                } else {
                    Button("Select") {
                        onSelect()
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color.accentGame)
                    .clipShape(Capsule())
                }
            } else {
                Button {
                    onPurchase()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12))
                        Text(price ?? "$0.99")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color.accentGame)
                    .clipShape(Capsule())
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? Color(uiColor: theme.uiAccentColor) : Color.clear, lineWidth: 2)
                )
        )
    }
}
