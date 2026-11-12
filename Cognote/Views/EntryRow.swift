import SwiftUI

struct EntryRow: View {
    let entry: SpaceEntry
    var showSpace = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                if entry.kind != .note {
                    Text(entry.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Palette.ink)
                }
                if !entry.thought.isEmpty {
                    Text(entry.thought)
                        .font(entry.kind == .note ? Font.body : Font.subheadline)
                        .foregroundStyle(entry.kind == .note ? Palette.ink : Palette.ink2)
                        .lineLimit(entry.kind == .note ? 5 : 2)
                }
                HStack(spacing: 4) {
                    if entry.kind != .impact {
                        Image(systemName: entry.kind.symbol)
                            .accessibilityLabel(L(entry.kind.labelKey))
                    }
                    Text(Fmt.longDate(entry.time))
                    if showSpace, let space = entry.space {
                        Text(verbatim: "·")
                        Text(space.name)
                            .lineLimit(1)
                    }
                }
                .font(.footnote)
                .foregroundStyle(Palette.ink3)
                .padding(.top, 1)
            }
            Spacer(minLength: 8)
            if entry.kind == .impact {
                ImpactBadge(entry: entry)
            }
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

enum EntryShare {
    static func text(for entry: SpaceEntry) -> String {
        var lines = [entry.name]
        if entry.kind == .impact { lines[0] += "  " + Fmt.badge(entry) }
        if !entry.thought.isEmpty { lines.append(entry.thought) }
        lines.append("— " + L("list.shareVia"))
        return lines.joined(separator: "\n")
    }
}
