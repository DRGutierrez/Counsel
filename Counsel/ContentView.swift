import SwiftUI
import Combine

// MARK: - Models

struct AdvisorResponseModel: Hashable {
    let summary: String
    let organized: [String]
    let nextStepPrompt: String
    let memorySnippet: String?
}

struct HistoryItem: Identifiable, Hashable {
    let id: UUID
    let createdAt: Date
    let title: String
    let model: AdvisorResponseModel
}

struct ReflectionItem: Identifiable, Hashable {
    let id: UUID
    let createdAt: Date
    let title: String
    let insight: String
    let supportingHistoryIDs: [UUID]
}

// MARK: - Store

@MainActor
final class AppStore: ObservableObject {
    @Published var history: [HistoryItem] = []
    @Published var reflections: [ReflectionItem] = []

    /// The single entry point for anything the user submits (typed today, voice tomorrow).
    func recordInteraction(input: String, model: AdvisorResponseModel) {
        addHistory(input: input, model: model)
        maybeGenerateReflection()
    }

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

    private func maybeGenerateReflection() {
        // Need enough signal to avoid junk reflections.
        guard history.count >= 3 else { return }

        let cadence: ReflectionCadence = (reflections.count < 7) ? .daily : .weekly
        guard shouldCreateReflection(cadence: cadence) else { return }

        let recent = Array(history.prefix(8))
        let reflection = ReflectionEngine.generate(from: recent)
        reflections.insert(reflection, at: 0)
    }

    private enum ReflectionCadence { case daily, weekly }

    private func shouldCreateReflection(cadence: ReflectionCadence) -> Bool {
        guard let last = reflections.first?.createdAt else { return true }
        let cal = Calendar.current

        switch cadence {
        case .daily:
            return !cal.isDate(last, inSameDayAs: Date())
        case .weekly:
            let lastWeek = cal.component(.weekOfYear, from: last)
            let nowWeek = cal.component(.weekOfYear, from: Date())
            let lastYear = cal.component(.yearForWeekOfYear, from: last)
            let nowYear = cal.component(.yearForWeekOfYear, from: Date())
            return (lastWeek != nowWeek) || (lastYear != nowYear)
        }
    }

    private static func makeTitle(from input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Untitled" }
        let firstLine = trimmed.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? trimmed
        return truncate(firstLine, limit: 42)
    }

    private static func truncate(_ s: String, limit: Int) -> String {
        if s.count <= limit { return s }
        let idx = s.index(s.startIndex, offsetBy: limit)
        return String(s[..<idx]) + "…"
    }
}

// MARK: - Reflection Engine (v1 heuristics)

enum ReflectionEngine {
    static func generate(from recent: [HistoryItem]) -> ReflectionItem {
        let combined = recent
            .map { "\($0.title) \($0.model.summary)" }
            .joined(separator: " ")
            .lowercased()

        let themes = topThemes(from: combined).prefix(3)
        let themeText = themes.isEmpty ? "your recent focus areas" : themes.joined(separator: ", ")

        let title = "Themes: \(themeText.capitalized)"
        let insight =
"""
Across your recent conversations, the recurring themes are: \(themeText).
If you want, I can turn one of these into a short, prioritized plan.
"""

        return ReflectionItem(
            id: UUID(),
            createdAt: Date(),
            title: title,
            insight: insight,
            supportingHistoryIDs: recent.map { $0.id }
        )
    }

    private static func topThemes(from text: String) -> [String] {
        let stop: Set<String> = [
            "the","a","an","and","or","to","of","in","on","for","with","my","i","me","you",
            "this","that","it","is","are","be","was","were","as","at","by","from","we",
            "plan","help","notes","summary","meeting","today","week","morning",
            "thinking","through","would","like","turn","into","simple"
        ]

        let tokens = text
            .replacingOccurrences(of: "’", with: "'")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 4 }
            .filter { !stop.contains($0) }

        var counts: [String: Int] = [:]
        for t in tokens { counts[t, default: 0] += 1 }

        return counts
            .sorted { $0.value > $1.value }
            .map { $0.key }
    }
}

// MARK: - App Routes

private enum Route: Hashable {
    case reflections
    case history
    case processing(AdvisorResponseModel)
    case response(AdvisorResponseModel)
    case reflectionDetail(ReflectionItem)
}

// MARK: - Home State

private enum HomeMode {
    case listening
    case didntCatchThat
}

// MARK: - Helpers

