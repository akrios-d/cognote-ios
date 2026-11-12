import Foundation
import SwiftData

// Port of server/lib/insights-calc.ts, computed on device.

enum InsightPeriod: String, CaseIterable, Identifiable {
    case week
    case month
    case year

    var id: String { rawValue }

    var component: Calendar.Component {
        switch self {
        case .week: return .weekOfYear
        case .month: return .month
        case .year: return .year
        }
    }

    var labelKey: String {
        switch self {
        case .week: return "insights.viewWeek"
        case .month: return "insights.viewMonth"
        case .year: return "insights.viewYear"
        }
    }

    var currentKey: String {
        switch self {
        case .week: return "insights.thisWeek"
        case .month: return "insights.thisMonth"
        case .year: return "insights.thisYear"
        }
    }

    var completedKey: String {
        switch self {
        case .week: return "insights.wlCompletedWeek"
        case .month: return "insights.wlCompletedMonth"
        case .year: return "insights.wlCompletedYear"
        }
    }
}

struct SpaceInsight: Identifiable {
    let space: Space
    let totalItems: Int
    let impactCount: Int
    let noteCount: Int
    let watchLaterCount: Int
    let avgImpact: Double
    let highest: SpaceEntry?
    let lastEntryAt: Date?

    var id: PersistentIdentifier { space.persistentModelID }
    var name: String { space.name }
}

struct WeekBucket: Identifiable {
    let start: Date
    let count: Int
    let avgImpact: Double
    let positive: Int
    let negative: Int

    var id: Date { start }
}

struct Insights {
    var totalItems = 0
    var positiveCount = 0
    var negativeCount = 0
    var avgImpact: Double = 0
    var highest: SpaceEntry?
    var watchLaterCompleted = 0
    var streak = 0
    var bySpace: [SpaceInsight] = []
    var byWeek: [WeekBucket] = []
    var activeWeeks = 0
    /// Change in average impact versus the previous week (week view only).
    var trend: Double?

    var best: SpaceInsight? { bySpace.count >= 2 ? bySpace.first : nil }
    var worst: SpaceInsight? { bySpace.count >= 2 ? bySpace.last : nil }
    var isEmpty: Bool { totalItems == 0 }
}

enum InsightsCalculator {
    /// ISO-8601 weeks (Monday first), in the device's time zone.
    static let calendar: Calendar = {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = .current
        return cal
    }()

    static func interval(_ period: InsightPeriod, containing date: Date) -> DateInterval {
        calendar.dateInterval(of: period.component, for: date)
            ?? DateInterval(start: calendar.startOfDay(for: date), duration: 86_400)
    }

    static func shift(_ date: Date, _ period: InsightPeriod, by value: Int) -> Date {
        calendar.date(byAdding: period.component, value: value, to: date) ?? date
    }

    static func contains(_ range: DateInterval, _ date: Date) -> Bool {
        date >= range.start && date < range.end
    }

    static func build(
        spaces: [Space],
        entries: [SpaceEntry],
        period: InsightPeriod,
        anchor: Date,
        now: Date = Date()
    ) -> Insights {
        let range = interval(period, containing: anchor)
        let impacts = entries.filter { $0.kind == .impact }
        let inRange = impacts.filter { contains(range, $0.time) }

        var result = Insights()
        result.totalItems = inRange.count
        result.positiveCount = inRange.filter { $0.sentiment == .positive }.count
        result.negativeCount = result.totalItems - result.positiveCount
        result.avgImpact = average(inRange)
        result.highest = inRange.max { $0.signedImpact < $1.signedImpact }
        result.watchLaterCompleted = entries.filter { entry in
            guard let completed = entry.watchLaterCompletedAt else { return false }
            return contains(range, completed)
        }.count
        result.streak = streak(entries.filter { $0.kind != .watchLater }, now: now)

        let periodEntries = entries.filter { $0.kind != .watchLater && contains(range, $0.time) }
        result.bySpace = spaceInsights(spaces: spaces, entries: periodEntries, includeEmpty: false)
            .filter { $0.impactCount > 0 }

        result.byWeek = weekStarts(for: period, range: range).map { start in
            let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start) ?? start
            let week = impacts.filter { contains(DateInterval(start: start, end: end), $0.time) }
            let positive = week.filter { $0.sentiment == .positive }.count
            return WeekBucket(
                start: start,
                count: week.count,
                avgImpact: average(week),
                positive: positive,
                negative: week.count - positive
            )
        }
        result.activeWeeks = result.byWeek.filter { $0.count > 0 }.count

        if period == .week {
            let previousRange = interval(.week, containing: shift(anchor, .week, by: -1))
            let previous = impacts.filter { contains(previousRange, $0.time) }
            if !previous.isEmpty && !inRange.isEmpty {
                result.trend = round1(result.avgImpact - average(previous))
            }
        }

        return result
    }

    /// Per-space totals. Sorted by average impact, highest first.
    static func spaceInsights(spaces: [Space], entries: [SpaceEntry], includeEmpty: Bool) -> [SpaceInsight] {
        var groups: [PersistentIdentifier: [SpaceEntry]] = [:]
        for entry in entries {
            guard let space = entry.space else { continue }
            groups[space.persistentModelID, default: []].append(entry)
        }

        return spaces.compactMap { space -> SpaceInsight? in
            let items = groups[space.persistentModelID] ?? []
            if items.isEmpty && !includeEmpty { return nil }
            let reflective = items.filter { $0.kind != .watchLater }
            let impacts = items.filter { $0.kind == .impact }
            return SpaceInsight(
                space: space,
                totalItems: reflective.count,
                impactCount: impacts.count,
                noteCount: items.filter { $0.kind == .note }.count,
                watchLaterCount: items.filter { $0.kind == .watchLater }.count,
                avgImpact: average(impacts),
                highest: impacts.max { $0.signedImpact < $1.signedImpact },
                lastEntryAt: reflective.map(\.time).max()
            )
        }
        .sorted { $0.avgImpact > $1.avgImpact }
    }

    /// Consecutive days with at least one entry, ending today (or yesterday).
    static func streak(_ entries: [SpaceEntry], now: Date) -> Int {
        let days = Set(entries.map { calendar.startOfDay(for: $0.time) })
        guard !days.isEmpty else { return 0 }

        var cursor = calendar.startOfDay(for: now)
        if !days.contains(cursor) {
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        var count = 0
        while days.contains(cursor) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }

    static func average(_ entries: [SpaceEntry]) -> Double {
        guard !entries.isEmpty else { return 0 }
        let sum = entries.reduce(0) { $0 + $1.signedImpact }
        return round1(Double(sum) / Double(entries.count))
    }

    static func round1(_ value: Double) -> Double {
        (value * 10).rounded() / 10
    }

    /// Week view: the selected week and the 7 before it. Month and year: every week they touch.
    private static func weekStarts(for period: InsightPeriod, range: DateInterval) -> [Date] {
        switch period {
        case .week:
            return (0..<8).reversed().compactMap {
                calendar.date(byAdding: .weekOfYear, value: -$0, to: range.start)
            }
        case .month, .year:
            var starts: [Date] = []
            var cursor = interval(.week, containing: range.start).start
            while cursor < range.end {
                starts.append(cursor)
                guard let next = calendar.date(byAdding: .weekOfYear, value: 1, to: cursor) else { break }
                cursor = next
            }
            return starts
        }
    }
}
