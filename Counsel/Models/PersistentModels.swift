import Foundation
import SwiftData

/// Source of truth for Counsel: persisted history only.
/// Everything else (reflections, plans) is derived from history.
@Model
final class HistoryRecord {
    var id: UUID
    var createdAt: Date
    var title: String

    var summary: String
    var organized: [String]
    var nextStepPrompt: String
    var memorySnippet: String?

    // ✅ Plan commitment (what user actually locks in)
    var planTimeframe: String?
    var planPriority: String?
    var planCommittedAction: String?
    var planCommittedAt: Date?

    init(
        id: UUID,
        createdAt: Date,
        title: String,
        summary: String,
        organized: [String],
        nextStepPrompt: String,
        memorySnippet: String?
    ) {
        self.id = id
        self.createdAt = createdAt
        self.title = title
        self.summary = summary
        self.organized = organized
        self.nextStepPrompt = nextStepPrompt
        self.memorySnippet = memorySnippet

        // defaults
        self.planTimeframe = nil
        self.planPriority = nil
        self.planCommittedAction = nil
        self.planCommittedAt = nil
    }
}
