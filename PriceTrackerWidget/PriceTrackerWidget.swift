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
    static var sharedContainer: ModelContainer? = {
        let schema = Schema([Product.self])
        let config = ModelConfiguration(groupContainer: .identifier("group.ahazyc.PriceTracker"))
        return try? ModelContainer(for: schema, configurations: [config])
    }()

    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), productEntries: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        completion(SimpleEntry(date: Date(), productEntries: fetchProducts(limit: 8)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let entries = fetchProducts(limit: 8)
        // Refresh every 15 minutes or when notified
        let timeline = Timeline(entries: [SimpleEntry(date: Date(), productEntries: entries)], policy: .atEnd)
        completion(timeline)
    }

    private func fetchProducts(limit: Int) -> [ProductEntry] {
        guard let container = Self.sharedContainer else { return [] }
        let context = ModelContext(container)
        
        // 🚀 Fix: Use sortOrder to match Main App exactly
        let descriptor = FetchDescriptor<Product>(sortBy: [SortDescriptor(\.sortOrder, order: .forward)])
        
        do {
            let products = try context.fetch(descriptor)
            print("DEBUG: [Widget] Fetched \(products.count) products from DB")
            return products.prefix(limit).map { 
                ProductEntry(
                    id: $0.id, 
                    name: $0.name, 
                    currentPrice: $0.currentPrice, 
                    initialPrice: $0.initialPrice, 
                    localImageName: $0.localImageName
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

struct ProductSquareCell: View {
    let entry: ProductEntry?
    
    var body: some View {
        VStack(spacing: 2) {
            if let entry = entry {
                let isLow = entry.currentPrice < entry.initialPrice
                
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
                
                Text(isLow ? "SALE" : "BASE")
                    .font(.system(size: 6, weight: .heavy))
                    .foregroundColor(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(isLow ? Color.red : Color.blue)
                    .cornerRadius(2)
            } else {
                // 🚀 Improved: Visible Placeholder for empty slots
                VStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 10))
                    Text("Empty")
                        .font(.system(size: 6))
                }
                .foregroundColor(.gray.opacity(0.3))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(entry != nil ? (entry!.currentPrice < entry!.initialPrice ? Color.red.opacity(0.08) : Color.blue.opacity(0.03)) : Color.clear)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(entry != nil ? (entry!.currentPrice < entry!.initialPrice ? Color.red.opacity(0.4) : Color.blue.opacity(0.2)) : Color.gray.opacity(0.1), lineWidth: 1)
        )
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
                VStack(spacing: 4) {
                    Image(systemName: "cart.badge.plus").font(.title2)
                    Text("Add gear in App").font(.system(size: 10))
                }.foregroundColor(.secondary)
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
        .configurationDisplayName("Gear Tracker")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}
