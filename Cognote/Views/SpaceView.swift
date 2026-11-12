import SwiftUI
import SwiftData

enum EntrySort: String, CaseIterable {
    case date
    case impact
    case name

    var labelKey: String {
        switch self {
        case .date: return "list.sortDate"
        case .impact: return "list.sortImpact"
        case .name: return "list.sortName"
        }
    }
}

/// What the entry sheet is showing.
enum EditorTarget: Identifiable {
    case new(preset: EntryKind?)
    case edit(SpaceEntry, preset: EntryKind?)

    var id: String {
        switch self {
        case .new: return "new"
        case .edit(let entry, _): return entry.id.uuidString
        }
    }
}

struct SpaceView: View {
    @Environment(\.modelContext) private var context
    let space: Space

    @Query(sort: \SpaceEntry.time, order: .reverse) private var allEntries: [SpaceEntry]
    @AppStorage("entrySortField") private var sortRaw = EntrySort.date.rawValue
    @AppStorage("entrySortAscending") private var ascending = false

    @State private var search = ""
    @State private var kindFilter: EntryKind?
    @State private var sentimentFilter: Sentiment?
    @State private var editor: EditorTarget?
    @State private var deleting: SpaceEntry?
    @State private var renaming = false
    @State private var renameDraft = ""

    private var entries: [SpaceEntry] {
        allEntries.filter { $0.space?.persistentModelID == space.persistentModelID }
    }

    private var visibleEntries: [SpaceEntry] {
        let query = search.trimmed
        let filtered = entries.filter { entry in
            if let kindFilter, entry.kind != kindFilter { return false }
            if let sentimentFilter, entry.kind == .impact, entry.sentiment != sentimentFilter { return false }
            if !query.isEmpty {
                return entry.name.localizedCaseInsensitiveContains(query)
                    || entry.thought.localizedCaseInsensitiveContains(query)
            }
            return true
        }
        return sort(filtered)
    }

