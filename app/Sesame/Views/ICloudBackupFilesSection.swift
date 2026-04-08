#if ICLOUD_CAPABLE
    import os
    import SwiftUI

    struct ICloudBackupFilesSection: View {
        let adapter: BackupAdapter
        let refreshID: Int

        @State private var backupFiles: [BackupFile] = []
        @State private var isLoading = false
        @State private var deleteTarget: BackupFile?
        @State private var showDeleteConfirmation = false

        private let logger = Logger(
            subsystem: Logger.appSubsystem,
            category: "ICloudBackupFiles"
        )

        var body: some View {
            Section {
                if isLoading {
                    HStack {
                        Text("Loading backups…")
                            .foregroundStyle(.secondary)
                        Spacer()
                        ProgressView()
                    }
                    .sesameRowBackground()
                } else if backupFiles.isEmpty {
                    Text("No backups found")
                        .foregroundStyle(.secondary)
                        .sesameRowBackground()
                } else {
                    ForEach(backupFiles) { file in
                        ICloudBackupFileRow(file: file) {
                            deleteTarget = file
                            showDeleteConfirmation = true
                        }
                    }
                }
            } header: {
                Text("Backups")
            }
            .task(id: refreshID) { await loadBackupFiles() }
            .alert(
                "Delete Backup?",
                isPresented: $showDeleteConfirmation,
                presenting: deleteTarget
            ) { file in
                Button("Delete", role: .destructive) {
                    Task { await deleteBackupFile(file) }
                }
                Button("Cancel", role: .cancel) {}
            } message: { _ in
                Text("This backup will be permanently deleted. This cannot be undone.")
            }
        }

        private func loadBackupFiles() async {
            isLoading = true
            do {
                backupFiles = try adapter.listBackups()
            } catch {
                logger.error("Failed to load backup files: \(error)")
            }
            isLoading = false
        }

        private func deleteBackupFile(_ file: BackupFile) async {
            do {
                try await adapter.deleteBackup(id: file.id)
                backupFiles.removeAll { $0.id == file.id }
            } catch {
                logger.error("Failed to delete backup \(file.id): \(error)")
            }
        }
    }
#endif
