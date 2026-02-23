import WidgetKit
import SwiftUI
import SwiftData

struct ProductEntry {
    let id: UUID
    let name: String
    let currentPrice: Double
    let initialPrice: Double
}

struct Provider: TimelineProvider {
    static var sharedContainer: ModelContainer? = {
        let schema = Schema([Product.self])
        let config = ModelConfiguration(groupContainer: .identifier("group.ahazyc.PriceTracker"))
        return try? ModelContainer(for: schema, configurations: [config])
    }()

    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), productEntries: Array(repeating: ProductEntry(id: UUID(), name: "Gear", currentPrice: 100, initialPrice: 100), count: 4))
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        completion(SimpleEntry(date: Date(), productEntries: fetchProducts(limit: 8)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        completion(Timeline(entries: [SimpleEntry(date: Date(), productEntries: fetchProducts(limit: 8))], policy: .atEnd))
    }

    private func fetchProducts(limit: Int) -> [ProductEntry] {
        guard let container = Self.sharedContainer else { return [] }
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Product>(sortBy: [SortDescriptor(\.addedDate, order: .reverse)])
        do {
            let products = try context.fetch(descriptor)
            return products.prefix(limit).map { ProductEntry(id: $0.id, name: $0.name, currentPrice: $0.currentPrice, initialPrice: $0.initialPrice) }
        } catch { return [] }
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let productEntries: [ProductEntry]
}

struct ProductSquareCell: View {
    let entry: ProductEntry?
    
    var body: some View {
        if let entry = entry {
            let isLow = entry.currentPrice < entry.initialPrice
            VStack(spacing: 2) {
                Image(systemName: isLow ? "arrow.down.circle.fill" : "minus.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(isLow ? .red : .blue)
                
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
            // 🚀 Added: Distinct border with color difference
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isLow ? Color.red.opacity(0.4) : Color.blue.opacity(0.2), lineWidth: 1)
            )
        } else {
            Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct PriceTrackerWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        VStack(spacing: 6) {
            if entry.productEntries.isEmpty {
                VStack(spacing: 4) {
                    Image(systemName: "plus.square.dashed").font(.title2)
                    Text("No Items").font(.caption2)
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
        .configurationDisplayName("Gear Monitor")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}
