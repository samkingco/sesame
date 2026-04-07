import SwiftUI

struct ColorPaletteView: View {
    @Binding var selectedColor: String?

    private static let colorNames: [String: String] = [
        "#3B82F6": "Blue",
        "#6366F1": "Indigo",
        "#8B5CF6": "Violet",
        "#D946EF": "Fuchsia",
        "#EC4899": "Pink",
        "#EF4444": "Red",
        "#F97316": "Orange",
        "#EAB308": "Yellow",
        "#84CC16": "Lime",
        "#22C55E": "Green",
        "#14B8A6": "Teal",
        "#06B6D4": "Cyan",
    ]

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
            ForEach(Profile.colorPalette, id: \.self) { hex in
                let isSelected = selectedColor == hex

                Button {
                    selectedColor = isSelected ? nil : hex
                } label: {
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 32, height: 32)
                        .overlay {
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Self.colorNames[hex, default: hex])
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }
}
