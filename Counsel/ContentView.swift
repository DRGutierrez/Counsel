import SwiftUI

private struct AdvisorResponseModel: Hashable {
    let summary: String
    let organized: [String]
    let nextStepPrompt: String
    let memorySnippet: String? // when non-nil, show "I'll remember this"
}

private struct HistoryItem: Identifiable, Hashable {
    let id: UUID
    let createdAt: Date
    let title: String
    let model: AdvisorResponseModel
}

@MainActor
private final class AppStore: ObservableObject {
    @Published var history: [HistoryItem] = []

    func addHistory(input: String, model: AdvisorResponseModel) {
        let title = AppStore.makeTitle(from: input)
        let item = HistoryItem(
            id: UUID(),
            createdAt: Date(),
            title: title,
            model: model
        )
        history.insert(item, at: 0)
    }

    private static func makeTitle(from input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Untitled" }
        // A simple, nice-looking title: first sentence-ish, truncated
        let firstLine = trimmed.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? trimmed
        return truncate(firstLine, limit: 42)
    }

    private static func truncate(_ s: String, limit: Int) -> String {
        if s.count <= limit { return s }
        let idx = s.index(s.startIndex, offsetBy: limit)
        return String(s[..<idx]) + "…"
    }
}

// MARK: - App Routes
private enum Route: Hashable {
    case reflections
    case history
    case processing(AdvisorResponseModel)
    case response(AdvisorResponseModel)
}


// MARK: - Home State
private enum HomeMode {
    case listening
    case didntCatchThat
}

struct ContentView: View {
    @State private var path = NavigationPath()
    @StateObject private var store = AppStore()

    var body: some View {
        NavigationStack(path: $path) {
            HomeView(path: $path)
                .environmentObject(store)
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .reflections:
                        ReflectionsView(path: $path)
                            .environmentObject(store)
                    case .history:
                        HistoryView(path: $path)
                            .environmentObject(store)
                    case .processing(let model):
                        ProcessingView(path: $path, next: model)
                    case .response(let model):
                        AdvisorResponseView(path: $path, model: model)
                    }
                }
        }
        .preferredColorScheme(.dark)
    }
}


private struct ProcessingView: View {
    @Binding var path: NavigationPath
    let next: AdvisorResponseModel

    @State private var didNavigate = false

    var body: some View {
        ZStack {
            CounselGradientBackground().ignoresSafeArea()

            VStack(spacing: 18) {
                Spacer()

                // Quiet pulse dot (subtle, not a loud spinner)
                ProcessingPulse()

                Text("Working on it...")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(CounselColors.secondaryText)

                Spacer()
            }
            .padding(.horizontal, 24)
        }
        .navigationBarHidden(true)
        .onAppear {
            guard !didNavigate else { return }
            didNavigate = true

            // A short, intentional pause
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                // Replace processing route with response route
                if path.count > 0 { path.removeLast() }
                path.append(Route.response(next))
            }
        }
    }
}

private struct ProcessingPulse: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 18, height: 18)
                .scaleEffect(animate ? 2.8 : 1.0)
                .opacity(animate ? 0.0 : 1.0)

            Circle()
                .fill(Color.white.opacity(0.35))
                .frame(width: 10, height: 10)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.0).repeatForever(autoreverses: false)) {
                animate = true
            }
        }
    }
}

// MARK: - Home (Sacred)
private struct HomeView: View {
    @Binding var path: NavigationPath
    @EnvironmentObject private var store: AppStore


    @State private var mode: HomeMode = .listening
    @State private var showMenu = false
    @State private var showTypeSheet = false
    @State private var typedText = ""
    

