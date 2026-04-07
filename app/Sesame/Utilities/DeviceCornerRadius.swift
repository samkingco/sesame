import Foundation

enum DeviceCornerRadius {
    static var current: CGFloat {
        radiusMap[modelIdentifier] ?? 55
    }

    // MARK: - Model identifier

    private static let modelIdentifier: String = {
        var size = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &machine, &size, nil, 0)
        return String(cString: machine)
    }()

    // MARK: - Radius map

    /// Simulator returns "arm64" or "x86_64" — not in the map, falls back to 55.
    private static let radiusMap: [String: CGFloat] = {
        var map = [String: CGFloat]()

        // 39 — iPhone X, Xs, Xs Max, 11 Pro, 11 Pro Max
        let r39: [String] = [
            "iPhone10,3", "iPhone10,6", // X
            "iPhone11,2", // Xs
            "iPhone11,4", "iPhone11,6", // Xs Max
            "iPhone12,3", // 11 Pro
            "iPhone12,5", // 11 Pro Max
        ]

        // 41.5 — iPhone Xr, 11
        let r41_5: [String] = [
            "iPhone11,8", // Xr
            "iPhone12,1", // 11
        ]

        // 44 — iPhone 12 mini, 13 mini
        let r44: [String] = [
            "iPhone13,1", // 12 mini
            "iPhone14,4", // 13 mini
        ]

        // 47.33 — iPhone 12, 12 Pro, 13, 13 Pro, 14
        let r47_33: [String] = [
            "iPhone13,2", "iPhone13,3", // 12, 12 Pro
            "iPhone14,5", "iPhone14,2", // 13, 13 Pro
            "iPhone14,7", // 14
        ]

        // 53.33 — iPhone 12 Pro Max, 13 Pro Max, 14 Plus, 15 Plus, 16 Plus
        let r53_33: [String] = [
            "iPhone13,4", // 12 Pro Max
            "iPhone14,3", // 13 Pro Max
            "iPhone14,8", // 14 Plus
            "iPhone15,5", // 15 Plus
            "iPhone17,4", // 16 Plus
        ]

        // 55 — iPhone 14 Pro, 14 Pro Max, 15, 15 Pro, 15 Pro Max, 16, 16 Pro, 16 Pro Max, 16e
        let r55: [String] = [
            "iPhone15,2", // 14 Pro
            "iPhone15,3", // 14 Pro Max
            "iPhone15,4", // 15
            "iPhone16,1", // 15 Pro
            "iPhone16,2", // 15 Pro Max
            "iPhone17,1", // 16 Pro
            "iPhone17,2", // 16 Pro Max
            "iPhone17,3", // 16
            "iPhone17,5", // 16e
        ]

        // 62 — iPhone 17, 17 Pro, 17 Pro Max, Air, 17e
        let r62: [String] = [
            "iPhone18,1", // 17 Pro
            "iPhone18,2", // 17 Pro Max
            "iPhone18,3", // 17
            "iPhone18,4", // Air
            "iPhone18,5", // 17e
        ]

        for id in r39 {
            map[id] = 39
        }
        for id in r41_5 {
            map[id] = 41.5
        }
        for id in r44 {
            map[id] = 44
        }
        for id in r47_33 {
            map[id] = 47.33
        }
        for id in r53_33 {
            map[id] = 53.33
        }
        for id in r55 {
            map[id] = 55
        }
        for id in r62 {
            map[id] = 62
        }

        return map
    }()
}
