import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var sub = SubscriptionManager.shared
    @State private var busy = false

    var body: some View {
        NavigationStack {
            ZStack {
                ProGradientBackground().ignoresSafeArea()

                VStack(spacing: 16) {
                    header

                    benefits

                    purchaseButton

                    HStack(spacing: 14) {
                        Button("Restore") {
                            Task { await sub.restore() }
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.white.opacity(0.65))

                        Text("•").foregroundStyle(.white.opacity(0.35))

                        Text("Cancel anytime in Settings → Subscriptions")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    .padding(.top, 6)

                    if let err = sub.lastError {
                        Text(err)
                            .font(.footnote)
                            .foregroundStyle(.red.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)
                    }

                    Spacer(minLength: 10)
                }
                .padding(24)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .task {
                // Ensure products & entitlements are available if this is the first time opening.
                await sub.loadProducts()
                await sub.refreshEntitlements()
            }
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                Text("Counsel Pro")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
            }

            Text("Keep it simple. Keep it moving.")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(.white.opacity(0.62))
        }
        .padding(.top, 6)
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 12) {
            benefitRow("Unlimited reflections & history")
            benefitRow("One-tap planning from any entry")
            benefitRow("Upcoming: voice capture + smarter advisor")
        }
        .padding(16)
        .background(.ultraThinMaterial.opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.top, 10)
    }

    private func benefitRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.white.opacity(0.75))
            Text(text)
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(.white.opacity(0.88))
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
    }

    private var purchaseButton: some View {
        Button {
            Task {
                busy = true
                await sub.purchaseMonthly()
                busy = false
                if sub.isPro { dismiss() }
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Go Pro (Monthly)")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.92))
                    Text(subtitlePrice)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.60))
                }
                Spacer()
                if busy {
                    ProgressView()
                        .tint(.white.opacity(0.85))
                } else {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.white.opacity(0.65))
                }
            }
            .padding(16)
            .background(.white.opacity(0.10))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(0.18), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .disabled(busy)
        .padding(.top, 8)
    }

    private var subtitlePrice: String {
        let price = sub.products.first(where: { $0.id == ProductIDs.proMonthly })?.displayPrice
        return (price != nil) ? "\(price!) / month" : "Loading price…"
    }
}

private struct ProGradientBackground: View {
    var body: some View {
        LinearGradient(
            stops: [
                .init(color: Color.black.opacity(0.98), location: 0.0),
                .init(color: Color.black.opacity(0.90), location: 0.55),
                .init(color: Color.black.opacity(0.98), location: 1.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
