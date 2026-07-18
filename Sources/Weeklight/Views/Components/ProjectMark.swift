import SwiftUI

struct ProjectMark: View {
    let project: Project
    var size: CGFloat = 10

    var body: some View {
        Circle()
            .fill(Color(projectHex: project.colorHex))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
