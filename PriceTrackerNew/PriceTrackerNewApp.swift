import SwiftUI
import SwiftData

@main
struct PriceTrackerNewApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Product.self])
        
        // Try to use the App Group first
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            groupContainer: .identifier("group.ahazyc.PriceTracker")
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // FALLBACK: If migration fails or App Group is unavailable, 
            // try to use a default local store to prevent the app from crashing.
            print("ERROR: SwiftData initialization failed: \(error). Falling back to local store.")
            
            let fallbackConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            do {
                return try ModelContainer(for: schema, configurations: [fallbackConfiguration])
            } catch {
                // If all else fails, use in-memory store as a last resort
                return try! ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
