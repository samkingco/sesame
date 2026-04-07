import CoreSpotlight
import os
import SwiftData
import SwiftUI

struct AccountListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(BackupStore.self) private var backupStore
    @Environment(CodeService.self) private var codeService
    @Query(
        filter: #Predicate<Account> { $0.deletedAt == nil },
        sort: \Account.createdAt
    ) private var allAccounts: [Account]
    @Query(sort: \Profile.sortOrder) private var profiles: [Profile]
    @State private var viewModel = AccountListViewModel()
    @State private var searchText = ""
    @State private var showAddAccount = false
    @State private var pendingParsed: ParsedOTPAccount?
    @State private var showAddProfile = false
    @State private var showSettings = false
    @State private var accountToEdit: Account?
    @State private var accountToDelete: Account?
    @State private var showDeleteConfirmation = false
    @State private var showManageProfiles = false
    @State private var hapticTrigger = 0
    @State private var enlargedAccount: Account?
    @State private var enlargedCodeDetent: PresentationDetent = .medium

    private let logger = Logger(subsystem: Logger.appSubsystem, category: "AccountListView")
    private let keychain: KeychainServiceProtocol

    init(keychain: KeychainServiceProtocol = KeychainService()) {
        self.keychain = keychain
    }

    private var currentProfileName: String {
        viewModel.profileName(for: viewModel.selectedProfileId, in: profiles)
    }

    private var currentProfileColor: Color {
        let hex = profiles.first(where: { $0.id == viewModel.selectedProfileId })?.color ?? Profile.defaultColor
        return Color(hex: hex)
    }

    var body: some View {
        NavigationStack {
            listContent
        }
        .environment(\.profileTint, currentProfileColor)
        .onOpenURL { url in
            guard url.scheme == "otpauth" else { return }
            do {
                let parsed = try OTPAuthParser.parse(url.absoluteString)
                pendingParsed = parsed
            } catch {
                logger.error("Failed to parse otpauth URL: \(error)")
            }
            showAddAccount = true
        }
        .onContinueUserActivity(CSSearchableItemActionType, perform: handleSpotlightActivity)
        .sheet(item: $enlargedAccount) { account in
            NavigationStack {
                CodeDetailView(account: account, title: "Code") {
                    enlargedAccount = nil
                }
            }
            .sesameSheet(currentDetent: $enlargedCodeDetent)
        }
        .sensoryFeedback(.impact, trigger: hapticTrigger) { _, _ in HapticService.isEnabled }
        .onAppear {
            ensureDefaultProfile()
            normalizeSortOrders()
        }
        .onChange(of: profiles) {
            if !profiles.contains(where: { $0.id == viewModel.selectedProfileId }) {
                viewModel.selectedProfileId = Profile.defaultID
            }
        }
    }

    // swiftui-pro: intentionally a computed property — real logic is in AccountListBody,
    // this just attaches sheets/toolbar which would need ~10 bindings if extracted.
    private var listContent: some View {
        AccountListBody(
            viewModel: viewModel,
            allAccounts: allAccounts,
            profiles: profiles,
            searchText: searchText,
            onCopy: { copyCode(for: $0) },
            onIncrement: { incrementCounter(for: $0) },
            onViewLarger: { viewLarger($0) },
            onEdit: { accountToEdit = $0 },
            onDelete: {
                accountToDelete = $0
                showDeleteConfirmation = true
            },
            onShowAddAccount: { showAddAccount = true }
        )
        .navigationTitle(currentProfileName)
        .searchable(text: $searchText, prompt: "Search accounts")
        .toolbar { toolbarContent }
        .sheet(isPresented: $showAddAccount, onDismiss: { pendingParsed = nil }) {
            AddAccountSheet(profileId: viewModel.selectedProfileId, initialParsed: pendingParsed)
        }
        .sheet(isPresented: $showAddProfile) {
            AddProfileSheet(onAdd: switchToProfile)
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet(keychain: keychain)
        }
        .sheet(item: $accountToEdit) { account in
            EditAccountSheet(
                account: account,
                profiles: profiles
            ) { result in
                account.displayIssuer = result.displayIssuer
                account.displayName = result.displayName
                if let profileId = result.profileId {
                    account.profileId = profileId
                }
                account.website = result.website
                hapticTrigger += 1
                AccountService.update(
                    account: account,
                    modelContext: modelContext,
                    backupStore: backupStore
                )
            }
        }
        .alert(
            "Delete Account?",
            isPresented: $showDeleteConfirmation,
            presenting: accountToDelete
        ) { account in
            Button("Delete", role: .destructive) {
                deleteAccount(account)
            }
            Button("Cancel", role: .cancel) {}
        } message: { account in
            // swiftlint:disable:next line_length
            Text(
                "\"\(account.effectiveIssuer)\" will be moved to Recently Deleted and permanently removed after 48 hours."
            )
        }
        .sheet(isPresented: $showManageProfiles) {
            ProfileManagementSheet(keychain: keychain, onAdd: switchToProfile)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            ProfilePickerView(
                profiles: profiles,
                selectedProfileId: viewModel.selectedProfileId,
                onSelect: { id in
                    viewModel.selectedProfileId = id
                    hapticTrigger += 1
                },
                onAddProfile: { showAddProfile = true },
                onManage: { showManageProfiles = true }
            )
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button("Add Account", systemImage: "plus") {
                showAddAccount = true
            }
            Button("Settings", systemImage: "ellipsis") {
                showSettings = true
            }
        }
    }

    private func switchToProfile(_ id: UUID) {
        viewModel.selectedProfileId = id
        hapticTrigger += 1
    }

    private func incrementCounter(for account: Account) {
        codeService.incrementCounter(for: account)
        hapticTrigger += 1
    }

    private func copyCode(for account: Account) {
        codeService.copyCode(for: account.id)
        codeService.startLiveActivity(for: account)
        CopyToast.show()
    }

    private func deleteAccount(_ account: Account) {
        AccountService.softDelete(
            account: account,
            modelContext: modelContext,
            backupStore: backupStore
        )
        codeService.evictSecret(for: account.id)
        hapticTrigger += 1
    }

    private func ensureDefaultProfile() {
        if let existing = profiles.first(where: { $0.id == Profile.defaultID }) {
            if existing.color == nil {
                existing.color = Profile.defaultColor
            }
        } else {
            modelContext.insert(Profile.makeDefault())
        }
    }

    private func viewLarger(_ account: Account) {
        enlargedCodeDetent = .medium
        enlargedAccount = account
    }

    private func handleSpotlightActivity(_ activity: NSUserActivity) {
        guard let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
              let accountId = UUID(uuidString: identifier),
              let account = allAccounts.first(where: { $0.id == accountId })
        else { return }

        viewModel.selectedProfileId = account.profileId
        enlargedAccount = account
    }

    private func normalizeSortOrders() {
        let uniqueOrders = Set(profiles.map(\.sortOrder))
        guard uniqueOrders.count < profiles.count else { return }
        let sorted = profiles.sorted { $0.createdAt < $1.createdAt }
        for (index, profile) in sorted.enumerated() {
            profile.sortOrder = index
        }
    }
}

