import SwiftUI
import SwiftData

/// The "Future" virtual space: every watch-later entry across all spaces.
struct FutureView: View {
    @Environment(\.modelContext) private var context
    @Query(
        filter: #Predicate<SpaceEntry> { $0.kindRaw == "watchLater" },
        sort: \SpaceEntry.createdAt,
        order: .reverse
    ) private var items: [SpaceEntry]

    @State private var search = ""
    @State private var sortByName = false
    @State private var editor: EditorTarget?
    @State private var deleting: SpaceEntry?

    private var visible: [SpaceEntry] {
        let query = search.trimmed
        let filtered = query.isEmpty ? items : items.filter {
            $0.name.localizedCaseInsensitiveContains(query) || $0.thought.localizedCaseInsensitiveContains(query)
        }
        guard sortByName else { return filtered }
        return filtered.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        List {
            if !visible.isEmpty {
                Section {
                    ForEach(visible) { entry in
                        Button {
                            editor = .edit(entry, preset: nil)
                        } label: {
                            EntryRow(entry: entry, showSpace: true)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Palette.surface)
                        .swipeActions(edge: .leading) {
                            Button {
                                editor = .edit(entry, preset: .impact)
                            } label: {
                                Label(L("future.recordImpact"), systemImage: "checkmark")
                            }
                            .tint(Palette.accent)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                deleting = entry
                            } label: {
                                Label(L("list.deleteAction"), systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .overlay {
            if items.isEmpty {
                ContentUnavailableView {
                    Label(L("watchLater.title"), systemImage: EntryKind.watchLater.symbol)
                } description: {
                    Text(L("watchLater.description") + "\n\n" + L("watchLater.emptyHint"))
                }
            } else if visible.isEmpty {
                ContentUnavailableView.search(text: search)
            }
        }
        .background(Palette.bg.ignoresSafeArea())
        .navigationTitle(L("watchLater.title"))
        .searchable(text: $search, prompt: L("list.searchPlaceholder"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if items.count > 1 {
                    Picker(L("list.sortLabel"), selection: $sortByName) {
                        Text(L("list.sortDate")).tag(false)
                        Text(L("list.sortName")).tag(true)
                    }
                    .pickerStyle(.menu)
                }
            }
        }
        .sheet(item: $editor) { target in
            if case .edit(let entry, let preset) = target, let space = entry.space {
                EntryFormView(space: space, entry: entry, preset: preset)
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
    }
}
