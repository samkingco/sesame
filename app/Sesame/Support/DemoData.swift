import Foundation
import SwiftData

#if DEMO_ENABLED

    // MARK: - In-memory keychain stub for demo/screenshot mode

    final class InMemoryKeychainService: KeychainServiceProtocol {
        private var store: [UUID: String] = [:]

        func save(secret: String, for accountId: UUID) throws {
            store[accountId] = secret
        }

        func read(for accountId: UUID) throws -> String {
            guard let secret = store[accountId] else {
                throw KeychainError.readFailed(errSecItemNotFound)
            }
            return secret
        }

        func delete(for accountId: UUID) throws {
            store.removeValue(forKey: accountId)
        }
    }

    // MARK: - Demo data seeding

    enum DemoData {
        private struct DemoAccount {
            let issuer: String
            let name: String
            let profileId: UUID
            let secret: String
            let type: OTPType
            let counter: Int

            init(
                _ issuer: String, _ name: String, _ profileId: UUID, _ secret: String,
                type: OTPType = .totp, counter: Int = 0
            ) {
                self.issuer = issuer
                self.name = name
                self.profileId = profileId
                self.secret = secret
                self.type = type
                self.counter = counter
            }
        }

        @MainActor static func seed(context: ModelContext, keychain: KeychainServiceProtocol) {
            let personal = Profile.makeDefault()
            let work = Profile(name: "Work", color: "#6366F1", sortOrder: 1)
            let studio = Profile(name: "Studio", color: "#EAB308", sortOrder: 2)

            context.insert(personal)
            context.insert(work)
            context.insert(studio)

            let accounts: [DemoAccount] = [
                // Personal
                DemoAccount("GitHub", "simhull", personal.id, "JBSWY3DPEHPK3PXP"),
                DemoAccount("Google", "sim@gmail.com", personal.id, "GEZDGNBVGY3TQOJQ"),
                DemoAccount("Discord", "simhull", personal.id, "KRSXG5CTMVRXEZLU"),
                DemoAccount("Figma", "simhull", personal.id, "HXDMVJECJJWSRB3H"),
                DemoAccount("Notion", "sim@gmail.com", personal.id, "OBQXG43XN5ZGI3LF"),
                DemoAccount("Proton", "sim@proton.me", personal.id, "GIYTEMZUGU3DOOBZ"),
                DemoAccount("Vaultic", "simhull", personal.id, "TFQWCYLBMFQWCYLZ",
                            type: .hotp, counter: 42),
                // Work
                DemoAccount("AWS", "sim.hull@acme.com", work.id, "MFQWCYLBMFQWCYLB"),
                DemoAccount("Slack", "sim@acme.com", work.id, "NBSWY3DPEHPK3PXR"),
                DemoAccount("Linear", "sim@acme.com", work.id, "ORSXG5BAORSXG5BA"),
                DemoAccount("Cloudflare", "sim@acme.com", work.id, "PJWGY2LPOIQXE3DF"),
                // Studio
                DemoAccount("Refrakt", "simstudio", studio.id, "KBSWY3DPEHPK3PXQ"),
                DemoAccount("Kiln", "sim@simstudio.com", studio.id, "LEZDGNBVGY3TQOJR"),
                DemoAccount("Stripe", "sim@simstudio.com", studio.id, "IRSXG5CTMVRXEZLV"),
                DemoAccount("Akkeri", "simstudio", studio.id, "QXDMVJECJJWSRB3I"),
                DemoAccount("Kaiho", "sim@simstudio.com", studio.id, "RFQWCYLBMFQWCYLC"),
            ]

            // Settings visible in screenshots and video (skip for UI tests)
            if LaunchMode.demo == .screenshots || LaunchMode.demo == .video {
                UserDefaults.standard.set(true, forKey: AppLockService.enabledKey)
                UserDefaults.standard.set(true, forKey: UserDefaultsKey.liveActivityEnabled)
                #if ICLOUD_CAPABLE
                    UserDefaults.standard.set(true, forKey: UserDefaultsKey.backupAutoBackupEnabledPrefix + "icloud")
                    UserDefaults.standard.set(true, forKey: UserDefaultsKey.backupConfiguredPrefix + "icloud")
                    UserDefaults.standard.set(true, forKey: BackupStore.recoveryKeyWarningShownKey)
                    UserDefaults.standard.set(Date.now, forKey: UserDefaultsKey.lastBackupPrefix + "icloud")
                #endif
            }

            #if ICLOUD_CAPABLE
                // Always clean the demo iCloud dir to prevent leftover files from previous runs
                let dir = FileManager.default.temporaryDirectory.appending(path: "icloud-demo/Documents")
                try? FileManager.default.removeItem(at: dir)

                if let countStr = ProcessInfo.processInfo.environment["SEED_ICLOUD_BACKUPS"],
                   let count = Int(countStr), count > 0
                {
                    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

                    let fakeBackups: [(String, TimeInterval)] = [
                        ("sams-iphone-k7x2m9ab.backup.sesame", -3600),
                        ("sams-ipad-x1y2z3w4.backup.sesame", -86400),
                        ("sesame-backup.sesame", -604800),
                    ]

                    for i in 0 ..< min(count, fakeBackups.count) {
                        let (name, offset) = fakeBackups[i]
                        let url = dir.appending(path: name)
                        try? Data("fake-backup".utf8).write(to: url)
                        try? FileManager.default.setAttributes(
                            [.modificationDate: Date(timeIntervalSinceNow: offset)],
                            ofItemAtPath: url.path()
                        )
                    }
                }
            #endif

            for entry in accounts {
                let account = Account(
                    profileId: entry.profileId,
                    issuer: entry.issuer,
                    name: entry.name,
                    type: entry.type,
                    counter: entry.counter
                )
                context.insert(account)
                try? keychain.save(secret: entry.secret, for: account.id)
            }
        }
    }

#endif