// MARK: - List body (owns the timer so parent toolbar doesn't re-render on ticks)

private struct AccountListBody: View {
    @Environment(\.profileTint) private var profileTint
    @Environment(CodeService.self) private var codeService

    let viewModel: AccountListViewModel
    let allAccounts: [Account]
    let profiles: [Profile]
    let searchText: String
    let onCopy: (Account) -> Void
    let onIncrement: (Account) -> Void
    let onViewLarger: (Account) -> Void
    let onEdit: (Account) -> Void
    let onDelete: (Account) -> Void
    let onShowAddAccount: () -> Void

    @Environment(\.isSearching) private var isSearching
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppClock.self) private var clock

    private var currentAccounts: [Account] {
        viewModel.accountsForCurrentProfile(from: allAccounts)
    }

    private var sections: [SearchSection] {
        viewModel.searchSections(
            from: allAccounts, profiles: profiles, searchText: searchText
        )
    }

    var body: some View {
        Group {
            if !isSearching, currentAccounts.isEmpty {
                ContentUnavailableView {
                    Label("No Accounts", systemImage: "key.fill")
                } description: {
                    Text("Add an account to get started.")
                } actions: {
                    Button("Add Account") { onShowAddAccount() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .tint(profileTint)
                }
                .safeAreaPadding(.bottom, 80)
            } else if isSearching, !searchText.isEmpty, sections.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                List {
                    if isSearching {
                        ForEach(sections) { section in
                            Section(section.profileName) {
                                ForEach(section.hits) { hit in
                                    accountRowButton(
                                        for: hit.account,
                                        issuerHighlight: hit.issuerHighlight,
                                        nameHighlight: hit.nameHighlight
                                    )
                                }
                            }
                            .listSectionSeparator(.visible)
                            .environment(\.profileTint, profileColor(for: section.id))
                        }
                    } else {
                        ForEach(currentAccounts) { account in
                            accountRowButton(for: account)
                        }
                    }
                }
                .listStyle(.inset)
                .animation(reduceMotion ? .none : .easeInOut(duration: 0.25), value: isSearching)
            }
        }
        .onChange(of: clock.now) { _, newDate in
            #if DEMO_ENABLED
                if LaunchMode.demo == .video {
                    let tickingAccounts = allAccounts.filter { $0.profileId != Profile.defaultID }
                    codeService.refreshCodes(for: tickingAccounts, at: newDate)
                    return
                }
            #endif
            codeService.refreshCodes(for: allAccounts, at: newDate)
        }
        #if DEMO_ENABLED
        .onChange(of: viewModel.selectedProfileId) {
                if LaunchMode.demo == .video {
                    if viewModel.selectedProfileId == Profile.defaultID {
                        clock.pause()
                        clock.setDate(clock.referenceDate)
                    } else {
                        clock.resume()
                    }
                }
            }
        #endif
            .onAppear {
                codeService.refreshCodes(for: allAccounts, at: clock.now)
            }
    }

    private func profileColor(for profileId: UUID) -> Color {
        let hex = profiles.first(where: { $0.id == profileId })?.color ?? Profile.defaultColor
        return Color(hex: hex)
    }

    private func accountRowButton(
        for account: Account,
        issuerHighlight: SearchHit.Highlight? = nil,
        nameHighlight: SearchHit.Highlight? = nil
    ) -> AccountRowButton {
        AccountRowButton(
            account: account,
            code: codeService.code(for: account.id),
            currentDate: clock.now,
            isCopied: codeService.copiedAccountId == account.id,
            issuerHighlight: issuerHighlight,
            nameHighlight: nameHighlight,
            onCopy: { onCopy(account) },
            onIncrement: account.type == .hotp ? { onIncrement(account) } : nil,
            onViewLarger: { onViewLarger(account) },
            onEdit: { onEdit(account) },
            onDelete: { onDelete(account) }
        )
    }
}
