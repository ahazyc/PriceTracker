import WidgetKit
import SwiftUI
import SwiftData

struct ProductEntry {
    let id: UUID
    let name: String
    let currentPrice: Double
    let initialPrice: Double
    let imageData: Data?
}

struct Provider: TimelineProvider {
    private func getContainer() -> ModelContainer? {
        let schema = Schema([Product.self])
        // Log App Group initialization
        print("DEBUG: [Widget] Initializing ModelContainer with App Group...")
        let config = ModelConfiguration(groupContainer: .identifier("group.ahazyc.PriceTracker"))
        return try? ModelContainer(for: schema, configurations: [config])
    }

    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), productEntries: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        Task {
            let entries = await fetchAndDownloadProducts()
            completion(SimpleEntry(date: Date(), productEntries: entries))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        Task {
            let entries = await fetchAndDownloadProducts()
            print("DEBUG: [Widget] Timeline update triggered. Found \(entries.count) entries.")
            let timeline = Timeline(entries: [SimpleEntry(date: Date(), productEntries: entries)], policy: .atEnd)
            completion(timeline)
        }
    }

    private func fetchAndDownloadProducts() async -> [ProductEntry] {
        guard let container = getContainer() else {
            print("DEBUG: [Widget] ModelContainer FAIL")
            return [] 
        }
        
        let context = ModelContext(container)
        // 🚨 Simplify query: No sorting, just fetch everything to debug
        let descriptor = FetchDescriptor<Product>()
        
        do {
            let products = try context.fetch(descriptor)
            print("DEBUG: [Widget] Successfully fetched \(products.count) products from DB")
            
            var entries: [ProductEntry] = []
            // Limit to 8 items for the grid
            for product in products.prefix(8) {
                var downloadedData: Data? = nil
                if let urlStr = product.imageURL, let url = URL(string: urlStr) {
                    // Timeout-safe download
                    downloadedData = try? Data(contentsOf: url)
                }
                
                entries.append(ProductEntry(
                    id: product.id,
                    name: product.name,
                    currentPrice: product.currentPrice,
                    initialPrice: product.initialPrice,
                    imageData: downloadedData
                ))
            }
            return entries
        } catch {
            print("DEBUG: [Widget] Fetch error: \(error)")
            return []
        }
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let productEntries: [ProductEntry]
}

struct StatusBadge: View {
    let current: Double
    let initial: Double
    
    var body: some View {
        if current < initial {
            Text("低价")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.red)
                .cornerRadius(3)
        } else if current > initial {
            Text("高价")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.orange)
                .cornerRadius(3)
        } else {
            Text("原价")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.gray)
                .cornerRadius(3)
        }
    }
}

struct ProductCell: View {
    let entry: ProductEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.1))
                    .frame(height: 40)
                
                if let data = entry.imageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    Image(systemName: "snowboard")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
            
            Text(entry.name)
                .font(.system(size: 9, weight: .medium))
                .lineLimit(1)
            
            StatusBadge(current: entry.currentPrice, initial: entry.initialPrice)
        }
        .padding(4)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }
}

struct PriceTrackerWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var columns: [GridItem] {
        switch family {
        case .systemSmall:
            return [GridItem(.flexible()), GridItem(.flexible())]
        default:
            return [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
        }
    }

    var body: some View {
        VStack {
            if entry.productEntries.isEmpty {
                VStack {
                    Image(systemName: "tray")
                        .font(.largeTitle)
                    Text("No gear tracked")
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
            } else {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(entry.productEntries, id: \.id) { productEntry in
                        ProductCell(entry: productEntry)
                    }
                }
            }
        }
        .containerBackground(.clear, for: .widget)
    }
}

struct PriceTrackerWidget: Widget {
    let kind: String = "PriceTrackerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            PriceTrackerWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Gear Grid")
        .description("Track gear status with real images.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
