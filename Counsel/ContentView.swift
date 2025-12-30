import SwiftUI
import Combine
import SwiftData
import CryptoKit
import UIKit

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

/// A normalized input to the Plan screen, so we can plan from:
/// - an Advisor response
/// - a Reflection

// MARK: - Store (History persisted, reflections derived)

@MainActor
final class AppStore: ObservableObject {
    @Published var history: [HistoryItem] = []
    @Published var reflections: [ReflectionItem] = []

    private var context: ModelContext?
    private var didLoad = false

    func setContextIfNeeded(_ context: ModelContext) {
        self.context = context
        guard !didLoad else { return }
        didLoad = true
        loadPersistedData()
    }

    private func loadPersistedData() {
        guard let context else { return }

        do {
            let historyRecords = try context.fetch(
                FetchDescriptor<HistoryRecord>(
                    sortBy: [SortDescriptor<HistoryRecord>(\.createdAt, order: .reverse)]
                )
            )

            self.history = historyRecords.map { rec in
                HistoryItem(
                    id: rec.id,
                    createdAt: rec.createdAt,
                    title: rec.title,
                    model: AdvisorResponseModel(
                        summary: rec.summary,
                        organized: rec.organized,
                        nextStepPrompt: rec.nextStepPrompt,
                        memorySnippet: rec.memorySnippet
                    )
                )
            }

            rebuildReflections()
        } catch {
            print("SwiftData load failed:", error)
        }
    }

    func recordInteraction(input: String, model: AdvisorResponseModel) {
        addHistory(input: input, model: model)
        rebuildReflections()
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

        guard let context else { return }
        let record = HistoryRecord(
            id: item.id,
            createdAt: item.createdAt,
            title: item.title,
            summary: model.summary,
            organized: model.organized,
            nextStepPrompt: model.nextStepPrompt,
            memorySnippet: model.memorySnippet
        )
        context.insert(record)
        try? context.save()
    }

    func clearAllData() {
        guard let context else { return }
        do {
            let histories = try context.fetch(FetchDescriptor<HistoryRecord>())
            histories.forEach { context.delete($0) }
            try context.save()
        } catch {
            print("Clear failed:", error)
        }

        history = []
        reflections = []
    }

    // MARK: - Derived reflections

    private struct WeekKey: Hashable { let year: Int; let week: Int }

    private func rebuildReflections() {
        let distinctDays = Set(history.map { Calendar.current.startOfDay(for: $0.createdAt) })
        let useWeekly = distinctDays.count >= 7

        let groups: [(key: String, sortDate: Date, items: [HistoryItem])] = useWeekly
        ? groupByWeek(history)
        : groupByDay(history)

        let rebuilt: [ReflectionItem] = groups
            .sorted { $0.sortDate > $1.sortDate }
            .map { g in
                let recent = Array(g.items.sorted { $0.createdAt > $1.createdAt }.prefix(8))
                let base = ReflectionEngine.generate(from: recent)

                // Stable id per group, so list animations/navigation stay sane.
                let id = stableUUID(seed: "reflection-\(g.key)")
                let createdAt = g.items.map(\.createdAt).max() ?? g.sortDate

                return ReflectionItem(
                    id: id,
                    createdAt: createdAt,
                    title: base.title,
                    insight: base.insight,
                    supportingHistoryIDs: base.supportingHistoryIDs
                )
            }

        reflections = rebuilt
    }

    private func groupByDay(_ items: [HistoryItem]) -> [(key: String, sortDate: Date, items: [HistoryItem])] {
        let cal = Calendar.current
        let buckets = Dictionary(grouping: items) { cal.startOfDay(for: $0.createdAt) }
        return buckets.map { day, items in
            (key: isoDayKey(day), sortDate: day, items: items)
        }
    }

    private func groupByWeek(_ items: [HistoryItem]) -> [(key: String, sortDate: Date, items: [HistoryItem])] {
        let cal = Calendar.current
        let buckets = Dictionary(grouping: items) { item in
            let year = cal.component(.yearForWeekOfYear, from: item.createdAt)
            let week = cal.component(.weekOfYear, from: item.createdAt)
            return WeekKey(year: year, week: week)
        }

        return buckets.map { key, items in
            let sortDate = items.map(\.createdAt).max() ?? Date()
            return (key: "\(key.year)-W\(key.week)", sortDate: sortDate, items: items)
        }
    }

