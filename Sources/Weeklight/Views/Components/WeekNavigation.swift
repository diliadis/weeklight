import SwiftUI

struct WeekNavigation: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        HStack(spacing: 8) {
            Button {
                appModel.moveSelectedWeek(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .help("Previous week")

            Button {
                appModel.selectCurrentWeek()
            } label: {
                Text(WeeklightFormatters.weekTitle(appModel.selectedWeekStart))
                    .frame(minWidth: 180)
            }
            .help("Return to the current week")

            Button {
                appModel.moveSelectedWeek(by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .help("Next week")
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}
