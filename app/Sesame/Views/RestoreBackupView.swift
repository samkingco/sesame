import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct RestoreBackupView: View {
    let backupService: BackupService

    @Environment(\.dismiss) private var dismiss
    @Environment(\.profileTint) private var profileTint

    @State private var sourceData: Data?
    @State private var password = ""
    @State private var isDecrypting = false
    @State private var error: String?
    @State private var payload: BackupPayload?
    @State private var showFilePicker = false
    @State private var showPreview = false
    @State private var fileError: String?
    @State private var sourceFileName: String?
    #if ICLOUD_CAPABLE
        @State private var isLoadingICloud = false
        @State private var iCloudError: String?
    #endif

    var body: some View {
        Form {
            #if ICLOUD_CAPABLE
                if ICloudBackupAdapter.isAvailable {
                    iCloudSection
                }
            #endif

            fileSection

            if sourceData != nil {
                passwordSection
            }
        }
        .sesameSheetContent()
        .navigationTitle("Restore Backup")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if sourceData != nil {
                ToolbarItem(placement: .confirmationAction) {
                    if isDecrypting {
                        ProgressView()
                    } else {
                        Button("Unlock", action: { decrypt(with: password) })
                            .bold()
                            .disabled(password.isEmpty)
                            .tint(profileTint)
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.sesameBackup],
            onCompletion: handleFileSelection
        )
        .navigationDestination(isPresented: $showPreview) {
            if let payload {
                RestoreConfirmView(
                    payload: payload,
                    backupService: backupService,
                    onComplete: { dismiss() }
                )
            }
        }
    }

    // MARK: - iCloud Section

    #if ICLOUD_CAPABLE
        private var iCloudSection: some View {
            Section {
                Button(action: loadFromICloud) {
                    HStack {
                        Text("Restore from iCloud")
                        Spacer()
                        if isLoadingICloud {
                            ProgressView()
                        } else if sourceData != nil, sourceFileName == nil {
                            Image(systemName: "checkmark")
                                .foregroundStyle(profileTint)
                        }
                    }
                }
                .disabled(isLoadingICloud || isDecrypting)
                .sesameRowBackground()
            } footer: {
                if let error = iCloudError {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }
        }
    #endif

    // MARK: - File Section

    private var fileSection: some View {
        Section {
            Button(action: { showFilePicker = true }) {
                HStack {
                    Text(sourceFileName ?? "Select .sesame File")
                    Spacer()
                    if sourceFileName != nil {
                        Image(systemName: "checkmark")
                            .foregroundStyle(profileTint)
                    }
                }
            }
            .disabled(isDecrypting)
            .sesameRowBackground()
        } footer: {
            if let error = fileError {
                Text(error)
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Password Section

    private var passwordSection: some View {
        Section {
            SecureField("Password", text: $password)
                .onSubmit { decrypt(with: password) }
                .submitLabel(.go)
                .sesameRowBackground()
        } footer: {
            if let error {
                Text(error)
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Actions

    #if ICLOUD_CAPABLE
        private func loadFromICloud() {
            isLoadingICloud = true
            iCloudError = nil
            fileError = nil
            error = nil

            Task {
                do {
                    let adapter = ICloudBackupAdapter()
                    let blob = try await adapter.retrieve()
                    sourceData = blob
                    sourceFileName = nil
                    password = ""
                    payload = nil
                } catch {
                    iCloudError = error.localizedDescription
                }
                isLoadingICloud = false
            }
        }
    #endif

    private func handleFileSelection(_ result: Result<URL, Error>) {
        #if ICLOUD_CAPABLE
            iCloudError = nil
        #endif
        fileError = nil
        error = nil

        switch result {
        case let .success(url):
            guard url.startAccessingSecurityScopedResource() else {
                fileError = "Unable to access the selected file."
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                sourceData = try Data(contentsOf: url)
                sourceFileName = url.lastPathComponent
                password = ""
                payload = nil
            } catch {
                fileError = error.localizedDescription
            }

        case let .failure(error):
            fileError = error.localizedDescription
        }
    }

    private func decrypt(with pwd: String) {
        guard let data = sourceData, !pwd.isEmpty else { return }

        isDecrypting = true
        error = nil

        Task {
            do {
                let result = try await RestoreService.decryptPayload(data: data, password: pwd)
                payload = result
                showPreview = true
            } catch BackupCryptoError.decryptionFailed {
                error = "Wrong password. Please try again."
            } catch BackupCryptoError.invalidBlob {
                error = "This file is not a valid Sesame backup."
            } catch BackupCryptoError.unsupportedVersion {
                error = "This backup was created by a newer version of Sesame."
            } catch {
                self.error = error.localizedDescription
            }
            isDecrypting = false
        }
    }
}
