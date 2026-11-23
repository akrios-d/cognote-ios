import Foundation
import SwiftUI
import SwiftData
import CoreTransferable
import UniformTypeIdentifiers

// MARK: - CSV

struct CSVExport: Transferable {
    let text: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { file in
            Data(file.text.utf8)
        }
        .suggestedFileName("cognote.csv")
    }

    static func make(entries: [SpaceEntry]) -> String {
        let header = ["name", "date", "type", "sentiment", "impact", "thought"]
        let rows = entries.map { entry in
            [
                entry.name,
                APIPayload.dayString(entry.time),
                entry.kind.rawValue,
                entry.kind == .impact ? entry.sentiment.rawValue : "",
                entry.kind == .impact ? String(entry.impact) : "",
                entry.thought,
            ]
        }
        return ([header] + rows)
            .map { $0.map(escape).joined(separator: ",") }
            .joined(separator: "\n")
    }

    private static func escape(_ field: String) -> String {
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0.isNewline }) else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}

// MARK: - Payload for the web API (not wired up yet)

/// JSON in the same shape as the web app's `WorkspaceModel` / `WorkspaceItemModel`,
/// so a future `/api/import` endpoint can store it as-is. Ids are the app's UUIDs.
struct APIPayload: Codable {
    struct Workspace: Codable {
        let id: String
        let name: String
        let createdAt: String
        let updatedAt: String
    }

    struct Item: Codable {
        let id: String
        let workspaceId: String
        let name: String
        let time: String
        let thought: String
        let impact: Int
        let sentiment: String
        let itemType: String
        let createdAt: String
        let updatedAt: String
        let watchLaterAddedAt: String?
        let watchLaterCompletedAt: String?
        /// Full timestamp of `time`, so a backup keeps the time of day. Optional for older files.
        var timeExact: String? = nil
    }

    struct Deleted: Codable {
        let id: String
        let type: String
        let deletedAt: String
    }

    let exportedAt: String
    let workspaces: [Workspace]
    let items: [Item]
    let deleted: [Deleted]

    /// Builds the payload. Pass `since` to include only what changed after the last upload.
    static func build(context: ModelContext, since: Date? = nil) throws -> APIPayload {
        let spaces = try context.fetch(FetchDescriptor<Space>())
        let entries = try context.fetch(FetchDescriptor<SpaceEntry>())
        let tombstones = try context.fetch(FetchDescriptor<Tombstone>())

        func changed(_ date: Date) -> Bool { since.map { date > $0 } ?? true }

        return APIPayload(
            exportedAt: iso(Date()),
            workspaces: spaces.filter { changed($0.updatedAt) }.map {
                Workspace(id: $0.id.uuidString, name: $0.name, createdAt: iso($0.createdAt), updatedAt: iso($0.updatedAt))
            },
            items: entries.filter { changed($0.updatedAt) }.compactMap { entry in
                guard let space = entry.space else { return nil }
                return Item(
                    id: entry.id.uuidString,
                    workspaceId: space.id.uuidString,
                    name: entry.name,
                    time: dayString(entry.time),
                    thought: entry.thought,
                    impact: entry.impact,
                    sentiment: entry.sentiment.rawValue,
                    itemType: entry.kind.rawValue,
                    createdAt: iso(entry.createdAt),
                    updatedAt: iso(entry.updatedAt),
                    watchLaterAddedAt: entry.watchLaterAddedAt.map(iso),
                    watchLaterCompletedAt: entry.watchLaterCompletedAt.map(iso),
                    timeExact: iso(entry.time)
                )
            },
            deleted: tombstones.filter { changed($0.deletedAt) }.map {
                Deleted(id: $0.recordId.uuidString, type: $0.recordType, deletedAt: iso($0.deletedAt))
            }
        )
    }

    func jsonData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    static func iso(_ date: Date) -> String {
        date.formatted(.iso8601)
    }

    /// "YYYY-MM-DD" in the device's time zone, like the web form's date input.
    static func dayString(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}

// MARK: - Backup file (export and import)

extension UTType {
    /// `.cognote` files: JSON backups the app owns, so Files and AirDrop open them in CogNote.
    /// Declared in Info.plist (UTExportedTypeDeclarations + CFBundleDocumentTypes).
    static let cognoteBackup = UTType(exportedAs: "dev.akrios.cognote.backup", conformingTo: .json)
}

/// A JSON backup of every space and entry, handed to the share sheet.
struct BackupFile: Transferable {
    let data: Data

    @MainActor
    static func make(context: ModelContext) -> BackupFile {
        let data = (try? APIPayload.build(context: context).jsonData()) ?? Data()
        return BackupFile(data: data)
    }

    static var fileName: String {
        "CogNote-backup-" + APIPayload.dayString(Date()) + ".cognote"
    }

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .cognoteBackup) { file in
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(BackupFile.fileName)
            try file.data.write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }
}

/// The same backup, as a document for the system "Save" panel (fileExporter).
struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.cognoteBackup, .json] }
    static var writableContentTypes: [UTType] { [.cognoteBackup] }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct ImportResult {
    var spaces = 0
    var entries = 0
    var deleted = 0
}

enum ImportMode {
    /// Keep current data; add or update from the file (newer `updatedAt` wins).
    case merge
    /// Save a safety copy, erase current data, then load the file.
    case replace
}

enum BackupImporter {
    /// Imports a backup file. The file is read and validated before anything local changes.
    @MainActor
    static func importFile(at url: URL, mode: ImportMode, into context: ModelContext) throws -> ImportResult {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        let payload = try JSONDecoder().decode(APIPayload.self, from: data)
        defer { removeIfInbox(url) }

        switch mode {
        case .merge:
            return try merge(payload, into: context, applyDeletions: true)
        case .replace:
            try SafetyBackups.save(from: context)
            try wipe(context)
            return try merge(payload, into: context, applyDeletions: false)
        }
    }

