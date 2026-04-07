import Foundation
@testable import Sesame
import Testing

@MainActor
struct AccountListViewModelTests {
    private func makeAccount(
        issuer: String = "Test",
        name: String = "user@test.com",
        profileId: UUID = Profile.defaultID,
        displayIssuer: String? = nil,
        displayName: String? = nil
    ) -> Account {
        Account(
            profileId: profileId,
            issuer: issuer,
            displayIssuer: displayIssuer,
            name: name,
            displayName: displayName
        )
    }

    // MARK: - Search Filtering

    @Test("Search filters by issuer name case-insensitively")
    func searchFiltersByIssuer() {
        let vm = AccountListViewModel()
        let accounts = [
            makeAccount(issuer: "GitHub", name: "user@github.com"),
            makeAccount(issuer: "Google", name: "user@google.com"),
            makeAccount(issuer: "Slack", name: "user@slack.com"),
        ]
        let profiles = [Profile.makeDefault()]

        let results = vm.searchSections(from: accounts, profiles: profiles, searchText: "git")
        let matched = results.flatMap(\.hits)

        #expect(matched.count == 1)
        #expect(matched[0].account.issuer == "GitHub")
    }

    @Test("Search filters by account name")
    func searchFiltersByName() {
        let vm = AccountListViewModel()
        let accounts = [
            makeAccount(issuer: "GitHub", name: "alice@example.com"),
            makeAccount(issuer: "Google", name: "bob@example.com"),
        ]
        let profiles = [Profile.makeDefault()]

        let results = vm.searchSections(from: accounts, profiles: profiles, searchText: "alice")
        let matched = results.flatMap(\.hits)

        #expect(matched.count == 1)
        #expect(matched[0].account.name == "alice@example.com")
    }

    @Test("Cross-profile search returns current profile results first")
    func crossProfileSearchOrder() {
        let workProfileId = UUID()
        let vm = AccountListViewModel()
        vm.selectedProfileId = Profile.defaultID

        let accounts = [
            makeAccount(issuer: "GitHub", name: "personal@github.com", profileId: Profile.defaultID),
            makeAccount(issuer: "GitHub", name: "work@github.com", profileId: workProfileId),
        ]
        let profiles = [
            Profile.makeDefault(),
            Profile(id: workProfileId, name: "Work"),
        ]

        let sections = vm.searchSections(from: accounts, profiles: profiles, searchText: "github")

        #expect(sections.count == 2)
        #expect(sections[0].id == Profile.defaultID)
        #expect(sections[0].profileName == "Personal")
        #expect(sections[1].id == workProfileId)
        #expect(sections[1].profileName == "Work")
    }

    @Test("Empty profile returns no accounts")
    func emptyProfile() {
        let vm = AccountListViewModel()
        let emptyProfileId = UUID()
        vm.selectedProfileId = emptyProfileId

        let accounts = [
            makeAccount(issuer: "GitHub", name: "user@github.com", profileId: Profile.defaultID),
        ]

        let result = vm.accountsForCurrentProfile(from: accounts)
        #expect(result.isEmpty)
    }

    @Test("Search uses displayIssuer when set")
    func searchUsesDisplayIssuer() {
        let vm = AccountListViewModel()
        let accounts = [
            makeAccount(issuer: "gh", name: "user@test.com", displayIssuer: "GitHub"),
        ]
        let profiles = [Profile.makeDefault()]

        let results = vm.searchSections(from: accounts, profiles: profiles, searchText: "GitHub")
        #expect(results.flatMap(\.hits).count == 1)
    }

    @Test("Search uses displayName when set")
    func searchUsesDisplayName() {
        let vm = AccountListViewModel()
        let accounts = [
            makeAccount(issuer: "Test", name: "acct", displayName: "alice@example.com"),
        ]
        let profiles = [Profile.makeDefault()]

        let results = vm.searchSections(from: accounts, profiles: profiles, searchText: "alice")
        #expect(results.flatMap(\.hits).count == 1)
    }

    @Test("Empty search text returns all accounts grouped by profile")
    func emptySearchReturnsAllAccounts() {
        let vm = AccountListViewModel()
        let accounts = [makeAccount()]
        let profiles = [Profile.makeDefault()]

        let results = vm.searchSections(from: accounts, profiles: profiles, searchText: "")
        #expect(results.count == 1)
        #expect(results[0].hits.count == 1)
    }

    @Test("Current profile filter returns only matching accounts")
    func accountsForCurrentProfile() {
        let vm = AccountListViewModel()
        let otherId = UUID()

        let accounts = [
            makeAccount(issuer: "A", profileId: Profile.defaultID),
            makeAccount(issuer: "B", profileId: otherId),
            makeAccount(issuer: "C", profileId: Profile.defaultID),
        ]

        let result = vm.accountsForCurrentProfile(from: accounts)
        #expect(result.count == 2)
        #expect(result.allSatisfy { $0.profileId == Profile.defaultID })
    }
}
