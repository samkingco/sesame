import SwiftData
import SwiftUI

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.profileTint) private var profileTint
    @AppStorage(HapticService.enabledKey) private var isHapticEnabled = true
    @AppStorage(ClipboardService.clearDurationKey)
    private var clipboardClearDuration = ClipboardService.ClearDuration.default.rawValue
    @AppStorage(AppLockService.enabledKey) private var isAppLockEnabled = false
    @AppStorage(AppLockService.delayKey) private var appLockDelay = 0
    @AppStorage(SiriIntentService.enabledKey) private var isSiriIntentsEnabled = false
    @AppStorage(LiveActivityService.enabledKey) private var isLiveActivityEnabled = false
    #if AUTOFILL_CAPABLE
        @AppStorage(AutoFillService.enabledKey) private var isAutoFillEnabled = false
    #endif
    @Query(filter: #Predicate<Account> { $0.deletedAt != nil })
    private var deletedAccounts: [Account]
    @Environment(\.scenePhase) private var scenePhase
    @State private var showPasscodeAlert = false
    @State private var showLiveActivityAlert = false

    private let keychain: KeychainServiceProtocol

    init(keychain: KeychainServiceProtocol) {
        self.keychain = keychain
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Security") {
                    Toggle(AppLockService.biometryLabel, isOn: appLockToggle)
                        .sesameRowBackground()

                    if isAppLockEnabled {
                        Picker("Require After", selection: $appLockDelay) {
                            ForEach(AppLockService.LockDelay.allCases) { option in
                                Text(option.label).tag(option.rawValue)
                            }
                        }
                        .sesameRowBackground()
                    }
                }

                Section("Clipboard") {
                    Picker("Clear Clipboard", selection: $clipboardClearDuration) {
                        ForEach(ClipboardService.ClearDuration.allCases) { option in
                            Text(option.label).tag(option.rawValue)
                        }
                    }
                    .sesameRowBackground()
                    Toggle("Show in Dynamic Island", isOn: $isLiveActivityEnabled)
                        .sesameRowBackground()
                        .onChange(of: isLiveActivityEnabled) {
                            if isLiveActivityEnabled, !LiveActivityService.areSystemActivitiesEnabled {
                                showLiveActivityAlert = true
                            }
                        }
                }

                Section("General") {
                    Toggle("Haptic Feedback", isOn: $isHapticEnabled)
                        .sesameRowBackground()
                    Toggle("Siri & Shortcuts", isOn: $isSiriIntentsEnabled)
                        .sesameRowBackground()
                        .onChange(of: isSiriIntentsEnabled) {
                            Task { await SiriIntentService.updateSpotlightIndex() }
                        }
                    #if AUTOFILL_CAPABLE
                        Toggle("AutoFill Codes", isOn: $isAutoFillEnabled)
                            .sesameRowBackground()
                            .onChange(of: isAutoFillEnabled) {
                                Task {
                                    if isAutoFillEnabled {
                                        await AutoFillService.syncIdentityStore()
                                    } else {
                                        await AutoFillService.clearIdentityStore()
                                    }
                                }
                            }
                    #endif
                }

                BackupSettingsSection()

                Section {
                    NavigationLink {
                        RecentlyDeletedView(keychain: keychain)
                    } label: {
                        HStack {
                            Text("Recently Deleted")
                            Spacer()
                            if !deletedAccounts.isEmpty {
                                Text("\(deletedAccounts.count)")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .sesameRowBackground()
                }

                Section("About") {
                    Link(destination: websiteURL) {
                        HStack {
                            Text("Website")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                        }
                    }
                    .sesameRowBackground()
                    NavigationLink("Credits") {
                        CreditsView()
                    }
                    .sesameRowBackground()
                    LabeledContent("Version", value: appVersion)
                        .sesameRowBackground()
                    Link(destination: sourceURL) {
                        HStack {
                            Text("Source Code")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                        }
                    }
                    .sesameRowBackground()
                }
            }
            .sesameSheetContent()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                        .labelStyle(.iconOnly)
                }
            }
        }
        .geometryGroup()
        .presentationDetents([.large])
        .presentationBackground(Color.sesameGroupedBackground)
        .alert("No Device Passcode", isPresented: $showPasscodeAlert) {} message: {
            Text("Set a passcode in system Settings to enable app lock.")
        }
        .alert("Live Activities Disabled", isPresented: $showLiveActivityAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {
                isLiveActivityEnabled = false
            }
        } message: {
            Text("Enable Live Activities for Sesame in Settings to show copied codes in the Dynamic Island.")
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active, isLiveActivityEnabled, !LiveActivityService.areSystemActivitiesEnabled {
                isLiveActivityEnabled = false
            }
        }
    }

    // Binding(get:set:) — setter needs conditional auth before enabling
    private var appLockToggle: Binding<Bool> {
        Binding(
            get: { isAppLockEnabled },
            set: { newValue in
                if newValue {
                    guard AppLockService.isDevicePasscodeSet else {
                        showPasscodeAlert = true
                        return
                    }
                    Task {
                        let success = await AppLockService.authenticate(
                            reason: "Authenticate to enable app lock"
                        )
                        if success {
                            isAppLockEnabled = true
                        }
                    }
                } else {
                    isAppLockEnabled = false
                }
            }
        )
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "–"
        return "\(version) (\(build))"
    }

    private var websiteURL: URL {
        URL(string: "https://opensesame.software")!
    }

    private var sourceURL: URL {
        URL(string: "https://github.com/samkingco/sesame")!
    }
}
