import AVFoundation
import SwiftUI

struct AddAccountSheet: View {
    @Environment(\.dismiss) private var dismiss

    let profileId: UUID
    var initialParsed: ParsedOTPAccount?

    @State private var path = NavigationPath()
    @State private var manualInput = ""
    @State private var parseError: String?
    @State private var cameraPermission: AVAuthorizationStatus = .notDetermined
    @State private var scanResetTrigger = 0
    @State private var currentDetent: PresentationDetent = .medium
    @State private var hapticTrigger = 0

    var body: some View {
        NavigationStack(path: $path) {
            rootView
                .navigationDestination(for: AddAccountPath.self) { destination in
                    switch destination {
                    case .manualEntry:
                        ManualEntryView(
                            input: $manualInput,
                            parseError: parseError,
                            onSubmit: { handleManualInput() }
                        )
                    case let .confirmation(parsed):
                        AccountConfirmationView(
                            parsed: parsed,
                            profileId: profileId,
                            onSaved: { account in
                                hapticTrigger += 1
                                path.append(AddAccountPath.saved(account))
                            }
                        )
                    case let .saved(account):
                        CodeDetailView(account: account, onDone: { dismiss() })
                    case let .importReview(accounts):
                        ImportReviewView(
                            accounts: accounts,
                            initialProfileId: profileId,
                            onDone: { dismiss() }
                        )
                    }
                }
        }
        .sesameSheet(currentDetent: $currentDetent)
        .sensoryFeedback(.impact, trigger: hapticTrigger) { _, _ in HapticService.isEnabled }
        .onAppear {
            cameraPermission = AVCaptureDevice.authorizationStatus(for: .video)
        }
    }

    @ViewBuilder
    private var rootView: some View {
        if let initialParsed {
            AccountConfirmationView(
                parsed: initialParsed,
                profileId: profileId,
                onSaved: { account in
                    hapticTrigger += 1
                    path.append(AddAccountPath.saved(account))
                }
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                        .labelStyle(.iconOnly)
                }
            }
        } else {
            AccountScanView(
                cameraPermission: cameraPermission,
                parseError: parseError,
                scanResetTrigger: scanResetTrigger,
                isFullHeight: currentDetent == .large,
                onCodeScanned: { handleScan($0) },
                onRequestPermission: { requestCameraPermission() },
                onManualEntry: { path.append(AddAccountPath.manualEntry) }
            )
            .navigationTitle("Add Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                        .labelStyle(.iconOnly)
                }
            }
        }
    }

    // MARK: - Actions

    private func handleScan(_ input: String) {
        if input.lowercased().hasPrefix("otpauth-migration://") {
            handleMigrationScan(input)
            return
        }

        do {
            let parsed = try OTPAuthParser.parse(input)
            parseError = nil
            path.append(AddAccountPath.confirmation(parsed))
        } catch {
            showScanError(error.localizedDescription)
        }
    }

    private func handleMigrationScan(_ input: String) {
        do {
            let accounts = try GoogleAuthMigrationParser.parse(input)
            guard !accounts.isEmpty else {
                showScanError("No accounts found in QR code")
                return
            }
            parseError = nil
            path.append(AddAccountPath.importReview(accounts))
        } catch {
            showScanError(error.localizedDescription)
        }
    }

    private func showScanError(_ message: String) {
        parseError = message
        Task {
            try? await Task.sleep(for: .seconds(2))
            parseError = nil
            scanResetTrigger += 1
        }
    }

    private func handleManualInput() {
        do {
            let parsed = try OTPAuthParser.parse(manualInput)
            parseError = nil
            path.append(AddAccountPath.confirmation(parsed))
        } catch {
            parseError = error.localizedDescription
        }
    }

    private func requestCameraPermission() {
        Task {
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            cameraPermission = granted ? .authorized : .denied
        }
    }
}
