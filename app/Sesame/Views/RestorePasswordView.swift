import os
import SwiftUI

struct RestorePasswordView: View {
    let data: Data
    let adapterKey: String
    let backupService: BackupService
    let onComplete: () -> Void

    @Environment(\.profileTint) private var profileTint

    @State private var password = ""
    @State private var error: String?
    @State private var isDecrypting = false
    @State private var payload: BackupPayload?
    @State private var showPreview = false

    private let logger = Logger(
        subsystem: Logger.appSubsystem,
        category: "RestorePassword"
    )

    var body: some View {
        Form {
            Section {
                SecureField("Password", text: $password)
                    .onSubmit { submit() }
                    .submitLabel(.go)
                    .sesameRowBackground()
            } header: {
                Text("Backup Password")
            } footer: {
                if let error {
                    Text(error)
                        .foregroundStyle(.red)
                } else {
                    Text("Enter the password used to encrypt this backup.")
                }
            }
        }
        .sesameSheetContent()
        .navigationTitle("Unlock Backup")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if isDecrypting {
                    ProgressView()
                } else {
                    Button("Unlock", action: submit)
                        .bold()
                        .disabled(password.isEmpty)
                        .tint(profileTint)
                }
            }
        }
        .navigationDestination(isPresented: $showPreview) {
            if let payload {
                RestoreConfirmView(
                    payload: payload,
                    backupService: backupService,
                    onComplete: onComplete
                )
            }
        }
    }

    private func submit() {
        guard !password.isEmpty, !isDecrypting else { return }
        isDecrypting = true
        error = nil

        Task {
            do {
                let result = try await backupService.unlock(
                    data: data,
                    for: adapterKey,
                    password: password
                )
                payload = result
                showPreview = true
            } catch BackupCryptoError.decryptionFailed {
                error = "Wrong password. Please try again."
            } catch {
                logger.error("Unlock failed: \(error)")
                self.error = error.localizedDescription
            }
            isDecrypting = false
        }
    }
}
