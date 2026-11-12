import Foundation
import SwiftData

/// Form state for creating or editing an entry (the web app's `ItemDraft`).
struct EntryDraft {
    var name = ""
    var time = Date()
    var thought = ""
    var impact = 3
    var sentiment: Sentiment = .positive
    var kind: EntryKind = .impact

    init() {}

    init(entry: SpaceEntry) {
        name = entry.name
        time = entry.time
        thought = entry.thought
        impact = entry.impact
        sentiment = entry.sentiment
        kind = entry.kind
    }

    var isValid: Bool {
        kind == .note ? !thought.trimmed.isEmpty : !name.trimmed.isEmpty
    }
}

enum Store {
    static let maxSpaceNameLength = 40
    static let maxNoteLength = 2000

    @discardableResult
    static func createSpace(named rawName: String, in context: ModelContext) -> Space? {
        let name = String(rawName.trimmed.prefix(maxSpaceNameLength))
        guard !name.isEmpty else { return nil }
        let space = Space(name: name)
        context.insert(space)
        return space
    }

    static func rename(_ space: Space, to rawName: String) {
        let name = String(rawName.trimmed.prefix(maxSpaceNameLength))
        guard !name.isEmpty else { return }
        space.name = name
        space.updatedAt = Date()
    }

    static func delete(_ space: Space, in context: ModelContext) {
        for entry in space.entries ?? [] {
            context.insert(Tombstone(recordId: entry.id, recordType: "entry"))
        }
        context.insert(Tombstone(recordId: space.id, recordType: "space"))
        context.delete(space)
    }

    static func delete(_ entry: SpaceEntry, in context: ModelContext) {
        context.insert(Tombstone(recordId: entry.id, recordType: "entry"))
        entry.space?.updatedAt = Date()
        context.delete(entry)
    }

    /// Saves a draft into a new entry (when `entry` is nil) or an existing one.
    /// Watch-later dates follow the same rules as the web API's PUT handler.
    static func save(_ draft: EntryDraft, to entry: SpaceEntry?, in space: Space, context: ModelContext) {
        let now = Date()
        let target: SpaceEntry
        if let entry {
            target = entry
        } else {
            target = SpaceEntry()
            context.insert(target)
            target.space = space
        }

        let wasWatchLater = entry?.kind == .watchLater

        target.kind = draft.kind
        target.name = draft.kind == .note ? noteTitle(from: draft.thought) : draft.name.trimmed
        target.thought = draft.kind == .note
            ? String(draft.thought.trimmed.prefix(maxNoteLength))
            : draft.thought.trimmed
        target.time = draft.time
        target.impact = min(5, max(1, draft.impact))
        target.sentiment = draft.sentiment

        if draft.kind == .watchLater {
            if target.watchLaterAddedAt == nil { target.watchLaterAddedAt = now }
            target.watchLaterCompletedAt = nil
        } else {
            target.watchLaterAddedAt = nil
            if wasWatchLater { target.watchLaterCompletedAt = now }
        }

        target.updatedAt = now
        space.updatedAt = now
    }

    /// Notes have no name field; use the first line of the text.
    private static func noteTitle(from text: String) -> String {
        let firstLine = text.trimmed.components(separatedBy: .newlines).first ?? ""
        return String(firstLine.prefix(60))
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
