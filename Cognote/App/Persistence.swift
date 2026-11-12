import Foundation
import SwiftData

enum AppConfig {
    /// Turn on once the app has the iCloud (CloudKit) capability, which needs a
    /// paid Apple Developer account. See README.md, "Turning on iCloud".
    static let iCloudSyncEnabled = false
}

enum Persistence {
    static let schema = Schema([Space.self, SpaceEntry.self, Tombstone.self])

    static func makeContainer() -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: AppConfig.iCloudSyncEnabled ? .automatic : .none
        )
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not open the local database: \(error)")
        }
    }
}
