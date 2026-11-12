import SwiftUI
import SwiftData

private let promptKeys = ["list.prompt1", "list.prompt2", "list.prompt3", "list.prompt4", "list.prompt5"]

struct EntryFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let space: Space
    let entry: SpaceEntry?
    let showFirstTip: Bool

    @State private var draft: EntryDraft
    @State private var promptKey = promptKeys.randomElement() ?? "list.prompt1"
    @FocusState private var nameFocused: Bool

    init(space: Space, entry: SpaceEntry? = nil, preset: EntryKind? = nil, showFirstTip: Bool = false) {
        self.space = space
        self.entry = entry
        self.showFirstTip = showFirstTip
        var initial = entry.map(EntryDraft.init(entry:)) ?? EntryDraft()
        if let preset { initial.kind = preset }
        _draft = State(initialValue: initial)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(L("list.modeLabel"), selection: $draft.kind) {
                        ForEach(EntryKind.allCases, id: \.self) { kind in
                            Text(L(kind.labelKey)).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())

                    if showFirstTip && entry == nil {
                        Text(L("list.formFirstTip"))
                            .font(.footnote)
                            .foregroundStyle(Palette.ink3)
                            .listRowBackground(Color.clear)
                    }
                }

                switch draft.kind {
                case .impact: impactFields
                case .watchLater: watchLaterFields
                case .note: noteFields
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.bg)
            .navigationTitle(L(entry == nil ? "list.formTitle" : "list.formTitleEdit"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("list.cancelAction")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L(entry == nil ? "list.addAction" : "list.saveEditAction")) {
                        Store.save(draft, to: entry, in: space, context: context)
                        dismiss()
                    }
                    .bold()
                    .disabled(!draft.isValid)
                }
            }
            .onAppear {
                if entry == nil && draft.kind != .note { nameFocused = true }
            }
        }
    }

    // MARK: - Modes

    private var impactFields: some View {
        Group {
            Section {
                TextField(L("list.namePlaceholder"), text: $draft.name)
                    .focused($nameFocused)
                DatePicker(L("list.timeLabel"), selection: $draft.time, displayedComponents: .date)
            }

            Section {
                TextField(L("list.thoughtPlaceholder"), text: $draft.thought, axis: .vertical)
                    .lineLimit(2...5)
            } footer: {
                if draft.thought.isEmpty {
                    Text(L("list.promptHint") + " " + L(promptKey))
                }
            }

            Section {
                Picker(L("list.impactLabel"), selection: $draft.sentiment) {
                    Text("− " + L("list.sentimentNegative")).tag(Sentiment.negative)
                    Text("+ " + L("list.sentimentPositive")).tag(Sentiment.positive)
                }
                .pickerStyle(.segmented)

                HStack {
                    Text(L("list.intensityLabel"))
                        .foregroundStyle(Palette.ink2)
                    Spacer()
                    ImpactDots(value: $draft.impact, sentiment: draft.sentiment)
                }
                .padding(.vertical, 4)
            } header: {
                Text(L("list.impactLabel"))
            } footer: {
                Text(L("list.impactHelper"))
            }
        }
        .listRowBackground(Palette.surface)
    }

    private var watchLaterFields: some View {
        Section {
            TextField(L("list.namePlaceholderWatchLater"), text: $draft.name)
                .focused($nameFocused)
            TextField(L("list.notePlaceholder"), text: $draft.thought, axis: .vertical)
                .lineLimit(2...5)
        }
        .listRowBackground(Palette.surface)
    }

    private var noteFields: some View {
        Section {
            DatePicker(L("list.timeLabel"), selection: $draft.time, displayedComponents: .date)
            TextField(L("list.notePlaceholderLong"), text: $draft.thought, axis: .vertical)
                .lineLimit(6...16)
                .onChange(of: draft.thought) { _, newValue in
                    if newValue.count > Store.maxNoteLength {
                        draft.thought = String(newValue.prefix(Store.maxNoteLength))
                    }
                }
        } footer: {
            Text(verbatim: "\(draft.thought.count) / \(Store.maxNoteLength)")
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .listRowBackground(Palette.surface)
    }
}
