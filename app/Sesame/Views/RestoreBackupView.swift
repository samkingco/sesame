import os
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

private enum RestoreDestination: Hashable {
    case preview(BackupPayload)
    case password(Data, adapterKey: String)
}

private enum ICloudUnlockResult {
    case unlocked(BackupPayload)
    case needsPassword(Data)
}

struct RestoreBackupView: View {
    let backupService: BackupService

    @Environment(BackupStore.self) private var backupStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.profileTint) private var profileTint

    @State private var sourceData: Data?
    @State private var isDecrypting = false
    @State private var error: String?
    @State private var payload: BackupPayload?
    @State private var showFilePicker = false
    @State private var destination: RestoreDestination?
    @State private var fileError: String?
    @State private var sourceFileName: String?
    @State private var sourceFileDate: Date?
    #if ICLOUD_CAPABLE
        @State private var isLoadingICloud = false
        @State private var hasLoadedICloud = false
        @State private var iCloudError: String?
        @State private var iCloudBackups: [BackupFile] = []
        @State private var selectedBackupID: String?
        @State private var isRetrievingICloud = false
        @State private var iCloudPayload: BackupPayload?
        @State private var iCloudCache: [String: ICloudUnlockResult] = [:]
    #endif

    private let logger = Logger(
        subsystem: Logger.appSubsystem,
        category: "RestoreBackup"
    )

    var body: some View {
        Form {
            #if ICLOUD_CAPABLE
                if backupStore.adapter(for: "icloud") != nil {
                    iCloudSection
                }
            #endif

            fileSection
        }
        .sesameSheetContent()
        .navigationTitle("Restore Backup")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if isDecrypting || isRetrieving {
                    ProgressView()
                } else {
                    Button("Unlock", action: unlock)
                        .bold()
                        .disabled(!canUnlock)
                        .tint(profileTint)
                }
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.sesameBackup],
            onCompletion: handleFileSelection
        )
        .navigationDestination(item: $destination) { dest in
            switch dest {
            case let .preview(payload):
                RestoreConfirmView(
                    payload: payload,
                    backupService: backupService,
                    onComplete: { dismiss() }
                )
            case let .password(data, adapterKey):
                RestorePasswordView(
                    data: data,
                    adapterKey: adapterKey,
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
                }
            }
        #endif
    }

    // MARK: - Unlock State

    private var isRetrieving: Bool {
        #if ICLOUD_CAPABLE
            return isRetrievingICloud
        #else
            return false
        #endif
    }

    private var canUnlock: Bool {
        #if ICLOUD_CAPABLE
            if selectedBackupID != nil { return sourceData != nil }
        #endif
        return sourceData != nil && sourceFileName != nil
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
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isDecrypting)
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
            selectedBackupID = file.id
            iCloudError = nil
            iCloudPayload = nil
            sourceFileName = nil

            if let cached = iCloudCache[file.id] {
                switch cached {
                case let .unlocked(payload):
                    iCloudPayload = payload
                case let .needsPassword(data):
                    sourceData = data
                }
                return
            }

            isRetrievingICloud = true

            Task {
                do {
                    let data = try await adapter.retrieve(id: file.id)
                    sourceData = data

                    let result = try await backupService.unlock(data: data, for: "icloud", password: nil)
                    iCloudPayload = result
                    iCloudCache[file.id] = .unlocked(result)
                } catch is RestoreError, is BackupCryptoError {
                    if let sourceData {
                        iCloudCache[file.id] = .needsPassword(sourceData)
                    }
                } catch {
                    logger.error("Failed to load iCloud backup \(file.id): \(error)")
                    iCloudError = error.localizedDescription
                    selectedBackupID = nil
                    sourceData = nil
                }
                isRetrievingICloud = false
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

    // MARK: - Actions

    private func unlock() {
        #if ICLOUD_CAPABLE
            if selectedBackupID != nil {
                if let iCloudPayload {
                    destination = .preview(iCloudPayload)
                } else if let sourceData {
                    destination = .password(sourceData, adapterKey: "icloud")
                }
                return
            }
        #endif

        guard let data = sourceData else { return }
        isDecrypting = true
        error = nil

        Task {
            do {
                let result = try await backupService.unlock(data: data, for: "", password: nil)
                destination = .preview(result)
            } catch RestoreError.passwordRequired {
                destination = .password(data, adapterKey: "")
            } catch BackupCryptoError.decryptionFailed {
                destination = .password(data, adapterKey: "")
            } catch BackupCryptoError.invalidBlob {
                fileError = "This file is not a valid Sesame backup."
            } catch BackupCryptoError.unsupportedVersion {
                fileError = "This backup was created by a newer version of Sesame."
            } catch {
                logger.error("Unlock failed: \(error)")
                fileError = error.localizedDescription
            }
            isDecrypting = false
        }
    }

    private func handleFileSelection(_ result: Result<URL, Error>) {
        #if ICLOUD_CAPABLE
            iCloudError = nil
            selectedBackupID = nil
            iCloudPayload = nil
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
                let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
                sourceFileDate = attributes?[.modificationDate] as? Date
                payload = nil
            } catch {
                logger.error("Failed to read backup file: \(error)")
                fileError = error.localizedDescription
            }

        case let .failure(error):
            fileError = error.localizedDescription
        }
    }
}
