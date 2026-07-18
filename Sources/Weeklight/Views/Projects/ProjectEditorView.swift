import SwiftUI

struct ProjectEditorView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss

    let project: Project?

    @State private var name: String
    @State private var selectedColorHex: String
    @State private var weeklyHours: Double
    @State private var applyToSelectedWeek = true

    init(project: Project?) {
        self.project = project
        _name = State(initialValue: project?.name ?? "")
        _selectedColorHex = State(
            initialValue: project?.colorHex ?? ProjectPalette.choices[0].hex
        )
        _weeklyHours = State(initialValue: project.map {
            Double($0.defaultWeeklyMinutes) / 60
        } ?? 8)
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Project") {
                    TextField("Name", text: $name, prompt: Text("Website redesign"))
                        .textFieldStyle(.roundedBorder)

                    LabeledContent("Color") {
                        HStack(spacing: 9) {
                            ForEach(ProjectPalette.choices) { item in
                                Button {
                                    selectedColorHex = item.hex
                                } label: {
                                    Circle()
                                        .fill(Color(projectHex: item.hex))
                                        .frame(width: 22, height: 22)
                                        .overlay {
                                            if selectedColorHex == item.hex {
                                                Image(systemName: "checkmark")
                                                    .font(.caption2.bold())
                                                    .foregroundStyle(.white)
                                            }
                                        }
                                }
                                .buttonStyle(.plain)
                                .help(item.name)
                                .accessibilityLabel(item.name)
                                .accessibilityAddTraits(
                                    selectedColorHex == item.hex ? .isSelected : []
                                )
                            }
                        }
                    }
                }

                Section("Weekly plan") {
                    LabeledContent("Default allocation") {
                        HoursInput(
                            accessibilityLabel: "Default weekly allocation in hours",
                            value: $weeklyHours
                        )
                    }

                    if project != nil {
                        Toggle("Apply to the selected week", isOn: $applyToSelectedWeek)
                    }
                }
            }
            .formStyle(.grouped)

            Divider()
            HStack {
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                Spacer()
                Button(project == nil ? "Add project" : "Save") {
                    save()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
            .padding(16)
        }
        .frame(width: 460, height: project == nil ? 330 : 370)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && weeklyHours >= 0
            && weeklyHours <= 168
    }

    private func save() {
        let minutes = Int((weeklyHours * 60).rounded())
        let didSave: Bool
        if let project {
            didSave = appModel.updateProject(
                project,
                name: name,
                colorHex: selectedColorHex,
                defaultWeeklyMinutes: minutes,
                applyToSelectedWeek: applyToSelectedWeek
            )
        } else {
            didSave = appModel.createProject(
                name: name,
                colorHex: selectedColorHex,
                defaultWeeklyMinutes: minutes
            )
        }

        if didSave {
            dismiss()
        }
    }
}
