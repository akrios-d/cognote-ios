import SwiftUI
import SwiftData
import Charts
import UniformTypeIdentifiers

/// What the detail column shows. On iPhone the split view collapses into a stack.
enum Destination: Hashable {
    case future
    case insights
    case space(Space)
}

private enum SpaceSort: String {
    case alpha
    case recent
}

private let quickStartKeys = [
    "workspace.quickFilms",
    "workspace.quickBooks",
    "workspace.quickDocs",
    "workspace.quickSeries",
]

/// Root screen: a sidebar (overview on iPhone, Future, Insights, spaces) and a detail column.
struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Query(sort: \Space.name) private var spaces: [Space]
    @Query(sort: \SpaceEntry.time, order: .reverse) private var entries: [SpaceEntry]
    @AppStorage("spaceSort") private var sortRaw = SpaceSort.alpha.rawValue
    @AppStorage("hasOnboarded") private var hasOnboarded = true
    @AppStorage(AppTheme.storageKey) private var themeRaw = AppTheme.auto.rawValue

    @State private var selection: Destination?
    @State private var creating = false
    @State private var newName = ""
    @State private var renaming: Space?
    @State private var renameDraft = ""
    @State private var deleting: Space?
    @State private var importing = false
    @State private var exportDocument: BackupDocument?
    @State private var pendingImport: URL?
    @State private var confirmingUndo = false
    @State private var importMessage: String?

    var body: some View {
        NavigationSplitView {
            sidebar
                // Kept off the view that has .fileImporter: two file panels on one view conflict.
                .fileExporter(
                    isPresented: Binding(get: { exportDocument != nil }, set: { if !$0 { exportDocument = nil } }),
                    document: exportDocument,
                    contentType: .cognoteBackup,
                    defaultFilename: (BackupFile.fileName as NSString).deletingPathExtension
                ) { result in
                    if case .success = result { importMessage = L("backup.exportDone") }
                }
        } detail: {
            NavigationStack {
                detail
            }
        }
        .navigationSplitViewStyle(.balanced)
        .alert(L("workspace.createAction"), isPresented: $creating) {
            TextField(L("workspace.inputPlaceholder"), text: $newName)
            Button(L("action.cancel"), role: .cancel) { newName = "" }
            Button(L("workspace.createAction")) {
                if let space = Store.createSpace(named: newName, in: context) {
                    selection = .space(space)
                }
                newName = ""
            }
        } message: {
            Text(L("workspace.nameHelper"))
        }
        .alert(L("workspace.renameLabel"), isPresented: renamingBinding) {
            TextField(L("workspace.inputPlaceholder"), text: $renameDraft)
            Button(L("action.cancel"), role: .cancel) {}
            Button(L("action.save")) {
                if let renaming { Store.rename(renaming, to: renameDraft) }
            }
        }
        .confirmationDialog(
            L("workspace.deleteConfirmTitle"),
            isPresented: deletingBinding,
            titleVisibility: .visible,
            presenting: deleting
        ) { space in
            Button(L("workspace.deleteConfirmAction"), role: .destructive) {
                if selection == .space(space) { selection = nil }
                Store.delete(space, in: context)
            }
            Button(L("workspace.deleteConfirmCancel"), role: .cancel) {}
        } message: { _ in
            Text(L("workspace.deleteConfirmMessage"))
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.cognoteBackup, .json]) { result in
            switch result {
            case .success(let url):
                // Let the file picker finish dismissing before asking how to import.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { pendingImport = url }
            case .failure: importMessage = L("backup.importFailed")
            }
        }
        .onOpenURL { url in
            // A .cognote file opened from Files, AirDrop or Mail.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { pendingImport = url }
        }
        .confirmationDialog(
            L("backup.modeTitle"),
            isPresented: Binding(get: { pendingImport != nil }, set: { if !$0 { pendingImport = nil } }),
            titleVisibility: .visible,
            presenting: pendingImport
        ) { url in
            Button(L("backup.merge")) { runImport(url, mode: .merge) }
            Button(L("backup.replace"), role: .destructive) { runImport(url, mode: .replace) }
            Button(L("action.cancel"), role: .cancel) {}
        } message: { _ in
            Text(L("backup.modeMessage"))
        }
        .confirmationDialog(
            L("backup.undoConfirmTitle"),
            isPresented: $confirmingUndo,
            titleVisibility: .visible
        ) {
            Button(L("backup.restore"), role: .destructive) { undoReplace() }
            Button(L("action.cancel"), role: .cancel) {}
        } message: {
            Text(L("backup.undoConfirmMessage"))
        }
        .alert(
            importMessage ?? "",
            isPresented: Binding(get: { importMessage != nil }, set: { if !$0 { importMessage = nil } })
        ) {
            Button(L("action.ok")) {}
        }
    }

    private func runImport(_ url: URL, mode: ImportMode) {
        selection = nil
        do {
            let summary = try BackupImporter.importFile(at: url, mode: mode, into: context)
            let counts = "\(summary.spaces) \(L("home.spacesLabel").lowercased()) · "
                + "\(summary.entries) \(L("home.itemPlural"))"
            let title = mode == .replace ? L("backup.replaceDone") : L("backup.importDone")
            importMessage = title + "\n" + counts
        } catch {
            importMessage = L("backup.importFailed")
        }
    }

    private func undoReplace() {
        selection = nil
        do {
            _ = try BackupImporter.undoLastReplace(into: context)
            importMessage = L("backup.restoreDone")
        } catch {
            importMessage = L("backup.importFailed")
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        let allTime = InsightsCalculator.spaceInsights(spaces: spaces, entries: entries, includeEmpty: true)

        return List(selection: $selection) {
            if sizeClass == .compact {
                Text(L("home.title"))
                    .font(.serif(.title3))
                    .foregroundStyle(Palette.ink2)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 4, trailing: 20))

                OverviewSections(spaces: spaces, entries: entries) { selection = $0 }
            }

            Section {
                NavigationLink(value: Destination.future) {
                    sidebarLabel(L("watchLater.title"), symbol: EntryKind.watchLater.symbol, count: futureCount)
                }
                NavigationLink(value: Destination.insights) {
                    sidebarLabel(L("insights.title"), symbol: "chart.bar.xaxis", count: nil)
                }
            }
            .listRowBackground(rowBackground)

            Section {
                if spaces.isEmpty {
                    emptySpaces
                } else {
                    ForEach(sortedInsights(allTime)) { insight in
                        NavigationLink(value: Destination.space(insight.space)) {
                            SpaceRow(insight: insight)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                deleting = insight.space
                            } label: {
                                Label(L("workspace.deleteAction"), systemImage: "trash")
                            }
                            Button {
                                startRename(insight.space)
                            } label: {
                                Label(L("workspace.renameLabel"), systemImage: "pencil")
                            }
                        }
                        .contextMenu {
                            Button {
                                startRename(insight.space)
                            } label: {
                                Label(L("workspace.renameLabel"), systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                deleting = insight.space
                            } label: {
                                Label(L("workspace.deleteAction"), systemImage: "trash")
                            }
                        }
                    }
                    if spaces.count < 4 && !remainingChips.isEmpty {
                        chips
                    }
                }
            } header: {
                Text(L("home.spacesLabel"))
            }
            .listRowBackground(rowBackground)
        }
        .scrollContentBackground(.hidden)
        .background(Palette.bg.ignoresSafeArea())
        .navigationTitle(greeting)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    creating = true
                } label: {
                    Label(L("workspace.createAction"), systemImage: "folder.badge.plus")
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }
            ToolbarItem(placement: .topBarTrailing) {
                moreMenu
            }
        }
    }

    private var moreMenu: some View {
        Menu {
            Picker(selection: $sortRaw) {
                Text(L("workspace.sortAlpha")).tag(SpaceSort.alpha.rawValue)
                Text(L("workspace.sortRecent")).tag(SpaceSort.recent.rawValue)
            } label: {
                Label(L("workspace.sortLabel"), systemImage: "arrow.up.arrow.down")
            }
            .pickerStyle(.menu)

            Picker(selection: $themeRaw) {
                ForEach(AppTheme.allCases) { theme in
                    Text(L(theme.labelKey)).tag(theme.rawValue)
                }
            } label: {
                Label(L("theme.label"), systemImage: "paintpalette")
            }
            .pickerStyle(.menu)

            Divider()

            Button {
                exportDocument = BackupDocument(data: BackupFile.make(context: context).data)
            } label: {
                Label(L("backup.export"), systemImage: "arrow.down.doc")
            }
            ShareLink(
                item: BackupFile.make(context: context),
                preview: SharePreview(BackupFile.fileName)
            ) {
                Label(L("backup.share"), systemImage: "square.and.arrow.up")
            }
            Button {
                importing = true
            } label: {
                Label(L("backup.import"), systemImage: "square.and.arrow.down")
            }
            if SafetyBackups.latest() != nil {
                Button {
                    confirmingUndo = true
                } label: {
                    Label(L("backup.undoReplace"), systemImage: "arrow.uturn.backward")
                }
            }

            Divider()

            Button {
                hasOnboarded = false
            } label: {
                Label(L("onboarding.replayLabel"), systemImage: "sparkles")
            }
        } label: {
            Label(L("home.menuLabel"), systemImage: "ellipsis.circle")
        }
    }

    private func sidebarLabel(_ title: String, symbol: String, count: Int?) -> some View {
        SidebarLabel(title: title, symbol: symbol, count: count)
    }

    private var emptySpaces: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("workspace.emptyTitle"))
                .font(.serif(.title3))
                .foregroundStyle(Palette.ink)
            Text(L("workspace.emptyDesc"))
                .font(.subheadline)
                .foregroundStyle(Palette.ink2)
            Button {
                creating = true
            } label: {
                Text(L("workspace.emptyCta"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Text(L("workspace.emptyOr"))
                .font(.caption)
                .foregroundStyle(Palette.ink3)
            chipButtons
        }
        .padding(.vertical, 8)
    }

    private var chips: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("workspace.emptyOr"))
                .font(.caption)
                .foregroundStyle(Palette.ink3)
            chipButtons
        }
        .padding(.vertical, 4)
    }

    private var chipButtons: some View {
        FlowLayout(spacing: 8) {
            ForEach(remainingChips, id: \.self) { chip in
                Button(chip) {
                    Store.createSpace(named: chip, in: context)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .controlSize(.small)
                .tint(Palette.ink2)
            }
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .space(let space):
            SpaceView(space: space)
                .id(space.persistentModelID)
        case .future:
            FutureView()
        case .insights:
            InsightsView()
        case nil:
            if sizeClass == .compact {
                EmptyView()
            } else {
                OverviewView(spaces: spaces, entries: entries) { selection = $0 }
            }
        }
    }

    // MARK: - Helpers

    /// iPhone: themed card rows. iPad/Mac sidebar: system rows, so the selection highlight shows.
    private var rowBackground: Color? {
        sizeClass == .compact ? Palette.surface : nil
    }

    private var futureCount: Int {
        entries.filter { $0.kind == .watchLater }.count
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return L("home.greeting.morning") }
        if hour < 18 { return L("home.greeting.afternoon") }
        return L("home.greeting.evening")
    }

    /// Quick-start chips whose emoji is not already used by a space name.
    private var remainingChips: [String] {
        quickStartKeys.map(L).filter { chip in
            guard let emoji = chip.first else { return true }
            return !spaces.contains { $0.name.first == emoji }
        }
    }

    private func sortedInsights(_ insights: [SpaceInsight]) -> [SpaceInsight] {
        switch SpaceSort(rawValue: sortRaw) ?? .alpha {
        case .alpha:
            return insights.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .recent:
            return insights.sorted {
                ($0.lastEntryAt ?? $0.space.createdAt) > ($1.lastEntryAt ?? $1.space.createdAt)
            }
        }
    }

    private func startRename(_ space: Space) {
        renameDraft = space.name
        renaming = space
    }

    private var renamingBinding: Binding<Bool> {
        Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })
    }

    private var deletingBinding: Binding<Bool> {
        Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })
    }
}

