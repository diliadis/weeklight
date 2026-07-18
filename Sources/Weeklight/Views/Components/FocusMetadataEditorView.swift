import SwiftUI

struct FocusMetadataEditorView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss

    let title: String
    let saveTitle: String
    let saveAction: (String, [String]) -> Bool
    let dismissAction: (() -> Void)?

    @State private var noteMarkdown: String
    @State private var tagNames: [String]

    init(
        title: String,
        saveTitle: String = "Save",
        noteMarkdown: String,
        tagNames: [String],
        saveAction: @escaping (String, [String]) -> Bool,
        dismissAction: (() -> Void)? = nil
    ) {
        self.title = title
        self.saveTitle = saveTitle
        self.saveAction = saveAction
        self.dismissAction = dismissAction
        _noteMarkdown = State(initialValue: noteMarkdown)
        _tagNames = State(initialValue: tagNames)
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 18) {
                Text(title)
                    .font(.title2.bold())

                VStack(alignment: .leading, spacing: 7) {
                    Text("Details")
                        .font(.headline)
                    MarkdownNoteEditor(markdown: $noteMarkdown, minimumHeight: 270)
                }

                VStack(alignment: .leading, spacing: 7) {
                    Text("Tags")
                        .font(.headline)
                    TagEditor(tags: $tagNames, suggestions: appModel.suggestedTagNames)
                }
            }
            .padding(22)

            Divider()

            HStack {
                Button("Cancel", role: .cancel) {
                    close()
                }
                Spacer()
                Button(saveTitle) {
                    if saveAction(noteMarkdown, tagNames) {
                        close()
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(noteMarkdown.count > FocusMetadata.maximumNoteLength)
            }
            .padding(16)
        }
        .frame(
            minWidth: 590,
            idealWidth: 650,
            maxWidth: .infinity,
            minHeight: 560,
            idealHeight: 620,
            maxHeight: .infinity
        )
    }

    private func close() {
        if let dismissAction {
            dismissAction()
        } else {
            dismiss()
        }
    }
}
