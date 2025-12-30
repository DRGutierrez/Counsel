//
//  ContentView.swift
//  Counsel
//
//  Drop-in replacement for a simple “Reflections” app shell.
//  This file is intentionally self-contained so the project compiles
//  even if other model/store files are missing.
//

import SwiftUI
import Combine

// MARK: - Model

struct Reflection: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var title: String
    var body: String

    init(id: UUID = UUID(), createdAt: Date = Date(), title: String, body: String) {
        self.id = id
        self.createdAt = createdAt
        self.title = title
        self.body = body
    }
}

// MARK: - Store (ObservableObject)

@MainActor
final class ReflectionStore: ObservableObject {
    @Published private(set) var reflections: [Reflection] = [] {
        didSet { save() }
    }

    private let fileName = "reflections.json"

    init() {
        load()
    }

    func add(title: String, body: String) {
        let new = Reflection(title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                             body: body.trimmingCharacters(in: .whitespacesAndNewlines))
        reflections.insert(new, at: 0)
    }

    func update(_ reflection: Reflection) {
        guard let idx = reflections.firstIndex(where: { $0.id == reflection.id }) else { return }
        reflections[idx] = reflection
    }

    func delete(at offsets: IndexSet) {
        reflections.remove(atOffsets: offsets)
    }

    func delete(_ reflection: Reflection) {
        reflections.removeAll { $0.id == reflection.id }
    }

    // MARK: Persistence

    private func documentsURL() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    private func fileURL() -> URL {
        documentsURL().appendingPathComponent(fileName)
    }

    private func load() {
        let url = fileURL()
        guard let data = try? Data(contentsOf: url) else {
            // Seed with a friendly default so the UI doesn’t look empty on first launch.
            reflections = [
                Reflection(title: "Welcome 👋",
                           body: "This is your first reflection.\n\nTap + to add more. Long-press an item for quick actions.")
            ]
            return
        }

        do {
            reflections = try JSONDecoder().decode([Reflection].self, from: data)
        } catch {
            // If decoding fails, keep the app usable.
            reflections = [
                Reflection(title: "Oops 😅",
                           body: "I couldn’t read your saved reflections (format changed or file corrupted).\n\nStart fresh—your app still works.")
            ]
        }
    }

    private func save() {
        let url = fileURL()
        do {
            let data = try JSONEncoder().encode(reflections)
            try data.write(to: url, options: [.atomic])
        } catch {
            // Avoid crashing; persistence failures should be non-fatal.
            // You can add logging here later if you want.
        }
    }
}

// MARK: - ContentView (App Shell)

struct ContentView: View {
    @StateObject private var store = ReflectionStore()

    var body: some View {
        TabView {
            HomeView(store: store)
                .tabItem { Label("Home", systemImage: "house") }

            ReflectionsView(store: store)
                .tabItem { Label("Reflections", systemImage: "book.closed") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}

// MARK: - Home

private struct HomeView: View {
    @ObservedObject var store: ReflectionStore

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                header

                if let latest = store.reflections.first {
                    LatestCard(reflection: latest)
                } else {
                    ContentUnavailableView("No reflections yet",
                                           systemImage: "note.text",
                                           description: Text("Tap + in the Reflections tab to add one."))
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Counsel")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Daily check-in")
                .font(.title2).bold()

            Text("Capture a thought, a win, or a lesson. Future-you will be annoyingly grateful.")
                .foregroundStyle(.secondary)
        }
    }
}

private struct LatestCard: View {
    let reflection: Reflection

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Latest")
                    .font(.headline)
                Spacer()
                Text(reflection.createdAt, style: .date)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text(reflection.title)
                .font(.title3).bold()
                .lineLimit(2)

            Text(reflection.body)
                .foregroundStyle(.secondary)
                .lineLimit(4)
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Reflections List

private struct ReflectionsView: View {
    @ObservedObject var store: ReflectionStore

    @State private var showingAdd = false
    @State private var selected: Reflection?
    @State private var searchText = ""

    private var filtered: [Reflection] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return store.reflections }
        return store.reflections.filter {
            $0.title.localizedCaseInsensitiveContains(q) ||
            $0.body.localizedCaseInsensitiveContains(q)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filtered) { reflection in
                    Button {
                        selected = reflection
                    } label: {
                        ReflectionRow(reflection: reflection)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button {
                            UIPasteboard.general.string = "\(reflection.title)\n\n\(reflection.body)"
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }

                        Button(role: .destructive) {
                            store.delete(reflection)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                .onDelete(perform: store.delete)
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic))
            .navigationTitle("Reflections")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add reflection")
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddReflectionSheet(store: store)
            }
            .sheet(item: $selected) { reflection in
                ReflectionDetailView(store: store, reflection: reflection)
            }
        }
    }
}

private struct ReflectionRow: View {
    let reflection: Reflection

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(reflection.title)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text(reflection.createdAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(reflection.body)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Add Reflection

private struct AddReflectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: ReflectionStore

    @State private var title = ""
    @State private var body = ""
    @FocusState private var focusField: Field?

    enum Field { case title, body }

    var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("e.g., What I learned today…", text: $title)
                        .focused($focusField, equals: .title)
                }

                Section("Reflection") {
                    TextEditor(text: $body)
                        .frame(minHeight: 180)
                        .focused($focusField, equals: .body)
                }
            }
            .navigationTitle("New Reflection")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.add(title: title, body: body)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
            .onAppear { focusField = .title }
        }
    }
}

// MARK: - Detail / Edit

private struct ReflectionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: ReflectionStore

    @State var reflection: Reflection
    @State private var isEditing = false

    init(store: ReflectionStore, reflection: Reflection) {
        self.store = store
        _reflection = State(initialValue: reflection)
    }

    var body: some View {
        NavigationStack {
            Group {
                if isEditing {
                    Form {
                        Section("Title") {
                            TextField("Title", text: $reflection.title)
                        }
                        Section("Reflection") {
                            TextEditor(text: $reflection.body)
                                .frame(minHeight: 220)
                        }
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(reflection.title)
                                .font(.title2).bold()

                            Text(reflection.createdAt, style: .date)
                                .foregroundStyle(.secondary)

                            Divider()

                            Text(reflection.body)
                                .font(.body)
                                .textSelection(.enabled)
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit" : "Reflection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isEditing ? "Cancel" : "Close") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if isEditing {
                        Button("Done") {
                            store.update(reflection)
                            isEditing = false
                        }
                    } else {
                        Button("Edit") { isEditing = true }
                    }
                }
                ToolbarItem(placement: .bottomBar) {
                    if !isEditing {
                        Button(role: .destructive) {
                            store.delete(reflection)
                            dismiss()
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Settings

private struct SettingsView: View {
    var body: some View {
        NavigationStack {
            Form {
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Tips") {
                    Label("Long-press a reflection for quick actions", systemImage: "hand.tap")
                    Label("Use search to find past notes", systemImage: "magnifyingglass")
                }
            }
            .navigationTitle("Settings")
        }
    }
}

// MARK: - Previews

#Preview {
    ContentView()
}
