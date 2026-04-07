import os
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct RestoreBackupView: View {
    let backupService: BackupService

    @Environment(BackupStore.self) private var backupStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.profileTint) private var profileTint

    @State private var sourceData: Data?
    @State private var password = ""
    @State private var isDecrypting = false
    @State private var needsManualPassword = false
    @State private var error: String?
    @State private var payload: BackupPayload?
    @State private var showFilePicker = false
    @State private var showPreview = false
    @State private var fileError: String?
    @State private var sourceFileName: String?
    @State private var sourceFileDate: Date?
    #if ICLOUD_CAPABLE
        @State private var isLoadingICloud = false
        @State private var hasLoadedICloud = false
        @State private var iCloudError: String?
        @State private var iCloudBackups: [BackupFile] = []
        @State private var selectedBackupID: String?
    #endif

    private let logger = Logger(
        subsystem: Logger.appSubsystem,
        category: "RestoreBackup"
    )

    var body: some View {
        Form {
            #if ICLOUD_CAPABLE
                if ICloudBackupAdapter.isAvailable {
                    iCloudSection
                }
            #endif

            fileSection

            if sourceData != nil, needsManualPassword {
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
                        Button("Unlock", action: unlock)
                            .bold()
                            .disabled(needsManualPassword && password.isEmpty)
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
        #if DEMO_ENABLED
            .onAppear {
                if let name = ProcessInfo.processInfo.environment["DEMO_RESTORE_FILE"] {
                    sourceData = Data("fake-backup".utf8)
                    sourceFileName = name
                    sourceFileDate = Date(timeIntervalSinceNow: -7200)
                    needsManualPassword = true
                }
            }
        #endif
    }

    // MARK: - iCloud Section

    #if ICLOUD_CAPABLE
        private var iCloudSection: some View {
            Section {
                if isLoadingICloud {
                    HStack {
                        Text("Loading backups…")
                            .foregroundStyle(.secondary)
                        Spacer()
                        ProgressView()
                    }
                    .sesameRowBackground()
                } else if hasLoadedICloud, iCloudBackups.isEmpty, iCloudError == nil {
                    Text("No backups found")
                        .foregroundStyle(.secondary)
                        .sesameRowBackground()
                } else {
                    iCloudPickerRows
                }
            } header: {
                Text("From iCloud")
            } footer: {
                if let error = iCloudError {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }
            .task { await loadFromICloud() }
        }

        private var iCloudPickerRows: some View {
            ForEach(iCloudBackups) { file in
                Button { selectICloudBackup(file) } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(file.name)
                            Text(file.modifiedAt, format: .relative(presentation: .named))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if file.id == selectedBackupID {
                            Image(systemName: "checkmark")
                                .accessibilityLabel("Selected")
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(isDecrypting || isLoadingICloud)
                .sesameRowBackground()
            }
        }

        private func loadFromICloud() async {
            guard !isLoadingICloud, iCloudBackups.isEmpty else { return }
            isLoadingICloud = true
            iCloudError = nil

            do {
                guard let adapter = backupStore.adapter(for: "icloud") else {
                    iCloudError = ICloudBackupError.iCloudUnavailable.localizedDescription
                    isLoadingICloud = false
                    return
                }

                #if DEMO_ENABLED
                    if let delayStr = ProcessInfo.processInfo.environment["DEMO_ICLOUD_DELAY"],
                       let delay = Double(delayStr)
                    {
                        try? await Task.sleep(for: .seconds(delay))
                    }
                #endif

                let backups = try adapter.listBackups()
                iCloudBackups = backups
            } catch {
                logger.error("Failed to load iCloud backups: \(error)")
                iCloudError = error.localizedDescription
            }
            hasLoadedICloud = true
            isLoadingICloud = false
        }

        private func selectICloudBackup(_ file: BackupFile) {
            guard let adapter = backupStore.adapter(for: "icloud") else { return }
            isLoadingICloud = true
            iCloudError = nil
            fileError = nil
            error = nil

            Task {
                do {
                    let data = try await adapter.retrieve(id: file.id)
                    sourceData = data
                    sourceFileName = nil
                    selectedBackupID = file.id
                    needsManualPassword = false
                    password = ""
                    payload = nil
                } catch {
                    logger.error("Failed to retrieve iCloud backup \(file.id): \(error)")
                    iCloudError = error.localizedDescription
                }
                isLoadingICloud = false
            }
        }
    #endif

    // MARK: - File Section

    private var fileSection: some View {
        Section {
            if let fileName = sourceFileName {
                HStack {
                    VStack(alignment: .leading) {
                        Text(fileName)
                        if let date = sourceFileDate {
                            Text(date, format: .relative(presentation: .named))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Image(systemName: "checkmark")
                        .accessibilityLabel("Selected")
                }
                .sesameRowBackground()

                Button("Change File") { showFilePicker = true }
                    .disabled(isDecrypting)
                    .sesameRowBackground()
            } else {
                Button("Select .sesame File") { showFilePicker = true }
                    .disabled(isDecrypting)
                    .sesameRowBackground()
            }
        } header: {
            Text("From File")
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
                .onSubmit { unlock() }
                .submitLabel(.go)
                .sesameRowBackground()
        } header: {
            Text("Enter Password")
        } footer: {
            if let error {
                Text(error)
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Actions

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
                let attributes = try? FileManager.default.attributesOfItem(atPath: url.path())
                sourceFileDate = attributes?[.modificationDate] as? Date
                needsManualPassword = true
                password = ""
                payload = nil
            } catch {
                logger.error("Failed to read backup file: \(error)")
                fileError = error.localizedDescription
            }

        case let .failure(error):
            fileError = error.localizedDescription
        }
    }

    private func unlock() {
        guard let data = sourceData else { return }
        let adapterKey = sourceFileName == nil ? "icloud" : ""
        let enteredPassword = needsManualPassword ? password : nil

        isDecrypting = true
        error = nil

        Task {
            do {
                let result = try await backupService.unlock(
                    data: data,
                    for: adapterKey,
                    password: enteredPassword
                )
                payload = result
                showPreview = true
            } catch RestoreError.passwordRequired {
                needsManualPassword = true
            } catch BackupCryptoError.decryptionFailed {
                if needsManualPassword {
                    error = "Wrong password. Please try again."
                } else {
                    needsManualPassword = true
                }
            } catch BackupCryptoError.invalidBlob {
                error = "This file is not a valid Sesame backup."
            } catch BackupCryptoError.unsupportedVersion {
                error = "This backup was created by a newer version of Sesame."
            } catch {
                logger.error("Unlock failed: \(error)")
                self.error = error.localizedDescription
            }
            isDecrypting = false
        }
    }
}
