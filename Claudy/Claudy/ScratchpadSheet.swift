import SwiftUI

/// Full scratchpad notes sheet — presented from character context menu.
struct ScratchpadSheet: View {
    @Binding var isPresented: Bool
    @State private var newNoteText: String = ""
    @State private var editingID: UUID? = nil

    private let manager = ScratchpadManager.shared
    private let orange  = Color(red: 0.784, green: 0.361, blue: 0.220)

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "note.text")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(orange)
                Text("Scratchpad")
                    .font(.system(size: 15, weight: .bold))
                Spacer()
                Button { isPresented = false } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 10)

            Divider()

            // New note input
            HStack(spacing: 8) {
                TextField("Jot something down…", text: $newNoteText, axis: .vertical)
                    .lineLimit(1...3)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                    .onSubmit { commitNewNote() }
                Button {
                    commitNewNote()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(newNoteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .secondary : orange)
                }
                .buttonStyle(.plain)
                .disabled(newNoteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            // Notes list
            if manager.notes.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "note.text")
                        .font(.system(size: 28))
                        .foregroundStyle(.quaternary)
                    Text("No notes yet.\nJot something above.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(manager.notes) { note in
                            NoteRow(note: note, manager: manager)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: 260)
            }
        }
        .frame(width: 300)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func commitNewNote() {
        let text = newNoteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        manager.addNote(text)
        newNoteText = ""
    }
}

// MARK: - NoteRow

struct NoteRow: View {
    let note: ScratchpadNote
    let manager: ScratchpadManager
    @State private var isEditing = false
    @State private var editText: String = ""
    private let orange = Color(red: 0.784, green: 0.361, blue: 0.220)

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if note.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(orange)
                    .padding(.top, 3)
            }

            if isEditing {
                TextField("", text: $editText, axis: .vertical)
                    .lineLimit(1...5)
                    .font(.system(size: 12))
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { commitEdit() }
            } else {
                Text(note.text)
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onTapGesture(count: 2) {
                        editText = note.text
                        isEditing = true
                    }
            }

            Spacer(minLength: 0)

            Menu {
                Button {
                    manager.togglePin(id: note.id)
                } label: {
                    Label(note.isPinned ? "Unpin" : "Pin", systemImage: note.isPinned ? "pin.slash" : "pin")
                }
                Button {
                    editText = note.text
                    isEditing = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                Divider()
                Button(role: .destructive) {
                    manager.deleteNote(id: note.id)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(4)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(note.isPinned ? orange.opacity(0.06) : Color.clear)
    }

    private func commitEdit() {
        let trimmed = editText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { manager.updateNote(id: note.id, text: trimmed) }
        isEditing = false
    }
}
