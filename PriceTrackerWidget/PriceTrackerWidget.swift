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
    private func getContainer() -> ModelContainer? {
        let schema = Schema([Product.self])
        let config = ModelConfiguration(groupContainer: .identifier("group.ahazyc.PriceTracker"))
        return try? ModelContainer(for: schema, configurations: [config])
    }

    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), productEntries: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        completion(SimpleEntry(date: Date(), productEntries: fetchProducts()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let entries = fetchProducts()
        let timeline = Timeline(entries: [SimpleEntry(date: Date(), productEntries: entries)], policy: .after(Calendar.current.date(byAdding: .minute, value: 15, to: Date())!))
        completion(timeline)
    }

    private func fetchProducts() -> [ProductEntry] {
        guard let container = getContainer() else { return [] }
        let context = ModelContext(container)
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
}

struct ProductCell: View {
    let entry: ProductEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.1))
                    .frame(height: 35)
                
                // 🚀 FIXED: Robust path construction for Widget access
                if let localName = entry.localImageName,
                   let sharedURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.ahazyc.PriceTracker") {
                    let fileURL = sharedURL.appendingPathComponent("Library/Caches").appendingPathComponent(localName)
                    
                    if let uiImage = UIImage(contentsOfFile: fileURL.path) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 35)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    } else {
                        Image(systemName: "snowboard").font(.system(size: 10)).foregroundColor(.blue)
                    }
                } else {
                    Image(systemName: "snowboard").font(.system(size: 10)).foregroundColor(.blue)
                }
            }
            
            Text(entry.name).font(.system(size: 8, weight: .bold)).lineLimit(1)
            
            let status = entry.currentPrice < entry.initialPrice ? "低价" : (entry.currentPrice > entry.initialPrice ? "高价" : "原价")
            let color = entry.currentPrice < entry.initialPrice ? Color.red : (entry.currentPrice > entry.initialPrice ? Color.orange : Color.gray)
            
            Text(status)
                .font(.system(size: 7, weight: .black))
                .foregroundColor(.white)
                .padding(.horizontal, 3)
                .padding(.vertical, 1)
                .background(color)
                .cornerRadius(2)
        }
        .padding(4)
        .background(Color.white.opacity(0.05))
        .cornerRadius(6)
    }
}

struct PriceTrackerWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var columns: [GridItem] {
        switch family {
        case .systemSmall: return [GridItem(.flexible()), GridItem(.flexible())]
        default: return [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            if entry.productEntries.isEmpty {
                Text("No Data").font(.caption2).foregroundColor(.secondary)
            } else {
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(entry.productEntries, id: \.id) { productEntry in
                        ProductCell(entry: productEntry)
                    }
                }
            }
            Spacer(minLength: 0)
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
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
