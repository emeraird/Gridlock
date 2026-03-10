import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var audio = AudioManager.shared
    @State private var hapticsEnabled = HapticManager.shared.isEnabled
    @State private var showRestoreAlert = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // Audio section
                Section("Audio") {
                    Toggle("Sound Effects", isOn: $audio.sfxEnabled)
                    Toggle("Music", isOn: $audio.musicEnabled)
                }

                // Haptics section
                Section("Haptics") {
                    Toggle("Vibration Feedback", isOn: $hapticsEnabled)
                        .onChange(of: hapticsEnabled) { _, newValue in
                            HapticManager.shared.isEnabled = newValue
                        }
                }

                // Theme section
                Section("Appearance") {
                    HStack {
                        Text("Current Theme")
                        Spacer()
                        Text(themeManager.currentTheme.name)
                            .foregroundColor(.secondary)
                    }
                }

                // Purchases section
                Section("Purchases") {
                    Button("Restore Purchases") {
                        Task {
                            await IAPManager.shared.restorePurchases()
                            showRestoreAlert = true
                        }
                    }

                    if !UserProgressManager.shared.removeAdsActive {
                        NavigationLink("Remove Ads") {
                            RemoveAdsView()
                        }
                    } else {
                        HStack {
                            Text("Remove Ads")
                            Spacer()
                            Text("Active")
                                .foregroundColor(.green)
                        }
                    }
                }

                // About section
                Section("About") {
                    Button("Rate on App Store") {
                        // TODO: SKStoreReviewController
                    }

                    Button("Share Gridlock") {
                        // TODO: UIActivityViewController
                    }

                    Link("Privacy Policy", destination: URL(string: "https://example.com/privacy")!)

                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Purchases Restored", isPresented: $showRestoreAlert) {
                Button("OK") {}
            }
        }
    }
}

// MARK: - Remove Ads View

struct RemoveAdsView: View {
    @StateObject private var iapManager = IAPManager.shared

    var body: some View {
        List {
            Section {
                Text("Enjoy Gridlock without any ads! Subscribers also get a free power-up each game.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Section("Subscription Options") {
                ForEach(iapManager.subscriptionProducts(), id: \.id) { product in
                    Button {
                        Task {
                            try? await iapManager.purchase(product)
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(product.displayName)
                                    .font(.headline)
                                Text(product.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(product.displayPrice)
                                .font(.headline)
                                .foregroundColor(.accentGame)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("Remove Ads")
    }
}
