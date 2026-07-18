import AppKit
import SwiftUI

@MainActor
final class FocusDetailsCoordinator: ObservableObject {
    @Published private(set) var timerDraftNoteMarkdown = ""
    @Published private(set) var timerDraftTagNames: [String] = []

    private var windowController: NSWindowController?

    func showTimerDraft(using appModel: AppModel) {
        showEditor(
            title: "Focus details",
            saveTitle: "Keep details",
            noteMarkdown: timerDraftNoteMarkdown,
            tagNames: timerDraftTagNames,
            appModel: appModel
        ) { [weak self] note, tags in
            self?.timerDraftNoteMarkdown = note
            self?.timerDraftTagNames = tags
            return true
        }
    }

    func showSession(_ session: FocusSession, using appModel: AppModel) {
        showEditor(
            title: "Edit focus session",
            saveTitle: "Save",
            noteMarkdown: session.noteMarkdown,
            tagNames: session.sortedTags.map(\.name),
            appModel: appModel
        ) { note, tags in
            appModel.updateFocusSession(
                session,
                noteMarkdown: note,
                tagNames: tags
            )
        }
    }

    func clearTimerDraft() {
        timerDraftNoteMarkdown = ""
        timerDraftTagNames = []
    }

    private func showEditor(
        title: String,
        saveTitle: String,
        noteMarkdown: String,
        tagNames: [String],
        appModel: AppModel,
        saveAction: @escaping (String, [String]) -> Bool
    ) {
        closeEditor()

        let content = FocusMetadataEditorView(
            title: title,
            saveTitle: saveTitle,
            noteMarkdown: noteMarkdown,
            tagNames: tagNames,
            saveAction: saveAction,
            dismissAction: { [weak self] in
                self?.closeEditor()
            }
        )
        .environmentObject(appModel)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 650, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.contentViewController = NSHostingController(rootView: content)
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 590, height: 560)
        window.center()

        let controller = NSWindowController(window: window)
        windowController = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func closeEditor() {
        windowController?.close()
        windowController = nil
    }
}