// MARK: - Sidebar rows

private struct SidebarLabel: View {
    let title: String
    let symbol: String
    let count: Int?
    @Environment(\.backgroundProminence) private var prominence

    var body: some View {
        let selected = prominence == .increased
        HStack {
            Label {
                Text(title)
            } icon: {
                Image(systemName: symbol)
                    .foregroundStyle(selected ? AnyShapeStyle(.primary) : AnyShapeStyle(Palette.accent))
            }
            Spacer()
            if let count, count > 0 {
                Text(verbatim: "\(count)")
                    .foregroundStyle(selected ? AnyShapeStyle(.secondary) : AnyShapeStyle(Palette.ink3))
                    .monospacedDigit()
            }
        }
    }
}

// MARK: - Space row

private struct SpaceRow: View {
    let insight: SpaceInsight
    /// `.increased` when the row is selected in the iPad/Mac sidebar.
    @Environment(\.backgroundProminence) private var prominence

    private var selected: Bool { prominence == .increased }

    var body: some View {
        let hasImpact = insight.impactCount > 0
        HStack(spacing: 12) {
            Capsule()
                .fill(selected ? AnyShapeStyle(Color.white.opacity(0.8)) : AnyShapeStyle(Palette.spaceBar(avg: insight.avgImpact, hasImpact: hasImpact)))
                .frame(width: 4, height: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(insight.name)
                    .foregroundStyle(selected ? AnyShapeStyle(.primary) : AnyShapeStyle(Palette.ink))
                meta
            }
            Spacer(minLength: 8)
            if hasImpact {
                Text(Fmt.magnitude(insight.avgImpact))
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(selected ? AnyShapeStyle(.primary) : AnyShapeStyle(insight.avgImpact < 0 ? Palette.negText : Palette.accent))
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var meta: some View {
        if insight.totalItems == 0 && insight.watchLaterCount == 0 {
            Text(L("home.spaceEmpty"))
                .font(.caption)
                .foregroundStyle(selected ? AnyShapeStyle(.secondary) : AnyShapeStyle(Palette.ink3))
        } else {
            HStack(spacing: 10) {
                if insight.impactCount > 0 { count(EntryKind.impact.symbol, insight.impactCount) }
                if insight.noteCount > 0 { count(EntryKind.note.symbol, insight.noteCount) }
                if insight.watchLaterCount > 0 { count(EntryKind.watchLater.symbol, insight.watchLaterCount) }
            }
            .font(.caption)
            .foregroundStyle(selected ? AnyShapeStyle(.secondary) : AnyShapeStyle(Palette.ink3))
        }
    }

    private func count(_ symbol: String, _ value: Int) -> some View {
        HStack(spacing: 3) {
            Image(systemName: symbol)
            Text(verbatim: "\(value)")
        }
    }
}

// MARK: - Overview

/// Highlights shown at the top of the sidebar on iPhone and as the empty detail on iPad and Mac.
struct OverviewSections: View {
    let spaces: [Space]
    let entries: [SpaceEntry]
    let open: (Destination) -> Void

    var body: some View {
        let week = InsightsCalculator.build(spaces: spaces, entries: entries, period: .week, anchor: Date())
        let allTime = InsightsCalculator.spaceInsights(spaces: spaces, entries: entries, includeEmpty: true)

        if let last = entries.first(where: { $0.kind != .watchLater }), let space = last.space {
            Section {
                Button {
                    open(.space(space))
                } label: {
                    EntryRow(entry: last, showSpace: true)
                }
                .buttonStyle(.plain)
            } header: {
                Text(L("home.lastEntryLabel"))
            }
            .listRowBackground(Palette.surface)
        }

        if !week.isEmpty {
            Section {
                patternRow(week)
                if let top = week.highest, let space = top.space {
                    Button {
                        open(.space(space))
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L("home.topItemLabel"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Palette.ink3)
                            EntryRow(entry: top, showSpace: true)
                        }
                    }
                    .buttonStyle(.plain)
                }
                ahaRow(allTime)
            } header: {
                Text(L("home.insightsLabel"))
            }
            .listRowBackground(Palette.surface)
        }
    }

    private func patternRow(_ week: Insights) -> some View {
        let active = week.byWeek.filter { $0.count > 0 }
        return HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(L("home.avgImpactPrefix"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.ink3)
                Text(Fmt.magnitude(week.avgImpact))
                    .font(.serif(.largeTitle, weight: .semibold))
                    .foregroundStyle(week.avgImpact < 0 ? Palette.neg : Palette.accent)
                Text(patternText(week.avgImpact))
                    .font(.subheadline)
                    .foregroundStyle(Palette.ink2)
            }
            Spacer(minLength: 0)
            if active.count >= 2 {
                Chart(active) { bucket in
                    LineMark(x: .value("week", bucket.start), y: .value("impact", bucket.avgImpact))
                        .foregroundStyle(Palette.accent)
                        .interpolationMethod(.monotone)
                    PointMark(x: .value("week", bucket.start), y: .value("impact", bucket.avgImpact))
                        .foregroundStyle(Palette.accent)
                        .symbolSize(18)
                }
                .chartYScale(domain: -5...5)
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(width: 110, height: 50)
                .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func ahaRow(_ allTime: [SpaceInsight]) -> some View {
        let impactTotal = entries.filter { $0.kind == .impact }.count
        let candidates = allTime.filter { $0.impactCount >= 2 }
        if impactTotal >= 3, candidates.count >= 2,
           let top = candidates.max(by: { abs($0.avgImpact) < abs($1.avgImpact) }) {
            Button {
                open(.space(top.space))
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        (Text(top.name).bold() + Text(" " + L("insights.ahaSpace")))
                            .foregroundStyle(Palette.ink)
                        Text(verbatim: "\(impactTotal) \(L("insights.ahaTotal")) \(spaces.count) \(L("insights.ahaSpaces"))")
                            .font(.caption)
                            .foregroundStyle(Palette.ink3)
                    }
                } icon: {
                    Image(systemName: "sparkle")
                        .foregroundStyle(Palette.accent)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func patternText(_ avg: Double) -> String {
        if avg > 3 { return L("home.pattern.veryHigh") }
        if avg > 0 { return L("home.pattern.high") }
        if avg >= -2 { return L("home.pattern.medium") }
        return L("home.pattern.low")
    }
}

/// The empty detail column on iPad and Mac.
private struct OverviewView: View {
    let spaces: [Space]
    let entries: [SpaceEntry]
    let open: (Destination) -> Void

    var body: some View {
        Group {
            if entries.contains(where: { $0.kind != .watchLater }) {
                List {
                    OverviewSections(spaces: spaces, entries: entries, open: open)
                }
                .scrollContentBackground(.hidden)
            } else {
                ContentUnavailableView {
                    Label(L("home.title"), systemImage: "sparkles")
                } description: {
                    Text(L("workspace.emptyDesc"))
                }
            }
        }
        .background(Palette.bg.ignoresSafeArea())
        .navigationTitle(L("home.title"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
