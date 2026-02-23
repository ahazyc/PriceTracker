import SwiftUI
import SwiftData

// MARK: - Sidebar Item Definition
enum SidebarItem: String, CaseIterable, Identifiable {
    case home = "装备追踪"
    case settings = "设置"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .home: return "snowboard"
        case .settings: return "gear"
        }
    }
}

struct ContentView: View {
    @State private var selection: SidebarItem? = .home
    
    var body: some View {
        NavigationSplitView {
            List(SidebarItem.allCases, selection: $selection) { item in
                NavigationLink(value: item) {
                    Label(item.rawValue, systemImage: item.icon)
                }
            }
            .navigationTitle("菜单")
        } detail: {
            if let selection = selection {
                switch selection {
                case .home:
                    HomeView()
                case .settings:
                    SettingsView()
                }
            } else {
                Text("Select an option")
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Home View
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Product.addedDate, order: .reverse) var products: [Product]
    
    @State private var urlInput: String = ""
    @State private var isAnalyzing: Bool = false
    
    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top input section
                inputSection
                    .padding()
                    .background(Color(UIColor.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 5)
                
                // Product list
                if products.isEmpty {
                    ContentUnavailableView(
                        "Inventory Empty",
                        systemImage: "snowboard",
                        description: Text("Paste a link to start tracking gear")
                    )
                } else {
                    List {
                        ForEach(products) { product in
                            ProductCardView(product: product)
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }
                        .onDelete(perform: deleteItems)
                    }
                    .listStyle(.plain)
                    .padding(.top, 8)
                }
            }
        }
        .navigationTitle("Gear Tracker")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var inputSection: some View {
        HStack(spacing: 12) {
            HStack {
                Image(systemName: "link")
                    .foregroundColor(.secondary)
                TextField("Paste product link (Shopify/Corbetts)...", text: $urlInput)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(10)
            
            Button(action: analyzeURL) {
                if isAnalyzing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(width: 20, height: 20)
                } else {
                    Text("Add")
                        .fontWeight(.bold)
                }
            }
            .disabled(urlInput.isEmpty || isAnalyzing)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(urlInput.isEmpty ? Color.gray.opacity(0.3) : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
    }

    private func analyzeURL() {
        guard !urlInput.isEmpty else { return }
        isAnalyzing = true
        let parser = UniversalParser()
        Task {
            if let info = await parser.fetchProduct(from: urlInput) {
                let newProduct = Product(
                    name: info.name,
                    urlString: urlInput,
                    targetPrice: info.price,
                    currentPrice: info.price
                )
                await MainActor.run {
                    modelContext.insert(newProduct)
                    urlInput = ""
                    isAnalyzing = false
                }
            } else {
                await MainActor.run {
                    isAnalyzing = false
                }
            }
        }
    }

    private func deleteItems(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(products[index])
        }
    }
}

// MARK: - Settings View
struct SettingsView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.blue)
                            .font(.title3)
                        Text("Supported Websites")
                            .font(.headline)
                    }
                    
                    Text("Our engine currently supports the following platforms:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Divider()
                    
                    HStack(alignment: .top) {
                        Image(systemName: "cart.fill")
                            .foregroundColor(.orange)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Shopify Stores")
                                .font(.system(.body, design: .rounded))
                                .fontWeight(.semibold)
                            Text("Including Skiis & Biikes, Burton, Salomon, and many other independent retailers.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    HStack(alignment: .top) {
                        Image(systemName: "cart.fill")
                            .foregroundColor(.green)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Corbetts")
                                .font(.system(.body, design: .rounded))
                                .fontWeight(.semibold)
                            Text("Special support for Corbetts.com product and price extraction.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 8)
            } header: {
                Text("Compatibility")
            } footer: {
                Text("More sites coming soon...")
            }
        }
        .navigationTitle("Settings")
    }
}

// MARK: - Product Card View (Updated with Historical Pricing)
struct ProductCardView: View {
    let product: Product
    
    // Calculate discount percentage relative to the initial recorded price
    var discountPercentage: Int {
        guard product.initialPrice > product.currentPrice, product.initialPrice > 0 else { return 0 }
        let discount = ((product.initialPrice - product.currentPrice) / product.initialPrice) * 100
        return Int(discount)
    }
    
    // Check if the current price represents a drop from the initial price
    var isPriceDropped: Bool {
        product.currentPrice < product.initialPrice
    }
    
    var cleanDomain: String {
        guard let url = URL(string: product.urlString),
              let host = url.host else {
            return "Unknown Source"
        }
        return host.replacingOccurrences(of: "www.", with: "")
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Leading Icon: Changes color and symbol if price drops
            ZStack {
                Circle()
                    .fill(isPriceDropped ? Color.red.opacity(0.1) : Color.blue.opacity(0.1))
                    .frame(width: 50, height: 50)
                Image(systemName: isPriceDropped ? "arrow.down.circle.fill" : "snowboard")
                    .font(.title2)
                    .foregroundColor(isPriceDropped ? .red : .blue)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(product.name)
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .foregroundColor(.primary)
                
                HStack(spacing: 4) {
                    Image(systemName: "globe")
                        .font(.caption2)
                    Text(cleanDomain)
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Pricing Section
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    // Show discount tag if price dropped
                    if isPriceDropped {
                        Text("\(discountPercentage)% OFF")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .cornerRadius(4)
                    }
                    
                    Text("$\(product.currentPrice, specifier: "%.2f")")
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(isPriceDropped ? .red : .primary)
                }
                
                // Display the price at the time of recording
                Text("Recorded: $\(product.initialPrice, specifier: "%.2f")")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}
