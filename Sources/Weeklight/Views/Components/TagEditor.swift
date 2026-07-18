import SwiftUI

struct TagEditor: View {
    @Binding var tags: [String]
    let suggestions: [String]

    @State private var draft = ""
    @State private var validationMessage: String?

    private var availableSuggestions: [String] {
        let selected = Set(tags.map(FocusMetadata.normalizedTag))
        return suggestions.filter {
            !selected.contains(FocusMetadata.normalizedTag($0))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            if !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(tags, id: \.self) { tag in
                            TagPill(name: tag) {
                                tags.removeAll {
                                    FocusMetadata.normalizedTag($0)
                                        == FocusMetadata.normalizedTag(tag)
                                }
                            }
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                TextField("Add a tag", text: $draft)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addDraft)

                Button("Add", action: addDraft)
                    .disabled(FocusMetadata.cleanTag(draft).isEmpty)

                if !availableSuggestions.isEmpty {
                    Menu {
                        ForEach(availableSuggestions.prefix(10), id: \.self) { suggestion in
                            Button("#\(suggestion)") {
                                add(suggestion)
                            }
                        }
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .help("Reuse a recent tag")
                }
            }

            HStack {
                if let validationMessage {
                    Text(validationMessage)
                        .foregroundStyle(.red)
                } else {
                    Text("Use up to \(FocusMetadata.maximumTagCount) tags.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(tags.count)/\(FocusMetadata.maximumTagCount)")
                    .foregroundStyle(.tertiary)
            }
            .font(.caption)
        }
    }

    private func addDraft() {
        add(draft)
    }

    private func add(_ value: String) {
        let cleaned = FocusMetadata.cleanTag(value)
        guard !cleaned.isEmpty else { return }
        guard cleaned.count <= FocusMetadata.maximumTagLength else {
            validationMessage = "Tags can contain up to \(FocusMetadata.maximumTagLength) characters."
            return
        }
        guard tags.count < FocusMetadata.maximumTagCount else {
            validationMessage = "Remove a tag before adding another."
            return
        }
        let normalized = FocusMetadata.normalizedTag(cleaned)
        guard !tags.contains(where: {
            FocusMetadata.normalizedTag($0) == normalized
        }) else {
            validationMessage = "That tag is already selected."
            return
        }

        tags.append(cleaned)
        draft = ""
        validationMessage = nil
    }
}
