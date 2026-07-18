import SwiftUI

struct ProjectPaletteItem: Identifiable, Hashable {
    let name: String
    let hex: String

    var id: String { hex }
}

enum ProjectPalette {
    static let choices: [ProjectPaletteItem] = [
        .init(name: "Blue", hex: "4F7FFF"),
        .init(name: "Indigo", hex: "7165E8"),
        .init(name: "Teal", hex: "26A69A"),
        .init(name: "Green", hex: "4B9B66"),
        .init(name: "Orange", hex: "DE873A"),
        .init(name: "Rose", hex: "D65A78"),
        .init(name: "Graphite", hex: "697386")
    ]
}

extension Color {
    init(projectHex hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let red: Double
        let green: Double
        let blue: Double

        if cleaned.count == 6 {
            red = Double((value >> 16) & 0xFF) / 255
            green = Double((value >> 8) & 0xFF) / 255
            blue = Double(value & 0xFF) / 255
        } else {
            red = 0.31
            green = 0.50
            blue = 1
        }

        self.init(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }
}
