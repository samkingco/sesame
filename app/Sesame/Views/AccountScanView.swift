import AVFoundation
import SwiftUI

struct AccountScanView: View {
    #if DEMO_ENABLED
        private static let isDemo = LaunchMode.isDemoData
    #else
        private static let isDemo = false
    #endif

    let cameraPermission: AVAuthorizationStatus
    let parseError: String?
    let scanResetTrigger: Int
    var isFullHeight = false
    let onCodeScanned: (String) -> Void
    let onRequestPermission: () -> Void
    let onManualEntry: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if Self.isDemo {
                // Placeholder for camera preview in screenshot mode
                Rectangle()
                    .fill(Color(.systemGray5))
                    .overlay {
                        Image("ScannerPlaceholder")
                            .resizable()
                            .scaledToFill()
                    }
                    .clipShape(.rect(cornerRadius: 16))
                    .padding()
            } else if cameraPermission == .authorized {
                QRScannerView(onCodeScanned: onCodeScanned, resetTrigger: scanResetTrigger)
                    .clipShape(.rect(cornerRadius: 16))
                    .padding()
                    .overlay(alignment: .bottom) {
                        if let parseError {
                            ErrorBannerView(message: parseError)
                        }
                    }
            } else if cameraPermission == .notDetermined {
                CameraPromptView(
                    icon: "camera",
                    title: "Camera Access",
                    message: "Sesame needs camera access to scan QR codes.",
                    buttonTitle: "Continue",
                    isFullHeight: isFullHeight,
                    action: onRequestPermission
                )
            } else {
                CameraPromptView(
                    icon: "camera.badge.ellipsis",
                    title: "Camera Access Denied",
                    message: "Open Settings and allow camera access for Sesame to scan QR codes.",
                    buttonTitle: "Open Settings",
                    isFullHeight: isFullHeight
                ) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }

            Divider()

            Button(action: onManualEntry) {
                Text("Enter Manually")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .padding()
        }
    }
}
