import AppKit
import SwiftUI

struct MarkdownNoteEditor: View {
    private enum Mode: String, CaseIterable, Identifiable {
        case write = "Write"
        case preview = "Preview"

        var id: String { rawValue }
    }

    @Binding var markdown: String
    var minimumHeight: CGFloat = 210

    @State private var mode: Mode = .write
    @State private var selectedRange = NSRange(location: 0, length: 0)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Picker("Note mode", selection: $mode) {
                    ForEach(Mode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 170)

                Spacer()

                Text("\(markdown.count.formatted()) / \(FocusMetadata.maximumNoteLength.formatted())")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(
                        markdown.count > FocusMetadata.maximumNoteLength ? .red : .secondary
                    )
            }

            if mode == .write {
                formattingToolbar
                MarkdownTextView(
                    text: $markdown,
                    selectedRange: $selectedRange
                )
                .frame(minHeight: minimumHeight)
                .overlay {
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(.separator, lineWidth: 1)
                        .allowsHitTesting(false)
                }
            } else {
                preview
                    .frame(minHeight: minimumHeight, alignment: .topLeading)
            }
        }
    }

    private var formattingToolbar: some View {
        HStack(spacing: 3) {
            formatButton("Bold", systemImage: "bold") {
                wrapSelection(prefix: "**", suffix: "**", placeholder: "bold text")
            }
            formatButton("Italic", systemImage: "italic") {
                wrapSelection(prefix: "_", suffix: "_", placeholder: "italic text")
            }
            formatButton("Inline code", systemImage: "chevron.left.forwardslash.chevron.right") {
                wrapSelection(prefix: "`", suffix: "`", placeholder: "code")
            }
            Divider().frame(height: 17).padding(.horizontal, 3)
            formatButton("Bulleted list", systemImage: "list.bullet") {
                prefixSelectedLines(with: "- ")
            }
            formatButton("Checklist", systemImage: "checklist") {
                prefixSelectedLines(with: "- [ ] ")
            }
            formatButton("Link", systemImage: "link") {
                wrapSelection(prefix: "[", suffix: "](https://)", placeholder: "link title")
            }
            Spacer()
            Text("Markdown")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private func formatButton(
        _ help: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .frame(width: 21, height: 21)
        }
        .buttonStyle(.borderless)
        .help(help)
    }

    private var preview: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    ContentUnavailableView(
                        "Nothing to preview",
                        systemImage: "doc.text",
                        description: Text("Write a note, then return here to preview it.")
                    )
                    .frame(maxWidth: .infinity, minHeight: minimumHeight - 24)
                } else {
                    Text(renderedMarkdown)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    FocusLinkList(markdown: markdown)
                }
            }
            .padding(12)
        }
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 7))
        .environment(\.openURL, OpenURLAction { url in
            guard let scheme = url.scheme?.lowercased(),
                  scheme == "https" || scheme == "http" else {
                return .discarded
            }
            return .systemAction(url)
        })
    }

    private var renderedMarkdown: AttributedString {
        (try? AttributedString(
            markdown: markdown,
            options: .init(
                interpretedSyntax: .full,
                failurePolicy: .returnPartiallyParsedIfPossible
            )
        )) ?? AttributedString(markdown)
    }

    private func wrapSelection(prefix: String, suffix: String, placeholder: String) {
        let source = markdown as NSString
        let range = safeSelection(in: source)
        let selected = source.substring(with: range)
        let content = selected.isEmpty ? placeholder : selected
        let replacement = prefix + content + suffix
        markdown = source.replacingCharacters(in: range, with: replacement)
        selectedRange = NSRange(
            location: range.location + prefix.utf16.count,
            length: content.utf16.count
        )
    }

    private func prefixSelectedLines(with prefix: String) {
        let source = markdown as NSString
        let selection = safeSelection(in: source)
        let lineRange = source.lineRange(for: selection)
        let selectedLines = source.substring(with: lineRange)
        let replacement = selectedLines
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { prefix + $0 }
            .joined(separator: "\n")
        markdown = source.replacingCharacters(in: lineRange, with: replacement)
        selectedRange = NSRange(
            location: lineRange.location,
            length: replacement.utf16.count
        )
    }

    private func safeSelection(in source: NSString) -> NSRange {
        guard selectedRange.location <= source.length else {
            return NSRange(location: source.length, length: 0)
        }
        return NSRange(
            location: selectedRange.location,
            length: min(selectedRange.length, source.length - selectedRange.location)
        )
    }
}

struct FocusLinkList: View {
    let markdown: String

    private var links: [URL] {
        FocusMetadata.safeLinks(in: markdown)
    }

    var body: some View {
        if !links.isEmpty {
            VStack(alignment: .leading, spacing: 7) {
                Text("Links")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                ForEach(links, id: \.absoluteString) { url in
                    Link(destination: url) {
                        HStack(spacing: 7) {
                            Image(systemName: linkIcon(for: url))
                            Text(linkTitle(for: url))
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            Image(systemName: "arrow.up.right")
                                .font(.caption2)
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.tint)
                }
            }
        }
    }

    private func linkIcon(for url: URL) -> String {
        FocusMetadata.githubReference(for: url) == nil
            ? "link"
            : "chevron.left.forwardslash.chevron.right"
    }

    private func linkTitle(for url: URL) -> String {
        FocusMetadata.githubReference(for: url)?.compactTitle
            ?? url.host(percentEncoded: false)
            ?? url.absoluteString
    }
}

private struct MarkdownTextView: NSViewRepresentable {
    @Binding var text: String
    @Binding var selectedRange: NSRange

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.allowsUndo = true
        textView.font = .systemFont(ofSize: NSFont.systemFontSize)
        textView.textContainerInset = NSSize(width: 9, height: 9)
        textView.drawsBackground = false
        textView.string = text
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        context.coordinator.parent = self
        if textView.string != text {
            textView.string = text
        }
        let safeLocation = min(selectedRange.location, textView.string.utf16.count)
        let safeLength = min(
            selectedRange.length,
            textView.string.utf16.count - safeLocation
        )
        let safeRange = NSRange(location: safeLocation, length: safeLength)
        if textView.selectedRange() != safeRange {
            textView.setSelectedRange(safeRange)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MarkdownTextView

        init(parent: MarkdownTextView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.selectedRange = textView.selectedRange()
        }
    }
}
