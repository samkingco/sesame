import Foundation
import SwiftData

enum SharedModelContainer {
    static let appGroupID = Bundle.main.infoDictionary?["AppGroupID"] as! String

    static let shared: ModelContainer = {
        #if DEMO_ENABLED
            if LaunchMode.isDemoData {
                let config = ModelConfiguration(isStoredInMemoryOnly: true)
                return try! ModelContainer(
                    for: Account.self, Profile.self,
                    configurations: config
                )
            }
        #endif

        #if APPGROUP_CAPABLE
            if let groupURL = FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
            {
                let containerURL = groupURL.appending(path: "Sesame.sqlite")
                let config = ModelConfiguration(url: containerURL)
                return try! ModelContainer(
                    for: Account.self, Profile.self,
                    configurations: config
                )
            }
        #endif

        // Fallback: standard app container (no shared data with extensions)
        return try! ModelContainer(for: Account.self, Profile.self)
    }()
}
