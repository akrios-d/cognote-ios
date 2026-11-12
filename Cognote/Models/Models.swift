import Foundation
import SwiftData

// CloudKit-compatible rules followed here (so iCloud can be switched on later):
// every stored property has a default or is optional, relationships are optional,
// and nothing uses @Attribute(.unique).

enum Sentiment: String, Codable, CaseIterable {
    case positive
    case negative
}

/// Mirrors `ItemType` from the web app: 'impact' | 'watchLater' | 'note'.
enum EntryKind: String, Codable, CaseIterable {
    case impact
    case watchLater
    case note
}

@Model
final class Space {
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \SpaceEntry.space)
    var entries: [SpaceEntry]? = []

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

@Model
final class SpaceEntry {
    var id: UUID = UUID()
    var name: String = ""
    var time: Date = Date()
    var thought: String = ""
    var impact: Int = 3
    var sentimentRaw: String = Sentiment.positive.rawValue
    var kindRaw: String = EntryKind.impact.rawValue
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var watchLaterAddedAt: Date?
    var watchLaterCompletedAt: Date?
    var space: Space?

    init() {
        self.id = UUID()
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var sentiment: Sentiment {
        get { Sentiment(rawValue: sentimentRaw) ?? .positive }
        set { sentimentRaw = newValue.rawValue }
    }

    var kind: EntryKind {
        get { EntryKind(rawValue: kindRaw) ?? .impact }
        set { kindRaw = newValue.rawValue }
    }

    /// Positive sentiment gives +intensity, negative gives -intensity.
    var signedImpact: Int { sentiment == .negative ? -impact : impact }
}

/// Records a deletion so a future sync with the web API can replay it.
/// iCloud sync does not need this; it propagates deletes on its own.
@Model
final class Tombstone {
    var recordId: UUID = UUID()
    var recordType: String = ""
    var deletedAt: Date = Date()

    init(recordId: UUID, recordType: String) {
        self.recordId = recordId
        self.recordType = recordType
        self.deletedAt = Date()
    }
}
