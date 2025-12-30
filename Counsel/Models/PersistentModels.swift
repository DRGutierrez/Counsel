import Foundation
import SwiftData

@Model
final class HistoryRecord {
    var id: UUID
    var createdAt: Date
    var title: String

    var summary: String
    var organized: [String]
    var nextStepPrompt: String
    var memorySnippet: String?

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
    }
}

@Model
final class ReflectionRecord {
    var id: UUID
    var createdAt: Date
    var title: String
    var insight: String
    var supportingHistoryIDs: [UUID]

    init(
        id: UUID,
        createdAt: Date,
        title: String,
        insight: String,
        supportingHistoryIDs: [UUID]
    ) {
        self.id = id
        self.createdAt = createdAt
        self.title = title
        self.insight = insight
        self.supportingHistoryIDs = supportingHistoryIDs
    }
}
