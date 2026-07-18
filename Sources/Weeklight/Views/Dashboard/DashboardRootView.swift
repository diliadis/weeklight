import SwiftUI

enum DashboardSection: String, CaseIterable, Identifiable {
    case overview
    case projects
    case activity

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: "Overview"
        case .projects: "Projects"
        case .activity: "Activity"
        }
    }

    var systemImage: String {
        switch self {
        case .overview: "chart.bar.xaxis"
        case .projects: "square.stack.3d.up"
        case .activity: "clock.arrow.circlepath"
        }
    }
}

struct DashboardRootView: View {
    @State private var selection: DashboardSection? = .overview

    var body: some View {
        NavigationSplitView {
            List(DashboardSection.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.systemImage)
                    .tag(section)
            }
            .navigationTitle("Weeklight")
            .navigationSplitViewColumnWidth(min: 175, ideal: 195, max: 230)
        } detail: {
            switch selection ?? .overview {
            case .overview:
                OverviewView()
            case .projects:
                ProjectsView()
            case .activity:
                ActivityView()
            }
        }
        .tint(.accentColor)
    }
}
