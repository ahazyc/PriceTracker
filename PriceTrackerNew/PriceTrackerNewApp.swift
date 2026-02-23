import SwiftUI
import SwiftData

@main
struct PriceTrackerNewApp: App {
    init() {
        print("************************************************")
        print("🚀 [PRICETRACKER] APP IS STARTING...")
        print("************************************************")
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Product.self])
        
        // 1. First try: Standard App Group
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            groupContainer: .identifier("group.ahazyc.PriceTracker")
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            print("✅ [DEBUG] ModelContainer initialized with App Group.")
            return container
        } catch {
            print("⚠️ [DEBUG] App Group initialization failed: \(error.localizedDescription)")
            
            // 2. Second try: Default local storage (ignores app groups)
            let fallbackConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            do {
                let container = try ModelContainer(for: schema, configurations: [fallbackConfiguration])
                print("✅ [DEBUG] ModelContainer initialized with local storage fallback.")
                return container
            } catch {
                print("❌ [DEBUG] ALL disk storage failed. Using in-memory only.")
                // 3. Final resort: In-memory only (guarantees no crash)
                return try! ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    print("🖼️ [DEBUG] ContentView has appeared.")
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
