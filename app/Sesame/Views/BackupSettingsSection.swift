import SwiftUI

struct BackupSettingsSection: View {
    @Environment(BackupStore.self) private var backupStore

    var body: some View {
        Section("Backup") {
            #if ICLOUD_CAPABLE
                if ICloudBackupAdapter.isAvailable, let adapter = backupStore.adapter(for: "icloud") {
                    NavigationLink("iCloud Backup") {
                        ICloudBackupView(adapter: adapter)
                    }
                    .sesameRowBackground()
                }
            #endif

            NavigationLink("Export Backup") {
                ExportBackupView(backupService: backupStore.backupService)
            }
            .sesameRowBackground()

            NavigationLink("Restore Backup") {
                RestoreBackupView(backupService: backupStore.backupService)
            }
            .sesameRowBackground()
        }
    }
}
