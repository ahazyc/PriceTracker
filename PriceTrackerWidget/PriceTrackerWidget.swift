import WidgetKit
import SwiftUI
import SwiftData

struct ProductEntry {
    let id: UUID
    let name: String
    let currentPrice: Double
    let initialPrice: Double
    let localImageName: String?
}

struct Provider: TimelineProvider {
    @MainActor
    private func getContext() -> ModelContext? {
        let schema = Schema([Product.self])
        let config = ModelConfiguration(groupContainer: .identifier("group.ahazyc.PriceTracker"))
        // Force a new container instance to bypass cache
        return try? ModelContainer(for: schema, configurations: [config]).mainContext
    }

    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), productEntries: [], lastSync: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        Task {
            let entries = await fetchProducts()
            completion(SimpleEntry(date: Date(), productEntries: entries, lastSync: Date()))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        Task {
            // Check for the signal from main app (optional, but helps debugging)
            let lastSignal = UserDefaults(suiteName: "group.ahazyc.PriceTracker")?.object(forKey: "last_update_signal") as? Date ?? Date()
            
            let entries = await fetchProducts()
            
            // Create an entry that displays NOW
            let entry = SimpleEntry(date: Date(), productEntries: entries, lastSync: lastSignal)
            
            // Request next update in 15 mins
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            
            completion(timeline)
        }
    }

    @MainActor
    private func fetchProducts() -> [ProductEntry] {
        guard let context = getContext() else { return [] }
        let descriptor = FetchDescriptor<Product>(sortBy: [SortDescriptor(\.sortOrder, order: .forward)])
        
        do {
            let products = try context.fetch(descriptor)
            return products.prefix(8).map { product in
                ProductEntry(
                    id: product.id,
                    name: product.name,
                    currentPrice: product.currentPrice,
                    initialPrice: product.initialPrice,
                    localImageName: product.localImageName
                )
            }
        } catch {
            return []
        }
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let productEntries: [ProductEntry]
    let lastSync: Date
}

struct ProductSquareCell: View {
    let entry: ProductEntry?
    
    var body: some View {
        if let entry = entry {
            let isLow = entry.currentPrice < entry.initialPrice
            VStack(spacing: 2) {
                // Image
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.1))
                        .frame(width: 35, height: 35)
                    
                    if let localName = entry.localImageName,
                       let sharedURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.ahazyc.PriceTracker") {
                        let fileURL = sharedURL.appendingPathComponent("Library/Caches").appendingPathComponent(localName)
                        if let data = try? Data(contentsOf: fileURL), let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 35, height: 35)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        } else {
                            statusIcon(isLow: isLow)
                        }
                    } else {
                        statusIcon(isLow: isLow)
                    }
                }
                
                Text(entry.name)
                    .font(.system(size: 8, weight: .bold))
                    .lineLimit(1)
                    .foregroundColor(.primary)
                
                Text(isLow ? "SALE" : "BASE")
                    .font(.system(size: 6, weight: .heavy))
                    .foregroundColor(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(isLow ? Color.red : Color.blue)
                    .cornerRadius(2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(isLow ? Color.red.opacity(0.08) : Color.blue.opacity(0.03))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isLow ? Color.red.opacity(0.4) : Color.blue.opacity(0.2), lineWidth: 1)
            )
        } else {
            Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    private func statusIcon(isLow: Bool) -> some View {
        Image(systemName: isLow ? "arrow.down.circle.fill" : "minus.circle.fill")
            .font(.system(size: 14))
            .foregroundColor(isLow ? .red : .blue)
    }
}

struct PriceTrackerWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        VStack(spacing: 6) {
            if entry.productEntries.isEmpty {
                Text("No Items").font(.caption2).foregroundColor(.secondary)
            } else {
                if family == .systemSmall {
                    VStack(spacing: 6) {
                        HStack(spacing: 6) {
                            ProductSquareCell(entry: getItem(at: 0))
                            ProductSquareCell(entry: getItem(at: 1))
                        }
                        HStack(spacing: 6) {
                            ProductSquareCell(entry: getItem(at: 2))
                            ProductSquareCell(entry: getItem(at: 3))
                        }
                    }
                } else {
                    VStack(spacing: 6) {
                        HStack(spacing: 6) {
                            ProductSquareCell(entry: getItem(at: 0))
                            ProductSquareCell(entry: getItem(at: 1))
                            ProductSquareCell(entry: getItem(at: 2))
                            ProductSquareCell(entry: getItem(at: 3))
                        }
                        HStack(spacing: 6) {
                            ProductSquareCell(entry: getItem(at: 4))
                            ProductSquareCell(entry: getItem(at: 5))
                            ProductSquareCell(entry: getItem(at: 6))
                            ProductSquareCell(entry: getItem(at: 7))
                        }
                    }
                }
            }
            
            // 🚀 Last Sync Indicator
            HStack {
                Spacer()
                Text(entry.lastSync, style: .time)
                    .font(.system(size: 6))
                    .foregroundColor(.secondary.opacity(0.5))
            }
        }
        .padding(8)
        .containerBackground(for: .widget) { Color(UIColor.systemBackground) }
    }
    
    private func getItem(at index: Int) -> ProductEntry? {
        guard index < entry.productEntries.count else { return nil }
        return entry.productEntries[index]
    }
}

struct PriceTrackerWidget: Widget {
    let kind: String = "PriceTrackerWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            PriceTrackerWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Gear Monitor")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}