    var body: some View {
        ZStack {
            CounselGradientBackground()
                .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                // Mic cluster
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .opacity(0.20)
                        .frame(width: 140, height: 140)

                    Image(systemName: "mic")
                        .font(.system(size: 56, weight: .regular))
                        .foregroundStyle(mode == .listening ? CounselColors.icon : CounselColors.iconDisabled)
                        .opacity(mode == .listening ? 1.0 : 0.7)
                }

                // Copy block
                VStack(spacing: 10) {
                    Text(primaryLine)
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(CounselColors.secondaryText)

                    if let secondary = secondaryLine {
                        Text(secondary)
                            .font(.system(size: 17, weight: .regular))
                            .foregroundStyle(CounselColors.tertiaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                }

                if mode == .didntCatchThat {
                    VStack(spacing: 14) {
                        Button("Try again") { mode = .listening }
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(CounselColors.primaryText)
                            .buttonStyle(.plain)

                        Button("Type instead") { showTypeSheet = true }
                            .font(.system(size: 18, weight: .regular))
                            .foregroundStyle(CounselColors.secondaryText)
                            .buttonStyle(.plain)
                            .padding(.top, 4)
                    }
                    .padding(.top, 10)
                } else {
                    Button { showTypeSheet = true } label: {
                        Image(systemName: "keyboard")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundStyle(CounselColors.tertiaryText)
                            .padding(.top, 6)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .padding(.horizontal, 24)

            // Top-right menu + TEMP debug toggle
            VStack {
                HStack {
                    Button {
                        mode = (mode == .listening) ? .didntCatchThat : .listening
                    } label: {
                        Text(mode == .listening ? "Test error" : "Back to listen")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(CounselColors.tertiaryText)
                            .padding(.leading, 16)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button { showMenu = true } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundStyle(CounselColors.tertiaryText)
                            .padding(16)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
        }
        .navigationBarHidden(true) // keep Home sacred
        .sheet(isPresented: $showMenu) {
            CounselMenuSheet(
                onGoReflections: {
                    showMenu = false
                    path.append(Route.reflections)
                },
                onGoHistory: {
                    showMenu = false
                    path.append(Route.history)
                }
            )
            .presentationDetents([.height(220)])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showTypeSheet) {
            CounselTypeSheet(text: $typedText) {
                showTypeSheet = false
                let input = typedText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !input.isEmpty else { return }

                let model = AdvisorStub.generateResponse(from: input)
                typedText = ""
                path.append(Route.processing(model))
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    private var primaryLine: String {
        mode == .listening ? "I'm listening." : "I didn't catch that."
    }

    private var secondaryLine: String? {
        mode == .listening ? nil : "You can try again, or type instead."
    }
}

private enum AdvisorStub {
    static func generateResponse(from input: String) -> AdvisorResponseModel {
        // Keep it factual & non-prescriptive
        let summary = "You’re thinking through: “\(truncate(input, limit: 90))”"

        // Very simple heuristic structure (good enough for a prototype)
        let organized: [String] = [
            "Key point: \(truncate(input, limit: 60))",
            "Constraint: unclear (worth clarifying)",
            "Next: decide what “done” looks like"
        ]

        // Memory example: only remember when the user states a preference like "I prefer..."
        let memorySnippet: String? = extractPreference(input)

        return AdvisorResponseModel(
            summary: summary,
            organized: organized,
            nextStepPrompt: "Would you like me to turn this into a simple plan?",
            memorySnippet: memorySnippet
        )
    }

    private static func truncate(_ s: String, limit: Int) -> String {
        if s.count <= limit { return s }
        let idx = s.index(s.startIndex, offsetBy: limit)
        return String(s[..<idx]) + "…"
    }

    private static func extractPreference(_ input: String) -> String? {
        // Ultra-simple: look for phrases that imply a lasting preference.
        // You’ll replace this with real logic later.
        let lowered = input.lowercased()
        if lowered.contains("i prefer ") || lowered.contains("i like ") {
            return truncate(input, limit: 80)
        }
        return nil
    }
}


// MARK: - Reflections
private struct ReflectionsView: View {
    @Binding var path: NavigationPath

    var body: some View {
        ZStack {
            CounselGradientBackground().ignoresSafeArea()

            VStack(spacing: 18) {
                ReviewHeader(active: .reflections, path: $path)

                // Placeholder content for now
                VStack(alignment: .leading, spacing: 14) {
                    Text("Check-ins")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(CounselColors.tertiaryText)

                    ReviewRow(title: "Morning routine improvements", subtitle: "Today · 9:24 AM")
                    ReviewRow(title: "Project timeline concerns", subtitle: "Today · 2:15 PM")
                    ReviewRow(title: "Weekly reflection", subtitle: "Yesterday · 11:20 AM")

                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 6)
            }
        }
        .navigationBarHidden(true)
    }
}

// MARK: - History
private struct HistoryView: View {
    @Binding var path: NavigationPath

    var body: some View {
        ZStack {
            CounselGradientBackground().ignoresSafeArea()

            VStack(spacing: 18) {
                ReviewHeader(active: .history, path: $path)

                VStack(alignment: .leading, spacing: 14) {
                    Text("Recent")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(CounselColors.tertiaryText)

                    ReviewRow(title: "Plan my week", subtitle: "Mon · 8:02 AM")
                    ReviewRow(title: "Summarize meeting notes", subtitle: "Sun · 6:14 PM")
                    ReviewRow(title: "Travel checklist", subtitle: "Sat · 10:40 AM")

                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 6)
            }
        }
        .navigationBarHidden(true)
    }
}

private struct AdvisorResponseView: View {
    @Binding var path: NavigationPath
    let model: AdvisorResponseModel

    @State private var showMemoryAck: Bool = true

    var body: some View {
        ZStack {
            CounselGradientBackground().ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {

                    // Top bar (safe + quiet)
                    HStack {
                        Button {
                            if path.count > 0 { path.removeLast() }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(CounselColors.tertiaryText)
                                .padding(.vertical, 8)
                                .padding(.trailing, 6)
                        }
                        .buttonStyle(.plain)

                        Spacer()
                    }
                    .padding(.top, 6)

                    // Summary
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Summary")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(CounselColors.tertiaryText)

                        Text(model.summary)
                            .font(.system(size: 26, weight: .regular))
                            .foregroundStyle(CounselColors.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Organized thoughts
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Organized thoughts")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(CounselColors.tertiaryText)

                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(model.organized, id: \.self) { item in
                                HStack(alignment: .top, spacing: 10) {
                                    Text("•")
                                        .foregroundStyle(CounselColors.tertiaryText)

                                    Text(item)
                                        .font(.system(size: 20, weight: .regular))
                                        .foregroundStyle(CounselColors.primaryText.opacity(0.92))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }

                    // Optional next step (make it feel like an action, not body copy)
                    Button {
                        // TODO: implement "turn into a plan"
                    } label: {
                        HStack(spacing: 10) {
                            Text(model.nextStepPrompt)
                                .font(.system(size: 18, weight: .regular))
                                .foregroundStyle(CounselColors.secondaryText)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(CounselColors.tertiaryText)
                        }
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)

                    // Memory acknowledgment (quiet)
                    if model.memorySnippet != nil, showMemoryAck {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("I’ll remember this.")
                                    .font(.system(size: 15, weight: .regular))
                                    .foregroundStyle(CounselColors.tertiaryText)

                                Spacer()

                                Button("Undo") {
                                    showMemoryAck = false
                                }
                                .font(.system(size: 15, weight: .regular))
                                .foregroundStyle(CounselColors.secondaryText)
                                .buttonStyle(.plain)
                            }

                            Text("You can review or remove memories anytime.")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(CounselColors.tertiaryText.opacity(0.85))
                        }
                        .padding(.top, 10)
                    }

                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 24)
                .padding(.top, 40) // <- this is the key for breathing room
                .padding(.bottom, 24)
            }
        }
        .navigationBarHidden(true)
    }
}


// MARK: - Review Header (text-only nav)
private enum ReviewTab {
    case home, reflections, history
}

private struct ReviewHeader: View {
    let active: ReviewTab
    @Binding var path: NavigationPath

    var body: some View {
        HStack(spacing: 22) {
            navItem("Home", isActive: active == .home) {
                // Pop to root (Home)
                if path.count > 0 {
                    path.removeLast()
                }
            }

            navItem("Reflections", isActive: active == .reflections) {
                if active != .reflections {
                    // Ensure we don't stack duplicates endlessly
                    if path.count > 0 { path.removeLast() }
                    path.append(Route.reflections)
                }
            }

            navItem("History", isActive: active == .history) {
                if active != .history {
                    if path.count > 0 { path.removeLast() }
                    path.append(Route.history)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 8)
    }

    private func navItem(_ title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(isActive ? CounselColors.primaryText : CounselColors.tertiaryText)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Reusable Row
private struct ReviewRow: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(CounselColors.primaryText)

            Text(subtitle)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(CounselColors.tertiaryText)

            Divider().opacity(0.12)
                .padding(.top, 10)
        }
    }
}

// MARK: - Menu Sheet
private struct CounselMenuSheet: View {
    let onGoReflections: () -> Void
    let onGoHistory: () -> Void

    var body: some View {
        ZStack {
            CounselGradientBackground().ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                Spacer(minLength: 10)

                Text("Reflections")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(CounselColors.primaryText)
                    .padding(.top, 8)
                    .onTapGesture { onGoReflections() }

                Divider().opacity(0.12)

                Text("History")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(CounselColors.primaryText)
                    .onTapGesture { onGoHistory() }

                Spacer()
            }
            .padding(.horizontal, 24)
        }
    }
}

// MARK: - Type Sheet
private struct CounselTypeSheet: View {
    @Binding var text: String
    let onSend: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                CounselGradientBackground().ignoresSafeArea()

                VStack(alignment: .leading, spacing: 14) {
                    Text("Type instead")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(CounselColors.tertiaryText)

                    TextEditor(text: $text)
                        .scrollContentBackground(.hidden)
                        .padding(12)
                        .background(.ultraThinMaterial.opacity(0.25))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .foregroundStyle(CounselColors.primaryText)
                        .frame(minHeight: 180)

                    Spacer()
                }
                .padding(20)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Send") { onSend() }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Design System
private enum CounselColors {
    static let primaryText = Color.white.opacity(0.92)
    static let secondaryText = Color.white.opacity(0.62)
    static let tertiaryText = Color.white.opacity(0.38)
    static let icon = Color.white.opacity(0.65)
    static let iconDisabled = Color.white.opacity(0.45)
}

private struct CounselGradientBackground: View {
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

#Preview {
    ContentView()
}
