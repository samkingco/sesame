import BackgroundTasks
import SwiftData
import SwiftUI

@main
struct SesameApp: App {
    @Environment(\.scenePhase) private var scenePhase

    private static let backgroundTaskIdentifier = "\(Bundle.main.bundleIdentifier!).purgeExpired"
    private static let backgroundPurgeInterval: TimeInterval = 4 * 60 * 60

    private let modelContainer: ModelContainer
    private let keychain: KeychainServiceProtocol
    @State private var clock = AppClock()
    #if DEMO_ENABLED
        @State private var lockState = AppLockState(isEnabled: {
            LaunchMode.isDemoData ? false : AppLockService.isEnabled
        })
    #else
        @State private var lockState = AppLockState()
    #endif
    @State private var backupStore: BackupStore
    @State private var codeService: CodeService

    init() {
        modelContainer = SharedModelContainer.shared

        #if DEMO_ENABLED
            if LaunchMode.isDemoData {
                let stubKeychain = InMemoryKeychainService()
                DemoData.seed(context: modelContainer.mainContext, keychain: stubKeychain)
                keychain = stubKeychain
            } else {
                keychain = KeychainService()
            }
        #else
            keychain = KeychainService()
        #endif

        _codeService = State(initialValue: CodeService(keychain: keychain))

        let backupService = BackupService(
            keychain: keychain,
            modelContext: modelContainer.mainContext
        )
        _backupStore = State(initialValue: BackupStore(
            backupService: backupService
        ))

        PrivacyWindowService.start()
        registerBackgroundPurge()
    }

    #if DEMO_ENABLED
        private var isDemo: Bool {
            LaunchMode.isDemoData
        }
    #endif

    var body: some Scene {
        WindowGroup {
            AccountListView(keychain: keychain)
                .environment(clock)
                .environment(backupStore)
                .environment(codeService)
            #if DEMO_ENABLED
                .preferredColorScheme(isDemo ? .dark : nil)
            #endif
                .task {
                    purgeOnLaunch()
                    #if ICLOUD_CAPABLE
                        await backupStore.resolveICloudAdapter()
                    #endif
                    #if AUTOFILL_CAPABLE
                        if AutoFillService.isEnabled {
                            await AutoFillService.syncIdentityStore()
                        }
                    #endif
                }
        }
        .modelContainer(modelContainer)
        .onChange(of: scenePhase, initial: true) { _, newPhase in
            lockState.handleScenePhase(newPhase)
            if newPhase == .background {
                codeService.clearSecretCache()
                schedulePurgeTask()
            }
        }
    }

    @MainActor
    private func purgeOnLaunch() {
        PurgeService.purgeExpired(
            context: modelContainer.mainContext,
            keychain: keychain
        )
    }

    private func registerBackgroundPurge() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.backgroundTaskIdentifier,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            handleBackgroundPurge(refreshTask)
        }
    }

    private func handleBackgroundPurge(_ task: BGAppRefreshTask) {
        Task {
            PurgeService.purgeExpired(
                context: modelContainer.mainContext,
                keychain: keychain
            )
            task.setTaskCompleted(success: true)
        }
        schedulePurgeTask()
    }

    private func schedulePurgeTask() {
        let request = BGAppRefreshTaskRequest(identifier: Self.backgroundTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: Self.backgroundPurgeInterval)
        try? BGTaskScheduler.shared.submit(request)
    }
}