    private func isoDayKey(_ date: Date) -> String {
        let cal = Calendar(identifier: .iso8601)
        let y = cal.component(.year, from: date)
        let m = cal.component(.month, from: date)
        let d = cal.component(.day, from: date)
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    private func stableUUID(seed: String) -> UUID {
        let data = Data(seed.utf8)
        let hash = SHA256.hash(data: data)
        let bytes = Array(hash.prefix(16))
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    // MARK: - Helpers

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

// MARK: - Reflection Engine (simple + useful, v1)

enum ReflectionEngine {
    static func generate(from recent: [HistoryItem]) -> ReflectionItem {
        let combined = recent
            .map { "\($0.title) \($0.model.summary) \($0.model.organized.joined(separator: " "))" }
            .joined(separator: " ")
            .lowercased()

        let themes = topThemes(from: combined).prefix(4)
        let themeText = themes.isEmpty ? "your recent focus areas" : themes.joined(separator: ", ")

        let title = "Themes: \(themeText.capitalized)"
        let insight =
"""
Across your recent entries, the recurring themes are: \(themeText).

If you want, pick one theme and I’ll turn it into a tiny plan you can do in 15 minutes.
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
            "thinking","through","would","like","turn","into","simple","about","your","recent"
        ]

        let tokens = text
            .replacingOccurrences(of: "’", with: "'")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 4 }
            .filter { !stop.contains($0) }

        var counts: [String: Int] = [:]
        for t in tokens { counts[t, default: 0] += 1 }

        return counts
            .sorted { $0.value > $1.value }
            .map { $0.key }
    }
}

// MARK: - Routes

private enum Route: Hashable {
    case reflections
    case history
    case processing(AdvisorResponseModel)
    case response(AdvisorResponseModel)
    case reflectionDetail(ReflectionItem)
    case plan(UUID)
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
    @Environment(\.modelContext) private var modelContext

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
                        AdvisorResponseView(path: $path, model: model).environmentObject(store)
                    case .reflectionDetail(let item):
                        ReflectionDetailView(path: $path, item: item)
                    case .plan(let id):
                        PlanRouteView(path: $path, recordID: id)
                    }
                }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            store.setContextIfNeeded(modelContext)
        }
    }
}

// MARK: - Processing

private struct ProcessingView: View {
    @Binding var path: NavigationPath
    let next: AdvisorResponseModel

    @State private var didNavigate = false

    var body: some View {
        ZStack {
            AppGradients.counsel.ignoresSafeArea()

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

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
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

// MARK: - Home

private struct HomeView: View {
    @Binding var path: NavigationPath
    @EnvironmentObject private var store: AppStore

    @State private var mode: HomeMode = .listening
    @State private var showMenu = false
    @State private var showPaywall = false
    @State private var showTypeSheet = false
    @State private var typedText = ""

    var body: some View {
        ZStack {
            AppGradients.counsel.ignoresSafeArea()

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

            // Top bar
            VStack {
                HStack {
                    Button { showPaywall = true } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "crown")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Pro")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(CounselColors.tertiaryText)
                        .padding(.leading, 16)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)

                    #if DEBUG
                    Button {
                        mode = (mode == .listening) ? .didntCatchThat : .listening
                    } label: {
                        Text(mode == .listening ? "Test error" : "Back to listen")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(CounselColors.tertiaryText)
                            .padding(.leading, 10)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    #endif

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
                onGoPro: {
                    showMenu = false
                    showPaywall = true
                },
                onGoReflections: {
                    showMenu = false
                    path.append(Route.reflections)
                },
                onGoHistory: {
                    showMenu = false
                    path.append(Route.history)
                },
                onClearAll: {
                    showMenu = false
                    store.clearAllData()
                    path = NavigationPath()
                }
            )
            .presentationDetents([.height(270)])
            .presentationDragIndicator(.visible)
        }
        
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .presentationDetents([.height(420), .large])
                .presentationDragIndicator(.visible)
        }
.sheet(isPresented: $showTypeSheet) {
            CounselTypeSheet(text: $typedText) {
                showTypeSheet = false

                let input = typedText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !input.isEmpty else { return }

                let model = AdvisorStub.generateResponse(from: input)

                // Save the interaction + rebuild derived reflections.
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

// MARK: - Advisor Stub (replace with real model later)

private enum AdvisorStub {
    static func generateResponse(from input: String) -> AdvisorResponseModel {
        let summary = "You’re thinking through: “\(truncate(input, limit: 96))”"

        let organized: [String] = [
            "Key point: \(truncate(input, limit: 66))",
            "Constraint: unclear (worth clarifying)",
            "Next: decide what “done” looks like"
        ]

        let memorySnippet: String? = extractPreference(input)

        return AdvisorResponseModel(
            summary: summary,
            organized: organized,
            nextStepPrompt: "Turn this into a plan",
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
        if lowered.contains("i prefer ") || lowered.contains("i like ") || lowered.contains("i want ") {
            return truncate(input, limit: 90)
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
            AppGradients.counsel.ignoresSafeArea()

            VStack(spacing: 18) {
                ReviewHeader(active: .reflections, path: $path)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Reflections")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(CounselColors.tertiaryText)

                        if store.reflections.isEmpty {
                            Text("No reflections yet.\nAdd a few entries first.")
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
            AppGradients.counsel.ignoresSafeArea()

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

                        Button("Turn into a plan") {
                            if let id = item.supportingHistoryIDs.first { path.append(Route.plan(id)) }
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(CounselColors.primaryText)
                        .buttonStyle(.plain)
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

    @State private var query: String = ""

    var filtered: [HistoryItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return store.history }
        return store.history.filter { item in
            item.title.lowercased().contains(q) ||
            item.model.summary.lowercased().contains(q) ||
            item.model.organized.joined(separator: " ").lowercased().contains(q)
        }
    }

    var body: some View {
        ZStack {
            AppGradients.counsel.ignoresSafeArea()

            VStack(spacing: 18) {
                ReviewHeader(active: .history, path: $path)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Recent")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(CounselColors.tertiaryText)

                        SearchBar(text: $query)

                        if filtered.isEmpty {
                            Text(query.isEmpty ? "Nothing yet." : "No matches.")
                                .font(.system(size: 18, weight: .regular))
                                .foregroundStyle(CounselColors.tertiaryText)
                                .padding(.top, 8)
                        } else {
                            ForEach(filtered) { item in
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

private struct SearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(CounselColors.tertiaryText)

            TextField("Search", text: $text)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .foregroundStyle(CounselColors.primaryText)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(CounselColors.tertiaryText)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Response Screen

private struct AdvisorResponseView: View {
    @Binding var path: NavigationPath
    let model: AdvisorResponseModel
    @EnvironmentObject private var store: AppStore

    @State private var showMemoryAck: Bool = true

    var body: some View {
        ZStack {
            AppGradients.counsel.ignoresSafeArea()

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
                        if let id = store.history.first?.id {
                            path.append(Route.plan(id))
                        }
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

// MARK: - Plan

private enum PlanTimeframe: String, CaseIterable, Identifiable, Hashable {
    case today = "Today"
    case thisWeek = "This week"
    case thisMonth = "This month"
    var id: String { rawValue }
}

private enum PlanPriority: String, CaseIterable, Identifiable, Hashable {
    case quickWin = "Quick win"
    case important = "Important"
    case deepWork = "Deep work"
    var id: String { rawValue }
}


private struct PlanRouteView: View {
    @Binding var path: NavigationPath
    let recordID: UUID

    @Environment(\.modelContext) private var modelContext
    @State private var record: HistoryRecord?

    var body: some View {
        Group {
            if let record {
                PlanView(path: $path, record: record)
            } else {
                ZStack {
                    AppGradients.counsel.ignoresSafeArea()
                    ProgressView("Loading…")
                        .tint(CounselColors.primaryText)
                }
                .task { await load() }
            }
        }
        .navigationBarHidden(true)
    }

    private func load() async {
        do {
            let descriptor = FetchDescriptor<HistoryRecord>(
                predicate: #Predicate { $0.id == recordID },
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            record = try modelContext.fetch(descriptor).first
        } catch {
            record = nil
        }
    }
}

private struct PlanView: View {
    @Binding var path: NavigationPath
    @Environment(\.modelContext) private var modelContext
    let record: HistoryRecord


    @State private var timeframe: PlanTimeframe = .thisWeek
    @State private var priority: PlanPriority = .important

    // Single-choice selection (radio)
    @State private var selectedActionIndex: Int? = nil

    @State private var showCopied: Bool = false
    @State private var showCommitted: Bool = false

    var body: some View {
        ZStack {
            AppGradients.counsel.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Commit the plan")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(CounselColors.tertiaryText)

                        Text(record.summary)
                            .font(.system(size: 28, weight: .regular))
                            .foregroundStyle(CounselColors.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    settingsCard

                    nextMoveCard

                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 24)
                .padding(.top, 40)
                .padding(.bottom, 90) // leave room for bottom CTA
            }
        }
        .navigationBarHidden(true)
        .safeAreaInset(edge: .bottom) {
            bottomCTA
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
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

            Button(showCopied ? "Copied" : "Copy action") {
                copySelectedAction()
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(showCopied ? CounselColors.secondaryText : CounselColors.primaryText)
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .buttonStyle(.plain)
            .disabled(selectedActionIndex == nil)
            .opacity(selectedActionIndex == nil ? 0.45 : 1.0)
        }
    }

    // MARK: - Cards

    private var settingsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(CounselColors.tertiaryText)

            VStack(alignment: .leading, spacing: 10) {
                planPicker(title: "Timeframe", selection: $timeframe)
                planPicker(title: "Priority", selection: $priority)
            }
            .padding(14)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private var nextMoveCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose the move that unlocks progress")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(CounselColors.tertiaryText)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(actions.enumerated()), id: \.offset) { idx, action in
                    Button {
                        select(idx)
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: selectedActionIndex == idx ? "largecircle.fill.circle" : "circle")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(selectedActionIndex == idx ? CounselColors.primaryText : CounselColors.tertiaryText)

                            Text(action)
                                .font(.system(size: 18, weight: .regular))
                                .foregroundStyle(CounselColors.primaryText)
                                .fixedSize(horizontal: false, vertical: true)

                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)

                    if idx != actions.count - 1 {
                        Divider().opacity(0.10)
                    }
                }
            }
            .padding(14)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    // MARK: - Bottom CTA

    private var bottomCTA: some View {
        VStack(spacing: 10) {
            if showCommitted {
                Text("Nice. You’ve locked in your next step.")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(CounselColors.tertiaryText)
                    .transition(.opacity)
            }

            Button {
                commit()
            } label: {
                HStack {
                    Text(primaryButtonTitle)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(selectedActionIndex == nil ? CounselColors.secondaryText : .black)
                    Spacer()
                    Image(systemName: "checkmark")
                        .foregroundStyle(selectedActionIndex == nil ? CounselColors.tertiaryText : .black)
                }
                .padding(14)
                .background {
                    if selectedActionIndex == nil {
                        RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.ultraThinMaterial).opacity(0.18)
                    } else {
                        RoundedRectangle(cornerRadius: 18, style: .continuous).fill(CounselColors.primaryText)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(selectedActionIndex == nil)
            .opacity(selectedActionIndex == nil ? 0.65 : 1.0)

            Button {
                // Success-driven exit, not "Close"
                if path.count > 0 { path.removeLast() }
            } label: {
                HStack {
                    Text("Done for now")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(CounselColors.secondaryText)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundStyle(CounselColors.tertiaryText)
                }
                .padding(14)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(.ultraThinMaterial)
    }

    private var primaryButtonTitle: String {
        if let idx = selectedActionIndex {
            return "Commit: \(actions[idx])"
        }
        return "Choose a next action"
    }

    // MARK: - Actions / Logic

    private var actions: [String] {
        let out = PlanHeuristics.actions(from: record.organized, timeframe: timeframe, priority: priority)
        return out
    }

    private func select(_ idx: Int) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        selectedActionIndex = idx
    }

    private func commit() {
        guard let idx = selectedActionIndex else { return }

        // Save the commitment into history (source of truth)
        record.planCommittedAction = actions[idx]
        record.planTimeframe = timeframe.rawValue
        record.planPriority = priority.rawValue
        record.planCommittedAt = Date()

        do {
            try modelContext.save()
        } catch {
            // If you already have an error banner system, hook it here.
            // For now: silent fail is acceptable for V1, but better to show an alert.
            print("Failed to save plan commitment: \(error)")
        }

        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.easeInOut(duration: 0.18)) { showCommitted = true }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            if path.count > 0 { path.removeLast() }
        }
    }


    private func copySelectedAction() {
        guard let idx = selectedActionIndex else { return }
        UIPasteboard.general.string = actions[idx]
        showCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            showCopied = false
        }
    }

    private func planPicker<T: CaseIterable & Identifiable & RawRepresentable & Hashable>(
        title: String,
        selection: Binding<T>
    ) -> some View where T.RawValue == String {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(CounselColors.secondaryText)

            Spacer()

            Picker(title, selection: selection) {
                ForEach(Array(T.allCases), id: \.id) { v in
                    Text(v.rawValue).tag(v)
                }
            }
            .pickerStyle(.menu)
            .tint(CounselColors.primaryText)
        }
    }
}

private enum PlanHeuristics {
    static func bullets(from insight: String) -> [String] {
        // Split into short-ish sentences, prefer actionable ones.
        let cleaned = insight
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "…", with: ".")
        let parts = cleaned
            .components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 8 }

        if parts.isEmpty {
            return ["Pick one theme and define what success looks like.", "List the smallest next step.", "Block 15 minutes to start."]
        }

        // Keep up to 6 bullets.
        return Array(parts.prefix(6))
    }

    static func actions(from bullets: [String], timeframe: PlanTimeframe, priority: PlanPriority) -> [String] {
        var out: [String] = []
        for b in bullets {
            let a = normalizeToAction(b)
            if !a.isEmpty { out.append(a) }
            if out.count == 3 { break }
        }

        if out.isEmpty {
            out = [
                "Write down what “done” looks like.",
                "List the smallest next step you can take.",
                "Block 15 minutes and start."
            ]
        }

        // Light flavoring (simple, not preachy)
        switch priority {
        case .quickWin:
            out = out.map { "Quick win (\(timeframe.rawValue.lowercased())): \($0)" }
        case .important:
            break
        case .deepWork:
            out = out.map { "Deep work: \($0)" }
        }

        return out
    }

    private static func normalizeToAction(_ s: String) -> String {
        var t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return "" }

        // Remove leading labels like "Key point:" "Constraint:" "Next:"
        let prefixes = ["key point:", "constraint:", "next:", "note:"]
        let lower = t.lowercased()
        for p in prefixes {
            if lower.hasPrefix(p) {
                t = t.dropFirst(p.count).trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
        }

        // Convert common non-actions into actions
        let l = t.lowercased()
        if l.contains("unclear") || l.contains("not sure") {
            t = "Write one sentence clarifying what you mean."
        } else if l.contains("worth clarifying") {
            t = "Write 3 bullets clarifying what matters most."
        }

        // Ensure it reads like an action.
        let starters = ["decide","write","list","pick","define","clarify","schedule","draft","start","review","ask"]
        if !starters.contains(where: { t.lowercased().hasPrefix($0) }) {
            t = "Clarify " + t
        }

        // Capitalize first letter
        if let first = t.first {
            t.replaceSubrange(t.startIndex...t.startIndex, with: String(first).uppercased())
        }

        t = t.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        return t
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
    let onGoPro: () -> Void
    let onGoReflections: () -> Void
    let onGoHistory: () -> Void
    let onClearAll: () -> Void

    var body: some View {
        ZStack {
            AppGradients.counsel.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                Spacer(minLength: 10)

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Counsel Pro")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(CounselColors.primaryText)
                        Text("Unlock unlimited + upcoming voice & AI.")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(CounselColors.tertiaryText)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(CounselColors.tertiaryText)
                }
                .contentShape(Rectangle())
                .onTapGesture { onGoPro() }

                Divider().opacity(0.12)

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

                Divider().opacity(0.12)

                Text("Clear all data")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(CounselColors.destructive)
                    .onTapGesture { onClearAll() }

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
                AppGradients.counsel.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 14) {
                    Text("Type instead")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(CounselColors.tertiaryText)

                    TextEditor(text: $text)
                        .scrollContentBackground(.hidden)
                        .padding(12)
                        .background(.ultraThinMaterial)
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


#Preview {
    ContentView()
        .modelContainer(for: [HistoryRecord.self], inMemory: true)
}