private func formatTimestamp(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter.string(from: date)
}

// MARK: - Root

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
                        ReflectionsView(path: $path).environmentObject(store)
                    case .history:
                        HistoryView(path: $path).environmentObject(store)
                    case .processing(let model):
                        ProcessingView(path: $path, next: model)
                    case .response(let model):
                        AdvisorResponseView(path: $path, model: model)
                    case .reflectionDetail(let item):
                        ReflectionDetailView(path: $path, item: item)
                    }
                }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Processing

private struct ProcessingView: View {
    @Binding var path: NavigationPath
    let next: AdvisorResponseModel

    @State private var didNavigate = false

    var body: some View {
        ZStack {
            CounselGradientBackground().ignoresSafeArea()

            VStack(spacing: 18) {
                Spacer()

                ProcessingPulse()

                Text("Working on it…")
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

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                // Replace processing route with response route (standard animation feel)
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
        .navigationBarHidden(true)
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

                // ✅ Save the interaction + maybe generate a reflection
                store.recordInteraction(input: input, model: model)

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

// MARK: - Advisor Stub (v1)

private enum AdvisorStub {
    static func generateResponse(from input: String) -> AdvisorResponseModel {
        let summary = "You’re thinking through: “\(truncate(input, limit: 90))”"

        let organized: [String] = [
            "Key point: \(truncate(input, limit: 60))",
            "Constraint: unclear (worth clarifying)",
            "Next: decide what “done” looks like"
        ]

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
    @EnvironmentObject private var store: AppStore

    var body: some View {
        ZStack {
            CounselGradientBackground().ignoresSafeArea()

            VStack(spacing: 18) {
                ReviewHeader(active: .reflections, path: $path)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Reflections")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(CounselColors.tertiaryText)

                        if store.reflections.isEmpty {
                            Text("No reflections yet.")
                                .font(.system(size: 18, weight: .regular))
                                .foregroundStyle(CounselColors.tertiaryText)
                                .padding(.top, 8)
                        } else {
                            ForEach(store.reflections) { item in
                                Button {
                                    path.append(Route.reflectionDetail(item))
                                } label: {
                                    ReviewRow(title: item.title, subtitle: formatTimestamp(item.createdAt))
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 6)
                    .padding(.bottom, 24)
                }
            }
        }
        .navigationBarHidden(true)
    }
}

private struct ReflectionDetailView: View {
    @Binding var path: NavigationPath
    let item: ReflectionItem

    var body: some View {
        ZStack {
            CounselGradientBackground().ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {

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

                    Text("Reflection")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(CounselColors.tertiaryText)

                    Text(item.title)
                        .font(.system(size: 26, weight: .regular))
                        .foregroundStyle(CounselColors.primaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(item.insight)
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(CounselColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 24)
                .padding(.top, 40)
                .padding(.bottom, 24)
            }
        }
        .navigationBarHidden(true)
    }
}

// MARK: - History

private struct HistoryView: View {
    @Binding var path: NavigationPath
    @EnvironmentObject private var store: AppStore

    var body: some View {
        ZStack {
            CounselGradientBackground().ignoresSafeArea()

            VStack(spacing: 18) {
                ReviewHeader(active: .history, path: $path)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Recent")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(CounselColors.tertiaryText)

                        if store.history.isEmpty {
                            Text("Nothing yet.")
                                .font(.system(size: 18, weight: .regular))
                                .foregroundStyle(CounselColors.tertiaryText)
                                .padding(.top, 8)
                        } else {
                            ForEach(store.history) { item in
                                Button {
                                    path.append(Route.response(item.model))
                                } label: {
                                    ReviewRow(title: item.title, subtitle: formatTimestamp(item.createdAt))
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 6)
                    .padding(.bottom, 24)
                }
            }
        }
        .navigationBarHidden(true)
    }
}

// MARK: - Response Screen

private struct AdvisorResponseView: View {
    @Binding var path: NavigationPath
    let model: AdvisorResponseModel

    @State private var showMemoryAck: Bool = true

    var body: some View {
        ZStack {
            CounselGradientBackground().ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {

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

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Summary")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(CounselColors.tertiaryText)

                        Text(model.summary)
                            .font(.system(size: 26, weight: .regular))
                            .foregroundStyle(CounselColors.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

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
                .padding(.top, 40)
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
                // Always return to root, even if deep in stack
                path = NavigationPath()
            }

            navItem("Reflections", isActive: active == .reflections) {
                if active != .reflections {
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
