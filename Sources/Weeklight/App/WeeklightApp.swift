import AppKit
import CoreData
import SwiftUI

private final class WeeklightAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

@main
struct WeeklightApp: App {
    @NSApplicationDelegateAdaptor(WeeklightAppDelegate.self) private var appDelegate

    @StateObject private var appModel: AppModel
    @StateObject private var focusDetailsCoordinator = FocusDetailsCoordinator()

    init() {
        let container: NSPersistentContainer
        let startupError: String?

        do {
            container = try PersistenceFactory.makeContainer()
            startupError = nil
        } catch let persistentStoreError {
            do {
                container = try PersistenceFactory.makeContainer(inMemory: true)
                startupError = "Weeklight could not open its local database. Changes in this session will not be saved. \(persistentStoreError.localizedDescription)"
            } catch let fallbackError {
                fatalError(
                    "Weeklight could not create a persistence container: \(fallbackError.localizedDescription)"
                )
            }
        }

        _appModel = StateObject(
            wrappedValue: AppModel(
                container: container,
                startupError: startupError
            )
        )
    }

    var body: some Scene {
        Window("Weeklight", id: "dashboard") {
            DashboardRootView()
                .environmentObject(appModel)
                .frame(minWidth: 760, minHeight: 560)
                .appErrorAlert(using: appModel)
        }
        .defaultSize(width: 980, height: 700)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        MenuBarExtra {
            MenuBarContentView()
                .environmentObject(appModel)
                .environmentObject(focusDetailsCoordinator)
                .appErrorAlert(using: appModel)
        } label: {
            MenuBarLabelView(appModel: appModel)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(appModel)
                .appErrorAlert(using: appModel)
        }
    }
}
