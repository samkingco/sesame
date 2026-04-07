import AVFoundation
import SwiftUI

struct QRScannerView: UIViewControllerRepresentable {
    let onCodeScanned: (String) -> Void
    var resetTrigger: Int = 0

    func makeUIViewController(context _: Context) -> QRScannerViewController {
        let controller = QRScannerViewController()
        controller.onCodeScanned = onCodeScanned
        return controller
    }

    func updateUIViewController(_ controller: QRScannerViewController, context: Context) {
        if context.coordinator.lastResetTrigger != resetTrigger {
            context.coordinator.lastResetTrigger = resetTrigger
            controller.resetScanning()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var lastResetTrigger = 0
    }
}