    var body: some View {
        let all = entries
        let visible = visibleEntries

        List {
            if all.isEmpty {
                emptyGuide
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else if !visible.isEmpty {
                Section {
                    ForEach(visible) { entry in
                        Button {
                            editor = .edit(entry, preset: nil)
                        } label: {
                            EntryRow(entry: entry)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Palette.surface)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                deleting = entry
                            } label: {
                                Label(L("list.deleteAction"), systemImage: "trash")
                            }
                            Button {
                                editor = .edit(entry, preset: nil)
                            } label: {
                                Label(L("list.editAction"), systemImage: "pencil")
                            }
                        }
                        .contextMenu {
                            ShareLink(item: EntryShare.text(for: entry)) {
                                Label(L("list.shareLabel"), systemImage: "square.and.arrow.up")
                            }
                            Button {
                                editor = .edit(entry, preset: nil)
                            } label: {
                                Label(L("list.editAction"), systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                deleting = entry
                            } label: {
                                Label(L("list.deleteAction"), systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text(L("list.itemsTitle"))
                        Spacer()
                        Text(verbatim: visible.count == all.count ? "\(all.count)" : "\(visible.count)/\(all.count)")
                            .monospacedDigit()
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .overlay {
            if !all.isEmpty && visible.isEmpty {
                ContentUnavailableView.search(text: search)
            }
        }
        .background(Palette.bg.ignoresSafeArea())
        .navigationTitle(space.name)
        .searchable(text: $search, prompt: L("list.searchPlaceholder"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    editor = .new(preset: nil)
                } label: {
                    Label(L("list.fabAction"), systemImage: "square.and.pencil")
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            ToolbarItem(placement: .topBarTrailing) { optionsMenu(hasEntries: !all.isEmpty) }
        }
        .sheet(item: $editor) { target in
            switch target {
            case .new(let preset):
                EntryFormView(space: space, preset: preset, showFirstTip: all.isEmpty)
            case .edit(let entry, let preset):
                EntryFormView(space: entry.space ?? space, entry: entry, preset: preset)
            }
        }
        .confirmationDialog(
            L("list.deleteConfirmTitle"),
            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
            titleVisibility: .visible,
            presenting: deleting
        ) { entry in
            Button(L("list.deleteConfirmAction"), role: .destructive) {
                Store.delete(entry, in: context)
            }
            Button(L("list.deleteConfirmCancel"), role: .cancel) {}
        } message: { _ in
            Text(L("list.deleteConfirmMessage"))
        }
        .alert(L("workspace.renameLabel"), isPresented: $renaming) {
            TextField(L("workspace.inputPlaceholder"), text: $renameDraft)
            Button(L("action.cancel"), role: .cancel) {}
            Button(L("action.save")) { Store.rename(space, to: renameDraft) }
        }
    }

    // MARK: - Pieces

    private func optionsMenu(hasEntries: Bool) -> some View {
        Menu {
            if hasEntries {
                Picker(L("list.sortLabel"), selection: sortSelection) {
                    ForEach(EntrySort.allCases, id: \.self) { field in
                        Text(L(field.labelKey)).tag(field)
                    }
                }
                Button {
                    ascending.toggle()
                } label: {
                    Label {
                        Text(verbatim: L("list.sortLabel") + (ascending ? " ↑" : " ↓"))
                    } icon: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                }

                Picker(L("list.filterLabel"), selection: $kindFilter) {
                    Text(L("list.filterAll")).tag(EntryKind?.none)
                    ForEach(EntryKind.allCases, id: \.self) { kind in
                        Label(L(kind.labelKey), systemImage: kind.symbol).tag(EntryKind?.some(kind))
                    }
                }

                if kindFilter == nil || kindFilter == .impact {
                    Picker(L("list.impactLabel"), selection: $sentimentFilter) {
                        Text(L("list.filterAll")).tag(Sentiment?.none)
                        Text(L("list.filterPos")).tag(Sentiment?.some(.positive))
                        Text(L("list.filterNeg")).tag(Sentiment?.some(.negative))
                    }
                }

                Divider()

                ShareLink(
                    item: CSVExport(text: CSVExport.make(entries: entries)),
                    preview: SharePreview(space.name + ".csv")
                ) {
                    Label(L("list.exportCsv"), systemImage: "square.and.arrow.down")
                }
            }

            Button {
                renameDraft = space.name
                renaming = true
            } label: {
                Label(L("workspace.renameLabel"), systemImage: "pencil")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel(L("home.menuLabel"))
    }

    private var emptyGuide: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(L("list.emptyGuideMockName"))
                        .font(.body.weight(.semibold))
                    Spacer()
                    Text(verbatim: "+4")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .foregroundStyle(Palette.accent)
                        .background(Capsule().fill(Palette.accentLight))
                }
                Text(L("list.emptyGuideMockThought"))
                    .font(.subheadline)
                    .foregroundStyle(Palette.ink2)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 16).fill(Palette.sampleEntry))
            .overlay(alignment: .leading) {
                UnevenRoundedRectangle(topLeadingRadius: 16, bottomLeadingRadius: 16)
                    .fill(Palette.accent)
                    .frame(width: 5)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .rotationEffect(.degrees(-1.5))
            .opacity(0.85)
            .accessibilityHidden(true)

            Text(L("list.emptyGuideTitle"))
                .font(.serif(.title2, weight: .semibold))
                .foregroundStyle(Palette.ink)
            Text(L("list.emptyGuideDesc"))
                .font(.subheadline)
                .foregroundStyle(Palette.ink2)

            Button {
                editor = .new(preset: nil)
            } label: {
                Label(L("list.fabAction"), systemImage: "square.and.pencil")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(.vertical, 12)
    }

    private var sortSelection: Binding<EntrySort> {
        Binding(
            get: { EntrySort(rawValue: sortRaw) ?? .date },
            set: { sortRaw = $0.rawValue }
        )
    }

    private func sort(_ items: [SpaceEntry]) -> [SpaceEntry] {
        let field = EntrySort(rawValue: sortRaw) ?? .date
        let sorted = items.sorted { a, b in
            switch field {
            case .date:
                if a.time != b.time { return a.time < b.time }
                return a.createdAt < b.createdAt
            case .impact:
                if a.signedImpact != b.signedImpact { return a.signedImpact < b.signedImpact }
                return a.time < b.time
            case .name:
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }
        }
        return ascending ? sorted : sorted.reversed()
    }
}
