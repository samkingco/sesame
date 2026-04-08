#if ICLOUD_CAPABLE
    import SwiftUI

    struct ICloudBackupFileRow: View {
        let file: BackupFile
        let onDelete: () -> Void

        var body: some View {
            VStack(alignment: .leading) {
                Text(file.name)
                Text(file.modifiedAt, format: .relative(presentation: .named))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .sesameRowBackground()
            .swipeActions(edge: .trailing) {
                Button("Delete", action: onDelete)
                    .tint(.red)
            }
        }
    }
#endif
