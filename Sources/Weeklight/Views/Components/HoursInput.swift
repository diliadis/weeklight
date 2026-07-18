import SwiftUI

struct HoursInput: View {
    let accessibilityLabel: String
    @Binding var value: Double

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            TextField(
                "Hours",
                value: $value,
                format: .number.precision(.fractionLength(0...1))
            )
            .labelsHidden()
            .multilineTextAlignment(.trailing)
            .frame(width: 60)
            .accessibilityLabel(accessibilityLabel)

            Text("hours")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: true, vertical: false)
        }
    }
}
