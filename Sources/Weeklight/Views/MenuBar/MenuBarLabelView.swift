import SwiftUI

struct MenuBarLabelView: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        if let activeEntry = appModel.activeEntry {
            statusLabel(
                title: activeTitle(for: activeEntry),
                systemImage: appModel.timerActivityState.systemImage,
                accessibilityTitle: accessibilityTitle(for: activeEntry)
            )
        } else if let pausedProject = appModel.pausedProject {
            statusLabel(
                title: "\(shortName(pausedProject.name)) · Paused",
                systemImage: "pause.circle.fill",
                accessibilityTitle: "\(pausedProject.name), paused"
            )
        } else if let completedProject = appModel.recentlyCompletedProjectName {
            statusLabel(
                title: "\(shortName(completedProject)) · Done",
                systemImage: appModel.timerActivityState.systemImage,
                accessibilityTitle: "\(completedProject), completed"
            )
        } else if let lastProject = appModel.lastTrackedProject {
            statusLabel(
                title: "\(shortName(lastProject.name)) · Stopped",
                systemImage: appModel.timerActivityState.systemImage,
                accessibilityTitle: "\(lastProject.name), stopped"
            )
        } else {
            statusLabel(
                title: "Weeklight",
                systemImage: appModel.timerActivityState.systemImage,
                accessibilityTitle: "No project is running"
            )
        }
    }

    private func statusLabel(
        title: String,
        systemImage: String,
        accessibilityTitle: String
    ) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .accessibilityHidden(true)
            Text(title)
                .monospacedDigit()
                .lineLimit(1)
        }
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityTitle)
    }

    private func activeTitle(for entry: TimeEntry) -> String {
        let name = shortName(entry.project?.name ?? "Project")
        let time: String
        if let remaining = appModel.activeRemainingDuration {
            time = DurationText.countdownClock(remaining)
        } else {
            time = DurationText.clock(appModel.activeDuration)
        }
        return "\(name) · \(time)"
    }

    private func accessibilityTitle(for entry: TimeEntry) -> String {
        let name = entry.project?.name ?? "Project"
        if let remaining = appModel.activeRemainingDuration {
            let status = appModel.timerActivityState == .countdownFinishing
                ? "finishing soon"
                : "running"
            return "\(name), \(status), \(DurationText.countdownClock(remaining)) remaining"
        }
        return "\(name), \(DurationText.clock(appModel.activeDuration)) elapsed"
    }

    private func shortName(_ name: String) -> String {
        let characterLimit = 16
        guard name.count > characterLimit else { return name }
        return String(name.prefix(characterLimit - 1)) + "…"
    }
}
