import SwiftUI

private struct AppErrorAlertModifier: ViewModifier {
    @ObservedObject var appModel: AppModel

    func body(content: Content) -> some View {
        content.alert(
            "Weeklight",
            isPresented: Binding(
                get: { appModel.errorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        appModel.clearError()
                    }
                }
            ),
            actions: {
                Button("OK") {
                    appModel.clearError()
                }
            },
            message: {
                Text(appModel.errorMessage ?? "An unexpected error occurred.")
            }
        )
    }
}

extension View {
    func appErrorAlert(using appModel: AppModel) -> some View {
        modifier(AppErrorAlertModifier(appModel: appModel))
    }
}
