import AppIntents
import SwiftData

struct AccountEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Account"
    static var defaultQuery = AccountEntityQuery()

    let id: UUID

    @Property(title: "Issuer")
    var issuer: String

    @Property(title: "Name")
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(issuer)",
            subtitle: "\(name)"
        )
    }

    init(id: UUID, issuer: String, name: String) {
        self.id = id
        self.issuer = issuer
        self.name = name
    }

    init(from account: Account) {
        id = account.id
        issuer = account.effectiveIssuer
        name = account.effectiveName
    }
}

struct AccountEntityQuery: EntityStringQuery {
    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [AccountEntity] {
        let context = SharedModelContainer.shared.mainContext
        let descriptor = FetchDescriptor<Account>(
            predicate: #Predicate { $0.deletedAt == nil }
        )

        let accounts = try context.fetch(descriptor)
        let idSet = Set(identifiers)
        return accounts
            .filter { idSet.contains($0.id) }
            .map { AccountEntity(from: $0) }
    }

    @MainActor
    func suggestedEntities() async throws -> [AccountEntity] {
        let context = SharedModelContainer.shared.mainContext
        let descriptor = FetchDescriptor<Account>(
            predicate: #Predicate { $0.deletedAt == nil }
        )

        let accounts = try context.fetch(descriptor)
        return accounts.map { AccountEntity(from: $0) }
    }

    @MainActor
    func entities(matching string: String) async throws -> [AccountEntity] {
        let context = SharedModelContainer.shared.mainContext
        let descriptor = FetchDescriptor<Account>(
            predicate: #Predicate { $0.deletedAt == nil }
        )

        let accounts = try context.fetch(descriptor)

        return accounts
            .filter { account in
                let issuer = account.effectiveIssuer
                let name = account.effectiveName
                return issuer.localizedStandardContains(string)
                    || name.localizedStandardContains(string)
            }
            .map { AccountEntity(from: $0) }
    }
}