    /// Brings back the data from before the last replace (and saves the current data first,
    /// so this can be undone too).
    @MainActor
    static func undoLastReplace(into context: ModelContext) throws -> ImportResult {
        guard let url = SafetyBackups.latest() else { throw CocoaError(.fileNoSuchFile) }
        return try importFile(at: url, mode: .replace, into: context)
    }

    /// AirDrop and Mail hand files over as copies in Documents/Inbox; drop them once imported.
    private static func removeIfInbox(_ url: URL) {
        if url.deletingLastPathComponent().lastPathComponent == "Inbox" {
            try? FileManager.default.removeItem(at: url)
        }
    }

    @MainActor
    private static func wipe(_ context: ModelContext) throws {
        for space in try context.fetch(FetchDescriptor<Space>()) { context.delete(space) }
        for entry in try context.fetch(FetchDescriptor<SpaceEntry>()) { context.delete(entry) }
        for tombstone in try context.fetch(FetchDescriptor<Tombstone>()) { context.delete(tombstone) }
        try context.save()
    }

    /// Records are matched by id; the newer `updatedAt` wins, so importing the same file twice changes nothing.
    @MainActor
    static func merge(_ payload: APIPayload, into context: ModelContext, applyDeletions: Bool) throws -> ImportResult {
        var result = ImportResult()
        var spaces: [UUID: Space] = [:]
        for space in try context.fetch(FetchDescriptor<Space>()) { spaces[space.id] = space }
        var entries: [UUID: SpaceEntry] = [:]
        for entry in try context.fetch(FetchDescriptor<SpaceEntry>()) { entries[entry.id] = entry }

        for incoming in payload.workspaces {
            guard let id = UUID(uuidString: incoming.id) else { continue }
            let updated = parseISO(incoming.updatedAt) ?? Date()
            if let existing = spaces[id] {
                guard updated > existing.updatedAt else { continue }
                existing.name = incoming.name
                existing.updatedAt = updated
            } else {
                let space = Space(name: incoming.name)
                space.id = id
                space.createdAt = parseISO(incoming.createdAt) ?? updated
                space.updatedAt = updated
                context.insert(space)
                spaces[id] = space
            }
            result.spaces += 1
        }

        for incoming in payload.items {
            guard let id = UUID(uuidString: incoming.id),
                  let spaceId = UUID(uuidString: incoming.workspaceId),
                  let space = spaces[spaceId] else { continue }
            let updated = parseISO(incoming.updatedAt) ?? Date()

            let target: SpaceEntry
            if let existing = entries[id] {
                guard updated > existing.updatedAt else { continue }
                target = existing
            } else {
                target = SpaceEntry()
                target.id = id
                target.createdAt = parseISO(incoming.createdAt) ?? updated
                context.insert(target)
                entries[id] = target
            }

            target.space = space
            target.name = incoming.name
            target.thought = incoming.thought
            target.impact = min(5, max(1, incoming.impact))
            target.sentiment = Sentiment(rawValue: incoming.sentiment) ?? .positive
            target.kind = EntryKind(rawValue: incoming.itemType) ?? .impact
            target.time = incoming.timeExact.flatMap(parseISO) ?? parseDay(incoming.time) ?? updated
            target.watchLaterAddedAt = incoming.watchLaterAddedAt.flatMap(parseISO)
            target.watchLaterCompletedAt = incoming.watchLaterCompletedAt.flatMap(parseISO)
            target.updatedAt = updated
            result.entries += 1
        }

        for removed in applyDeletions ? payload.deleted : [] {
            guard let id = UUID(uuidString: removed.id) else { continue }
            let deletedAt = parseISO(removed.deletedAt) ?? Date()
            switch removed.type {
            case "entry":
                if let entry = entries[id], deletedAt >= entry.updatedAt {
                    Store.delete(entry, in: context)
                    entries[id] = nil
                    result.deleted += 1
                }
            case "space":
                if let space = spaces[id], deletedAt >= space.updatedAt {
                    Store.delete(space, in: context)
                    spaces[id] = nil
                    result.deleted += 1
                }
            default:
                continue
            }
        }

        try context.save()
        return result
    }

    /// Accepts "2026-11-01T20:00:00Z" and, from other sources, "2026-11-01T20:00:00.000Z".
    private static func parseISO(_ text: String) -> Date? {
        (try? Date.ISO8601FormatStyle().parse(text))
            ?? (try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(text))
    }

    /// "YYYY-MM-DD" from the web app, placed at noon local time.
    private static func parseDay(_ text: String) -> Date? {
        let parts = text.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return Calendar.current.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12))
    }
}

/// Automatic copies saved before a replace, in Documents/Safety backups (visible in the Files app).
enum SafetyBackups {
    private static let keep = 5

    static var folder: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("Safety backups", isDirectory: true)
    }

    @MainActor
    static func save(from context: ModelContext) throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let stamp = Date().formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false))
            .replacingOccurrences(of: ":", with: "-")
        let url = folder.appendingPathComponent("CogNote-before-replace-\(stamp).json")
        try APIPayload.build(context: context).jsonData().write(to: url, options: .atomic)
        prune()
    }

    /// Most recent safety copy, if any.
    static func latest() -> URL? {
        sortedFiles().first
    }

    private static func sortedFiles() -> [URL] {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.creationDateKey]
        )) ?? []
        return files
            .filter { $0.pathExtension == "json" }
            .sorted { creationDate($0) > creationDate($1) }
    }

    private static func creationDate(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
    }

    private static func prune() {
        for url in sortedFiles().dropFirst(keep) {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
