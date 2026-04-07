import AuthenticationServices
import SwiftData
import SwiftUI

class CredentialProviderViewController: ASCredentialProviderViewController {
    private let appBundleId = Bundle.main.infoDictionary?["AppBundleID"] as! String
    private var keychainService: String { "\(appBundleId).secrets" }
    // AppIdentifierPrefix is injected into Info.plist by Xcode at build time as "<TeamID>."
    private var keychainAccessGroup: String {
        let prefix = Bundle.main.infoDictionary?["AppIdentifierPrefix"] as? String ?? ""
        return "\(prefix)\(appBundleId)"
    }

    private lazy var modelContainer: ModelContainer? = {
        let containerURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: SharedModelContainer.appGroupID)?
            .appending(path: "Sesame.sqlite")
        guard let containerURL else { return nil }
        let config = ModelConfiguration(url: containerURL)
        return try? ModelContainer(for: Account.self, Profile.self, configurations: config)
    }()

    // MARK: - Silent fill (no UI)

    override func provideCredentialWithoutUserInteraction(for credentialRequest: ASCredentialRequest) {
        guard credentialRequest.type == .oneTimeCode,
              let request = credentialRequest as? ASOneTimeCodeCredentialRequest,
              let recordId = request.credentialIdentity.recordIdentifier,
              let accountId = UUID(uuidString: recordId)
        else {
            extensionContext.cancelRequest(withError: ASExtensionError(.failed))
            return
        }

        guard let account = fetchAccount(id: accountId),
              let secret = readSecret(for: accountId),
              let result = generateCode(account: account, secret: secret)
        else {
            extensionContext.cancelRequest(withError: ASExtensionError(.failed))
            return
        }

        let credential = ASOneTimeCodeCredential(code: result)
        extensionContext.completeOneTimeCodeRequest(using: credential)
    }

    // MARK: - Credential list (with UI)

    override func prepareOneTimeCodeCredentialList(for serviceIdentifiers: [ASCredentialServiceIdentifier]) {
        let accounts = fetchAccountsMatching(serviceIdentifiers)

        let listView = CredentialListView(accounts: accounts) { account in
            self.selectAccount(account)
        } onCancel: {
            self.extensionContext.cancelRequest(withError: ASExtensionError(.userCanceled))
        }

        let hostingController = UIHostingController(rootView: listView)
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        hostingController.didMove(toParent: self)
    }

    private func selectAccount(_ account: Account) {
        guard let secret = readSecret(for: account.id),
              let code = generateCode(account: account, secret: secret)
        else {
            extensionContext.cancelRequest(withError: ASExtensionError(.failed))
            return
        }
        let credential = ASOneTimeCodeCredential(code: code)
        extensionContext.completeOneTimeCodeRequest(using: credential)
    }

    // MARK: - Data access

    private func fetchAccount(id: UUID) -> Account? {
        guard let container = modelContainer else { return nil }
        let context = ModelContext(container)
        let predicate = #Predicate<Account> { $0.id == id && $0.deletedAt == nil }
        let descriptor = FetchDescriptor<Account>(predicate: predicate)
        return try? context.fetch(descriptor).first
    }

    private func fetchAccountsMatching(_ serviceIdentifiers: [ASCredentialServiceIdentifier]) -> [Account] {
        guard let container = modelContainer else { return [] }
        let context = ModelContext(container)
        let predicate = #Predicate<Account> { $0.deletedAt == nil && $0.website != nil }
        let descriptor = FetchDescriptor<Account>(predicate: predicate)
        guard let accounts = try? context.fetch(descriptor) else { return [] }

        let requestedDomains = Set(serviceIdentifiers.map { $0.identifier.lowercased() })
        if requestedDomains.isEmpty { return accounts }

        return accounts.filter { account in
            guard let website = account.website?.lowercased() else { return false }
            return requestedDomains.contains(where: { domain in
                domain == website || domain.hasSuffix(".\(website)")
            })
        }
    }

    // MARK: - Keychain

    private func readSecret(for accountId: UUID) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: accountId.uuidString,
            kSecAttrAccessGroup as String: keychainAccessGroup,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let secret = String(data: data, encoding: .utf8)
        else { return nil }

        return secret
    }

    // MARK: - Code generation

    private func generateCode(account: Account, secret: String) -> String? {
        guard let secretData = Base32.decode(secret) else { return nil }

        return OTPGenerator.generate(
            secret: secretData,
            algorithm: account.algorithm,
            digits: account.digits,
            period: account.period,
            timestamp: .now
        )
    }
}

// MARK: - Credential list UI

private struct CredentialListView: View {
    let accounts: [Account]
    let onSelect: (Account) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                if accounts.isEmpty {
                    ContentUnavailableView(
                        "No Matching Accounts",
                        systemImage: "key.fill",
                        description: Text("No accounts match this site.")
                    )
                } else {
                    List(accounts) { account in
                        Button {
                            onSelect(account)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(account.displayIssuer ?? account.issuer)
                                    .font(.headline)
                                Text(account.displayName ?? account.name)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Choose Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
    }
}
