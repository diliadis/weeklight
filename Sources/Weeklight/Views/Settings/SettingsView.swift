import AppKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        Form {
            Section("Planning") {
                LabeledContent("Weekly capacity") {
                    HoursInput(
                        accessibilityLabel: "Weekly capacity in hours",
                        value: capacityHours
                    )
                }
                LabeledContent("Week starts") {
                    Text("Monday")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Notifications") {
                Toggle(
                    "Enable timer notifications",
                    isOn: Binding(
                        get: { appModel.notificationsEnabled },
                        set: { appModel.setNotificationsEnabled($0) }
                    )
                )
                Toggle(
                    "Countdown finishing soon",
                    isOn: Binding(
                        get: { appModel.countdownFinishingNotificationEnabled },
                        set: {
                            appModel.setCountdownFinishingNotificationEnabled($0)
                        }
                    )
                )
                .disabled(!appModel.notificationsEnabled)
                Toggle(
                    "Countdown completed",
                    isOn: Binding(
                        get: { appModel.countdownCompletionNotificationEnabled },
                        set: {
                            appModel.setCountdownCompletionNotificationEnabled($0)
                        }
                    )
                )
                .disabled(!appModel.notificationsEnabled)
                Toggle(
                    "Weekly allocation reached",
                    isOn: Binding(
                        get: { appModel.allocationNotificationEnabled },
                        set: { appModel.setAllocationNotificationEnabled($0) }
                    )
                )
                .disabled(!appModel.notificationsEnabled)

                LabeledContent("macOS permission") {
                    notificationPermissionStatus
                }

                if appModel.notificationsEnabled,
                   appModel.notificationAuthorizationState == .notDetermined {
                    Button("Allow notifications") {
                        Task {
                            await appModel.refreshNotificationAuthorization(
                                requestIfNeeded: true
                            )
                        }
                    }
                }

                if appModel.notificationAuthorizationState == .denied {
                    Text("Notifications are blocked for Weeklight. Allow them in System Settings → Notifications → Weeklight.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("System") {
                Toggle(
                    "Launch Weeklight at login",
                    isOn: Binding(
                        get: { appModel.launchAtLoginEnabled },
                        set: { appModel.setLaunchAtLogin($0) }
                    )
                )

                LabeledContent("Login item status") {
                    launchAtLoginStatus
                }

                if appModel.launchAtLoginState == .requiresApproval {
                    Text("Weeklight is registered, but macOS requires your approval before it can open automatically.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Open Login Items…") {
                        appModel.openLoginItemsSettings()
                    }
                } else if appModel.launchAtLoginState == .enabled {
                    Text("Weeklight will open quietly in the menu bar when you sign in.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Manage Login Items…") {
                        appModel.openLoginItemsSettings()
                    }
                }

                if !appModel.appIsInApplicationsFolder {
                    Label(
                        "For reliable startup, move Weeklight.app to your Applications folder before enabling this option.",
                        systemImage: "folder.badge.questionmark"
                    )
                    .font(.caption)
                    .foregroundStyle(.orange)
                }

                Text("Your projects and activity stay on this Mac. Weeklight does not require an account or a network connection.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("About") {
                LabeledContent("Weeklight") {
                    Text(versionText)
                        .foregroundStyle(.secondary)
                }
                Text("A quiet weekly project timer for macOS.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 560, height: 700)
        .task {
            await appModel.refreshNotificationAuthorization()
            appModel.refreshLaunchAtLoginState()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSApplication.didBecomeActiveNotification
            )
        ) { _ in
            appModel.refreshLaunchAtLoginState()
        }
    }

    private var capacityHours: Binding<Double> {
        Binding(
            get: { Double(appModel.weeklyCapacityMinutes) / 60 },
            set: { appModel.updateWeeklyCapacity(minutes: Int(($0 * 60).rounded())) }
        )
    }

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return "Version " + (version ?? "1.0")
    }

    @ViewBuilder
    private var notificationPermissionStatus: some View {
        switch appModel.notificationAuthorizationState {
        case .unknown:
            Label("Checking…", systemImage: "ellipsis.circle")
                .foregroundStyle(.secondary)
        case .notDetermined:
            Label("Not requested", systemImage: "questionmark.circle")
                .foregroundStyle(.secondary)
        case .denied:
            Label("Blocked", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        case .authorized:
            Label("Allowed", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        }
    }

    @ViewBuilder
    private var launchAtLoginStatus: some View {
        switch appModel.launchAtLoginState {
        case .disabled:
            Label("Off", systemImage: "minus.circle")
                .foregroundStyle(.secondary)
        case .enabled:
            Label("Enabled", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .requiresApproval:
            Label("Approval required", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        case .unavailable:
            Label("Unavailable", systemImage: "xmark.circle.fill")
                .foregroundStyle(.red)
        }
    }
}
