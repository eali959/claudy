import SwiftUI

// MARK: - ReactionLogView
// Easter egg: long-press Claud-y for 3 seconds to reveal today's ambient reaction log.
// In-memory only; cleared on quit. No mention in docs - a hidden delight for curious devs.

struct ReactionLogView: View {
    let entries: [(Date, String)]
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.2)
            content
        }
        .frame(width: 280, height: 300)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.22), radius: 18, y: 6)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Today's Reactions")
                .font(.system(size: 12, weight: .semibold))
            Spacer()
            Text("\(entries.count)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)
            Button { onDismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if entries.isEmpty {
            VStack(spacing: 6) {
                Image(systemName: "bubble.left")
                    .font(.system(size: 22))
                    .foregroundStyle(.tertiary)
                Text("No reactions yet today.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(entries.reversed().enumerated()), id: \.offset) { offset, entry in
                        HStack(alignment: .top, spacing: 8) {
                            Text(timeString(from: entry.0))
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.tertiary)
                                .frame(width: 36, alignment: .leading)

                            Text(entry.1)
                                .font(.system(size: 11))
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)

                        // Bug fix: use index position, not text content, to find the last item.
                        // Text-based comparison breaks when two different reactions share the same string.
                        if offset < entries.count - 1 {
                            Divider().opacity(0.08).padding(.leading, 56)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Helpers

    private func timeString(from date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}
