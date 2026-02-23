import WidgetKit
import SwiftUI
import SwiftData

// Helper to download images for Widget
extension UIImage {
    static func download(from urlString: String) -> UIImage? {
        guard let url = URL(string: urlString),
              let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }
}

struct ProductEntry {
    let id: UUID
    let name: String
    let currentPrice: Double
    let initialPrice: Double
    let imageData: Data? // Pre-downloaded image data
}

struct Provider: TimelineProvider {
    private func getContainer() -> ModelContainer? {
        let schema = Schema([Product.self])
        let config = ModelConfiguration(groupContainer: .identifier("group.ahazyc.PriceTracker"))
        return try? ModelContainer(for: schema, configurations: [config])
    }

    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), productEntries: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        Task {
            let entries = await fetchAndDownloadProducts(limit: 8)
            let entry = SimpleEntry(date: Date(), productEntries: entries)
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        Task {
            let entries = await fetchAndDownloadProducts(limit: 8)
            let entry = SimpleEntry(date: Date(), productEntries: entries)
            let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }

    // Fetches items from SwiftData and manually downloads their images
    private func fetchAndDownloadProducts(limit: Int) async -> [ProductEntry] {
        guard let container = getContainer() else { return [] }
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Product>(sortBy: [SortDescriptor(\.addedDate, order: .reverse)])
        
        let products = (try? context.fetch(descriptor)) ?? []
        var entries: [ProductEntry] = []
        
        for product in products.prefix(limit) {
            var downloadedData: Data? = nil
            if let urlStr = product.imageURL, let url = URL(string: urlStr) {
                // Manually download image for widget display
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

    var maxItems: Int {
        switch family {
        case .systemSmall: return 4
        case .systemMedium: return 8
        default: return 8
        }
    }

    var body: some View {
        VStack {
            if entry.productEntries.isEmpty {
                Text("No gear tracked")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(entry.productEntries.prefix(maxItems), id: \.id) { productEntry in
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
