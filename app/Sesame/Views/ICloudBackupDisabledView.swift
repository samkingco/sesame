#if ICLOUD_CAPABLE
    import SwiftUI

    struct ICloudBackupDisabledView: View {
        @Environment(\.profileTint) private var profileTint

        let onSetup: () -> Void

        var body: some View {
            ContentUnavailableView {
                Label("iCloud Backup", systemImage: "icloud")
            } description: {
                Text(
                    // swiftlint:disable:next line_length
                    "Encrypt and back up your accounts to iCloud Drive. If you use Sesame for your Apple ID, save your backup codes separately in case you lose access to your device."
                )
            } actions: {
                Button("Set Up iCloud Backup", action: onSetup)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(profileTint)
            }
            .geometryGroup()
            .safeAreaPadding(.bottom, 20)
            .sesameSheetContent()
        }
    }
#endif
