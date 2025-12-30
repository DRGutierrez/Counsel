import Foundation

/// Centralized UI copy for Counsel.
/// Keep strings here so the app feels coherent and changes are painless.
enum Copy {

    // MARK: - App / Global
    enum App {
        static let name = "Counsel"
        static let proName = "Counsel Pro"
        static let doneForNow = "Done for now"
        static let close = "Close"
        static let restore = "Restore"
        static let cancelAnytime = "Cancel anytime in Settings → Subscriptions"
        static let loading = "Loading…"
        static let workingOnIt = "Working on it…"
        static let copied = "Copied"
        static let copyAction = "Copy action"
    }

    // MARK: - Home
    enum Home {
        static let listening = "I’m listening."
        static let didntCatchThat = "I didn’t catch that."
        static let tryAgain = "Try again"
        static let typeInstead = "Type instead"
    }

    // MARK: - Type Sheet
    enum TypeSheet {
        static let title = "Type instead"
        static let send = "Send"
        static let placeholder = "Type here…"
    }

    // MARK: - Menu
    enum Menu {
        static let proTitle = "Counsel Pro"
        static let proSubtitle = "Unlimited reflections. Smarter guidance."
        static let reflections = "Reflections"
        static let history = "History"
        static let clearAllData = "Clear all data"
    }

    // MARK: - Reflections
    enum Reflections {
        static let title = "Reflections"
        static let empty = "No reflections yet.\nAdd a few entries first."
        static let reflectionLabel = "Reflection"
        static let chooseNextStep = "Choose a next step"
        static let chooseNextStepSubtitle = "From your recent entries"
    }

    // MARK: - History
    enum History {
        static let recent = "Recent"
        static let empty = "Nothing yet."
        static let noMatches = "No matches."
        static let searchPlaceholder = "Search"
        static let nextStepPrefix = "Next step: "
    }

    // MARK: - Advisor Response
    enum Response {
        static let summaryHeader = "Summary"
        static let keyThoughtsHeader = "Key thoughts"
        static let chooseMyNextStep = "Choose my next step"
        static let nextStepHint = "Takes ~30 seconds. No tasks created."
        static let memoryAckTitle = "I’ll remember this."
        static let memoryAckSubtitle = "You can review or remove memories anytime."
        static let undo = "Undo"
    }

    // MARK: - Plan
    enum Plan {
        static let screenTitle = "Choose your next step"
        static let screenSubtitle = "You only need one."
        static let contextHeader = "Context"
        static let whenLabel = "When"
        static let focusLabel = "Focus"
        static let actionCardTitle = "Which move feels right?"
        static let commitCTA = "Commit this step"
        static let chooseNextActionCTA = "Choose a next action"
        static let successToast = "Nice. You’ve locked in your next step."
    }
}
