import SwiftUI

/// Horizontal session rail showing active sessions as chips.
struct SessionRailView: View {
    @ObservedObject var sessionStore: RecordingSessionStore
    @ObservedObject var speechManager: SpeechManager
    @ObservedObject var feedbackManager: UserFeedbackManager
    @State private var sessionForRename: RecordingSession?

    var body: some View {
        VStack(spacing: 0) {
            SearchSessionsView(searchQuery: $sessionStore.searchQuery)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.top, DS.Spacing.xs)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.xs) {
                    newSessionButton

                    if sessionStore.sessions.isEmpty {
                        emptyChip(icon: "text.badge.plus", text: "No sessions yet")
                    } else if sessionStore.filteredSessions.isEmpty {
                        emptyChip(icon: "magnifyingglass", text: "No matches")
                    } else {
                        ForEach(sessionStore.filteredSessions) { session in
                            SessionChip(
                                session: session,
                                isActive: session.id == sessionStore.selectedSessionId,
                                onTap: {
                                    sessionStore.selectSession(session.id)
                                    speechManager.transcribedText = session.text
                                },
                                onDelete: {
                                    sessionStore.deleteSession(session.id)
                                    feedbackManager.showSessionDeleted()
                                },
                                onTogglePin: {
                                    sessionStore.togglePin(session.id)
                                },
                                onExport: { sess, format in
                                    if let url = SessionExporter.shared.exportAndSave(
                                        session: sess, format: format
                                    ) {
                                        feedbackManager.showSuccess(
                                            "Exported to \(url.lastPathComponent)"
                                        )
                                    }
                                },
                                onRename: {
                                    sessionForRename = session
                                }
                            )
                        }
                    }
                }
                .padding(.vertical, DS.Spacing.sm)
                .padding(.horizontal, DS.Spacing.md)
            }
        }
        .background(DS.Colors.surfaceGrouped)
        .sheet(item: $sessionForRename) { session in
            RenameSessionSheet(session: session) { newName in
                sessionStore.renameSession(session.id, newName: newName)
            }
        }
    }

    // MARK: - Subviews

    private var newSessionButton: some View {
        Button {
            _ = sessionStore.createNewSession()
            speechManager.transcribedText = ""
            feedbackManager.showNewSession()
        } label: {
            HStack(spacing: DS.Spacing.xxs) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: DS.IconSize.sm))
                Text("New")
                    .font(DS.Typography.caption)
            }
            .foregroundColor(.accentColor)
        }
        .buttonStyle(.bordered)
        .help("New Session")
    }

    private func emptyChip(icon: String, text: String) -> some View {
        HStack(spacing: DS.Spacing.xxs) {
            Image(systemName: icon)
                .font(.system(size: DS.IconSize.inline))
            Text(text)
                .font(DS.Typography.caption)
        }
        .foregroundColor(DS.Colors.textTertiary)
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xxs)
        .frame(height: 28)
        .background(DS.Colors.surfaceSecondary)
        .cornerRadius(DS.Radius.sm)
    }
}

/// Individual session chip.
struct SessionChip: View {
    let session: RecordingSession
    let isActive: Bool
    let onTap: () -> Void
    let onDelete: () -> Void
    let onTogglePin: () -> Void
    let onExport: (RecordingSession, ExportFormat) -> Void
    let onRename: () -> Void

    var body: some View {
        HStack(spacing: DS.Spacing.xxs) {
            Circle()
                .fill(isActive ? Color.accentColor : .clear)
                .frame(width: 6, height: 6)

            if let pinIcon = session.pinIcon {
                Text(pinIcon)
                    .font(.system(size: DS.IconSize.inline))
            }

            Text(session.displayTitle)
                .font(DS.Typography.caption)
                .lineLimit(1)
                .frame(maxWidth: 120, alignment: .leading)

            Text("\(session.wordCount)w")
                .font(DS.Typography.caption2)
                .foregroundColor(DS.Colors.textTertiary)

            Button { onDelete() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: DS.IconSize.inline))
                    .foregroundColor(DS.Colors.textTertiary)
            }
            .buttonStyle(.plain)
            .help("Delete session")
        }
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xxs)
        .frame(height: 28)
        .background(isActive ? Color.accentColor.opacity(0.12) : DS.Colors.surfaceSecondary)
        .cornerRadius(DS.Radius.sm)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .contextMenu {
            Button {
                onTogglePin()
            } label: {
                Label(
                    session.isPinned ? "Unpin" : "Pin Session",
                    systemImage: session.isPinned ? "pin.slash" : "pin"
                )
            }
            Divider()
            Button { onRename() } label: {
                Label("Rename", systemImage: "pencil")
            }
            Divider()
            Menu("Export…") {
                Button("Export as TXT") { onExport(session, .txt) }
                Button("Export as Markdown") { onExport(session, .markdown) }
            }
        }
    }
}
