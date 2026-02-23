import WidgetKit
import SwiftUI
import SwiftData

struct ProductEntry {
    let id: UUID
    let name: String
    let currentPrice: Double
    let initialPrice: Double
    let localImageName: String? // Name of the cached file
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
        let entries = fetchProducts()
        completion(SimpleEntry(date: Date(), productEntries: entries))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let entries = fetchProducts()
        let entry = SimpleEntry(date: Date(), productEntries: entries)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
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

struct StatusBadge: View {
    let current: Double
    let initial: Double
    
    var body: some View {
        if current < initial {
            Text("低价").font(.system(size: 8, weight: .bold)).foregroundColor(.white).padding(.horizontal, 4).padding(.vertical, 2).background(Color.red).cornerRadius(3)
        } else if current > initial {
            Text("高价").font(.system(size: 8, weight: .bold)).foregroundColor(.white).padding(.horizontal, 4).padding(.vertical, 2).background(Color.orange).cornerRadius(3)
        } else {
            Text("原价").font(.system(size: 8, weight: .bold)).foregroundColor(.white).padding(.horizontal, 4).padding(.vertical, 2).background(Color.gray).cornerRadius(3)
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
                
                // 🚀 Read from App Group Local Storage
                if let localName = entry.localImageName,
                   let sharedURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.ahazyc.PriceTracker"),
                   let uiImage = UIImage(contentsOfFile: sharedURL.appendingPathComponent(localName).path) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    Image(systemName: "snowboard").font(.system(size: 14)).foregroundColor(.blue)
                }
            }
            
            Text(entry.name).font(.system(size: 9, weight: .medium)).lineLimit(1)
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
        case .systemSmall: return [GridItem(.flexible()), GridItem(.flexible())]
        default: return [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            if entry.productEntries.isEmpty {
                Text("No gear found").font(.caption2).foregroundColor(.secondary)
            } else {
                LazyVGrid(columns: columns, spacing: 8) {
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
        .configurationDisplayName("Gear Grid")
        .description("Offline-first gear tracking.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
