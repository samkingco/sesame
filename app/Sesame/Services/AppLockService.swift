import LocalAuthentication

enum AppLockService {
    static let enabledKey = UserDefaultsKey.appLockEnabled
    static let delayKey = UserDefaultsKey.appLockDelay

    enum LockDelay: Int, CaseIterable, Identifiable {
        case immediately = 0
        case oneMinute = 60
        case fiveMinutes = 300
        case fifteenMinutes = 900

        static let `default`: LockDelay = .immediately

        var id: Int {
            rawValue
        }

        var label: String {
            switch self {
            case .immediately: "Immediately"
            case .oneMinute: "1 minute"
            case .fiveMinutes: "5 minutes"
            case .fifteenMinutes: "15 minutes"
            }
        }
    }

    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: enabledKey)
    }

    static var delay: Int {
        UserDefaults.standard.object(forKey: delayKey) == nil
            ? LockDelay.default.rawValue
            : UserDefaults.standard.integer(forKey: delayKey)
    }

    static let biometryType: LABiometryType = {
        #if DEMO_ENABLED
            if LaunchMode.isSimulator || LaunchMode.isDemoData {
                return .faceID
            }
        #else
            if LaunchMode.isSimulator {
                return .faceID
            }
        #endif
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
        return context.biometryType
    }()

    static var isDevicePasscodeSet: Bool {
        if LaunchMode.isSimulator { return true }
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    static var biometryLabel: String {
        switch biometryType {
        case .faceID: "Face ID"
        case .touchID: "Touch ID"
        case .opticID: "Optic ID"
        default: "Passcode"
        }
    }

    static var lockIcon: String {
        switch biometryType {
        case .faceID: "faceid"
        case .touchID: "touchid"
        case .opticID: "opticid"
        default: "lock"
        }
    }

    static func authenticate(reason: String = "Unlock Sesame") async -> Bool {
        if LaunchMode.isSimulator { return true }
        let context = LAContext()
        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
        } catch {
            return false
        }
    }
}
