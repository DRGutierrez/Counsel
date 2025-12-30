import SwiftUI
import Combine

/// Wrap any Pro-only view with ProGate { ... } to show an upsell instead for free users.
struct ProGate<ProContent: View>: View {
    @ObservedObject private var sub = SubscriptionManager.shared
    @State private var showPaywall = false

    let title: String
    let message: String
    let proContent: () -> ProContent

    init(
        title: String = "Pro Feature",
        message: String = "Unlock Counsel Pro to use this.",
        @ViewBuilder proContent: @escaping () -> ProContent
    ) {
        self.title = title
        self.message = message
        self.proContent = proContent
    }

    var body: some View {
        Group {
            if sub.isPro {
                proContent()
            } else {
                VStack(spacing: 12) {
                    Text(title)
                        .font(.title3.bold())
                        .foregroundStyle(.white.opacity(0.92))

                    Text(message)
                        .foregroundStyle(.white.opacity(0.60))
                        .multilineTextAlignment(.center)

                    Button("Unlock Pro") { showPaywall = true }
                        .buttonStyle(.borderedProminent)
                }
                .padding(22)
            }
        }
        .task { await sub.refreshEntitlements() }
        .sheet(isPresented: $showPaywall) { PaywallView() }
    }
}
