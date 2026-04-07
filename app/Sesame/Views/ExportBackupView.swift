import SwiftUI
import UniformTypeIdentifiers

// MARK: - UTType

extension UTType {
    static let sesameBackup = UTType(exportedAs: "studio.samking.sesame-backup")
}

// MARK: - View

struct ExportBackupView: View {
    let backupService: BackupService

    @Environment(\.dismiss) private var dismiss
    @Environment(\.profileTint) private var profileTint

    @State private var customPassword = ""
    @State private var confirmPassword = ""
    @State private var showValidation = false
    @State private var isExporting = false
    @State private var exportError: String?
    @State private var exportFileURL: URL?
    @State private var showExportReady = false

    var body: some View {
        Form {
            PasswordEntryFields(
                password: $customPassword,
                confirmation: $confirmPassword,
                showValidation: showValidation,
                hint: "You'll need this password to restore. It cannot be recovered."
            )

            if let error = exportError {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.footnote)
                        .sesameRowBackground()
                }
            }
        }
        .sesameSheetContent()
        .navigationTitle("Export Backup")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if isExporting {
                    ProgressView()
                } else {
                    Button("Export", action: exportWithCustom)
                        .bold()
                        .tint(profileTint)
                }
            }
        }
        .navigationDestination(isPresented: $showExportReady) {
            if let url = exportFileURL {
                ExportReadyView(url: url) {
                    cleanUpTempFile()
                    dismiss()
                }
            }
        }
        .onChange(of: showExportReady) { _, isShowing in
            if !isShowing { cleanUpTempFile() }
        }
    }

    // MARK: - Export Actions

    private func exportWithCustom() {
        showValidation = true
        guard PasswordValidation.isValid(password: customPassword, confirmation: confirmPassword) else { return }
        export(password: customPassword)
    }

    private func export(password: String) {
        isExporting = true
        exportError = nil

        Task {
            do {
                let blob = try await backupService.buildEncryptedBlob(password: password)
                let url = try Self.writeTempFile(blob: blob)
                exportFileURL = url
                showExportReady = true
            } catch {
                exportError = error.localizedDescription
            }
            isExporting = false
        }
    }

    // MARK: - File Helpers

    // swiftui-pro: intentional DateFormatter — this is a filename component, not user-facing
    // text, and it's created once in a button action (not on render).
    static func writeTempFile(blob: Data) throws -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: .now)
        let filename = "sesame-backup-\(dateString).sesame"
        let url = FileManager.default.temporaryDirectory.appending(path: filename)
        try blob.write(to: url)
        return url
    }

    private func cleanUpTempFile() {
        guard let url = exportFileURL else { return }
        try? FileManager.default.removeItem(at: url)
        exportFileURL = nil
    }
}

// MARK: - Export Ready View

private struct ExportReadyView: View {
    let url: URL
    let onDone: () -> Void

    @Environment(\.profileTint) private var profileTint

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            if let icon = UIImage(named: "app-icon") {
                Image(uiImage: icon)
                    .resizable()
                    .frame(width: 128, height: 128)
                    .clipShape(.rect(cornerRadius: 28))
                    .accessibilityHidden(true)
            }

            Text(url.lastPathComponent)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 12)
                .padding(.bottom, 20)

            ShareLink(
                item: ExportedBackupFile(url: url),
                preview: SharePreview(url.lastPathComponent)
            ) {
                Text("Save File")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(profileTint)

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .sesameSheetContent()
        .navigationTitle("Export Backup")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done", action: onDone)
                    .bold()
            }
        }
    }
}

// MARK: - Transferable Backup File

struct ExportedBackupFile: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .sesameBackup) { file in
            SentTransferredFile(file.url)
        }
    }
}
