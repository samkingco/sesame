import SwiftUI

struct AddProfileSheet: View {
    var onAdd: ((UUID) -> Void)?

    @State private var currentDetent: PresentationDetent = .medium

    var body: some View {
        NavigationStack {
            AddProfileView(showCancel: true, onAdd: onAdd)
        }
        .sesameSheet(currentDetent: $currentDetent)
    }
}
