import SwiftUI

extension View {
    /// Apply to the outermost view of a sheet. Configures detents
    /// and presentation background (system grouped at large, system glass at medium).
    func sesameSheet(currentDetent: Binding<PresentationDetent>) -> some View {
        geometryGroup()
            .presentationDetents([.medium, .large], selection: currentDetent)
            .presentationBackground(
                currentDetent.wrappedValue == .large
                    ? Color.sesameGroupedBackground
                    : Color.clear
            )
    }

    /// Apply to Form/List inside a sheet (root or pushed).
    /// Hides scroll background so sheet glass shows through at medium.
    /// Clears navigation container background for pushed views.
    func sesameSheetContent() -> some View {
        modifier(SesameSheetContentModifier())
    }

    /// Apply to individual rows for themed row backgrounds.
    func sesameRowBackground() -> some View {
        listRowBackground(Color.sesameSurface)
    }
}

private struct SesameSheetContentModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .containerBackground(.clear, for: .navigation)
    }
}
