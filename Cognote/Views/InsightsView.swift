import SwiftUI
import SwiftData
import Charts

struct InsightsView: View {
    @Query(sort: \Space.name) private var spaces: [Space]
    @Query(sort: \SpaceEntry.time) private var entries: [SpaceEntry]

    @State private var period: InsightPeriod = .week
    @State private var anchor = Date()

    var body: some View {
        let insights = InsightsCalculator.build(spaces: spaces, entries: entries, period: period, anchor: anchor)
        let range = InsightsCalculator.interval(period, containing: anchor)

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(L("insights.description"))
                    .font(.subheadline)
                    .foregroundStyle(Palette.ink2)

                Picker(L("insights.eyebrow"), selection: $period) {
                    ForEach(InsightPeriod.allCases) { item in
                        Text(L(item.labelKey)).tag(item)
                    }
                }
                .pickerStyle(.segmented)

                navigator(range: range)

                if insights.isEmpty && insights.watchLaterCompleted == 0 {
                    Card {
                        Text(L("insights.empty"))
                            .font(.subheadline)
                            .foregroundStyle(Palette.ink2)
                    }
                } else {
                    stats(insights)
                    highlights(insights)
                    topEntry(insights)
                    weeklyChart(insights)
                    bySpace(insights)
                }
            }
            .padding(20)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.bg.ignoresSafeArea())
        .navigationTitle(L("insights.title"))
        .onChange(of: period) { anchor = Date() }
    }

    // MARK: - Navigator

    private func navigator(range: DateInterval) -> some View {
        let isCurrent = InsightsCalculator.contains(range, Date())
        let isOldest = entries.first.map { range.start <= $0.time } ?? true

        return HStack {
            Button {
                anchor = InsightsCalculator.shift(anchor, period, by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(isOldest)
            .accessibilityLabel(L("insights.previous"))

            Spacer()
            VStack(spacing: 2) {
                if isCurrent {
                    Text(L(period.currentKey))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Palette.accent)
                }
                Text(rangeLabel(range))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Palette.ink)
            }
            Spacer()

            if !isCurrent {
                Button(L(period.currentKey)) { anchor = Date() }
                    .font(.caption)
            }
            Button {
                anchor = InsightsCalculator.shift(anchor, period, by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(isCurrent)
            .accessibilityLabel(L("insights.next"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.surface))
    }

    private func rangeLabel(_ range: DateInterval) -> String {
        switch period {
        case .week:
            let last = range.end.addingTimeInterval(-1)
            return Fmt.shortDate(range.start) + " – " + Fmt.shortDate(last)
        case .month:
            return range.start.formatted(.dateTime.month(.wide).year())
        case .year:
            return range.start.formatted(.dateTime.year())
        }
    }

    // MARK: - Sections

    private func stats(_ insights: Insights) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            StatCard(label: L("insights.avgImpact")) {
                Text(Fmt.signed(insights.avgImpact))
                    .font(.serif(.title, weight: .semibold))
                    .foregroundStyle(insights.avgImpact < 0 ? Palette.neg : Palette.accent)
                Text(L("insights.outOf"))
                    .font(.caption)
                    .foregroundStyle(Palette.ink3)
                if let trend = insights.trend {
                    Text(verbatim: (trend > 0 ? "↑ " : trend < 0 ? "↓ " : "→ ") + Fmt.signed(trend) + " " + L("insights.vsLastWeek"))
                        .font(.caption)
                        .foregroundStyle(trend < 0 ? Palette.neg : Palette.accent)
                }
            }

            StatCard(label: L("insights.sentimentSplit")) {
                HStack(spacing: 4) {
                    Text(verbatim: "+\(insights.positiveCount)").foregroundStyle(Palette.accent)
                    Text(verbatim: "/").foregroundStyle(Palette.ink3)
                    Text(verbatim: "−\(insights.negativeCount)").foregroundStyle(Palette.neg)
                }
                .font(.serif(.title2, weight: .semibold))
                GeometryReader { proxy in
                    let share = insights.totalItems > 0
                        ? Double(insights.positiveCount) / Double(insights.totalItems)
                        : 0.5
                    ZStack(alignment: .leading) {
                        Capsule().fill(Palette.neg.opacity(0.35))
                        Capsule().fill(Palette.accent).frame(width: proxy.size.width * share)
                    }
                }
                .frame(height: 6)
            }

            StatCard(label: L("insights.totalItems")) {
                Text(verbatim: "\(insights.totalItems)")
                    .font(.serif(.title, weight: .semibold))
                    .foregroundStyle(Palette.ink)
            }

            StatCard(label: L("insights.consistency")) {
                Text(verbatim: "\(insights.activeWeeks)/\(insights.byWeek.count)")
                    .font(.serif(.title, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                Text(L("insights.weeksActive"))
                    .font(.caption)
                    .foregroundStyle(Palette.ink3)
            }

            StatCard(label: L(period.completedKey)) {
                Text(verbatim: "\(insights.watchLaterCompleted)")
                    .font(.serif(.title, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                Text(L("insights.wlCompletedSub"))
                    .font(.caption)
                    .foregroundStyle(Palette.ink3)
            }

            StatCard(label: L("insights.streak")) {
                Text(verbatim: "\(insights.streak)")
                    .font(.serif(.title, weight: .semibold))
                    .foregroundStyle(Palette.ink)
            }
        }
    }

    @ViewBuilder
    private func highlights(_ insights: Insights) -> some View {
        if let best = insights.best, let worst = insights.worst {
            HStack(spacing: 12) {
                highlightCard(L("insights.bestSpace"), best, color: Palette.accent, background: Palette.accentLight)
                highlightCard(L("insights.worstSpace"), worst, color: Palette.neg, background: Palette.negLight)
            }
        }
    }

    private func highlightCard(_ title: String, _ space: SpaceInsight, color: Color, background: Color) -> some View {
        Card(background: background) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(color)
                Text(space.name)
                    .font(.headline)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                HStack {
                    Text(Fmt.signed(space.avgImpact))
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .foregroundStyle(color)
                    Text(verbatim: "\(space.impactCount) \(L("insights.entries"))")
                        .font(.caption)
                        .foregroundStyle(Palette.ink3)
                }
            }
        }
    }

    @ViewBuilder
    private func topEntry(_ insights: Insights) -> some View {
        if let top = insights.highest {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(text: L("insights.topItem"))
                Card {
                    EntryRow(entry: top, showSpace: true)
                }
            }
        }
    }

    private func weeklyChart(_ insights: Insights) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: L("insights.byWeek"))
            Card {
                Chart(insights.byWeek) { bucket in
                    BarMark(
                        x: .value("week", bucket.start, unit: .weekOfYear),
                        y: .value("entries", bucket.count)
                    )
                    .foregroundStyle(bucket.avgImpact < 0 ? Palette.neg : Palette.accent)
                    .cornerRadius(3)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                    }
                }
                .frame(height: 150)
            }
        }
    }

    @ViewBuilder
    private func bySpace(_ insights: Insights) -> some View {
        if !insights.bySpace.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(text: L("insights.bySpace"))
                Card {
                    VStack(spacing: 14) {
                        ForEach(insights.bySpace) { space in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(space.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Palette.ink)
                                    Spacer()
                                    Text(verbatim: "\(space.impactCount) \(L("insights.entries"))")
                                        .font(.caption)
                                        .foregroundStyle(Palette.ink3)
                                    Text(Fmt.signed(space.avgImpact))
                                        .font(.subheadline.weight(.bold).monospacedDigit())
                                        .foregroundStyle(space.avgImpact < 0 ? Palette.neg : Palette.accent)
                                }
                                ImpactBar(value: space.avgImpact)
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct StatCard<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Palette.ink3)
                .lineLimit(2)
            content
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.surface))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Palette.border, lineWidth: 0.5)
        )
    }
}

/// A centred bar from -5 to +5.
private struct ImpactBar: View {
    let value: Double

    var body: some View {
        GeometryReader { proxy in
            let half = proxy.size.width / 2
            let width = half * min(1, abs(value) / 5)
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.surfaceAlt)
                Rectangle()
                    .fill(value < 0 ? Palette.neg : Palette.accent)
                    .frame(width: width)
                    .offset(x: value < 0 ? half - width : half)
                Rectangle()
                    .fill(Palette.border)
                    .frame(width: 1)
                    .offset(x: half)
            }
            .clipShape(Capsule())
        }
        .frame(height: 6)
    }
}
