import SwiftData
import SwiftUI

struct RecentlyDeletedView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(BackupStore.self) private var backupStore
    @Query(
        filter: #Predicate<Account> { $0.deletedAt != nil },
        sort: \Account.deletedAt, order: .reverse
    ) private var deletedAccounts: [Account]

    @State private var accountToPurge: Account?
    @State private var showPurgeConfirmation = false
    @State private var showDeleteError = false
    @State private var deleteError: String?

    private let keychain: KeychainServiceProtocol
    // Fires every 60s to refresh the "deleted X ago" time-remaining labels
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    @State private var now = Date.now

    init(keychain: KeychainServiceProtocol) {
        self.keychain = keychain
    }

    var body: some View {
        Group {
            if deletedAccounts.isEmpty {
                ContentUnavailableView {
                    Label("No Deleted Accounts", systemImage: "trash.slash")
                } description: {
                    Text("Deleted accounts appear here for 48 hours before permanent removal.")
                }
                .geometryGroup()
                .safeAreaPadding(.bottom, 20)
                .sesameSheetContent()
            } else {
                List {
                    ForEach(deletedAccounts) { account in
                        RecentlyDeletedRow(
                            account: account,
                            timeRemaining: timeRemaining(for: account),
                            onRestore: { restore(account) },
                            onDelete: {
                                accountToPurge = account
                                showPurgeConfirmation = true
                            }
                        )
                        .sesameRowBackground()
                    }
                }
                .listStyle(.insetGrouped)
                .sesameSheetContent()
            }
        }
        .navigationTitle("Recently Deleted")
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(timer) { now = $0 }
        .alert(
            "Delete Permanently?",
            isPresented: $showPurgeConfirmation,
            presenting: accountToPurge
        ) { account in
            Button("Delete Permanently", role: .destructive) {
                permanentlyDelete(account)
            }
            Button("Cancel", role: .cancel) {}
        } message: { account in
            Text("\"\(account.effectiveIssuer)\" will be permanently removed. This cannot be undone.")
        }
        .alert("Delete Failed", isPresented: $showDeleteError) {} message: {
            if let deleteError {
                Text(deleteError)
            }
        }
    }

    private func timeRemaining(for account: Account) -> String? {
        guard let deletedAt = account.deletedAt else { return nil }
        let expiry = deletedAt.addingTimeInterval(PurgeService.gracePeriod)
        let remaining = expiry.timeIntervalSince(now)
        guard remaining > 0 else { return "Expiring soon" }

        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    private func restore(_ account: Account) {
        AccountService.restore(account: account, backupStore: backupStore)
    }

    private func permanentlyDelete(_ account: Account) {
        do {
            try keychain.delete(for: account.id)
        } catch {
            deleteError = error.localizedDescription
            showDeleteError = true
            return
        }
        modelContext.delete(account)
    }
}

// MARK: - Row

private struct RecentlyDeletedRow: View {
    let account: Account
    let timeRemaining: String?
    let onRestore: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(account.effectiveIssuer)
                    .font(.headline)
                Text(account.effectiveName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let timeRemaining {
                Text(timeRemaining)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .swipeActions(edge: .leading) {
            Button("Restore", action: onRestore)
                .tint(.green)
        }
        .swipeActions(edge: .trailing) {
            Button("Delete", role: .destructive, action: onDelete)
        }
        .contextMenu {
            Button("Restore", systemImage: "arrow.uturn.backward", action: onRestore)
            Button("Delete Permanently", systemImage: "trash", role: .destructive, action: onDelete)
        }
    }
}
