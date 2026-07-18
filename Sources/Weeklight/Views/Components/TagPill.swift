import SwiftUI

struct TagPill: View {
    let name: String
    var removeAction: (() -> Void)?

    var body: some View {
        HStack(spacing: 4) {
            Text("#\(name)")
                .lineLimit(1)

            if let removeAction {
                Button(action: removeAction) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove \(name) tag")
            }
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.quaternary, in: Capsule())
    }
}
