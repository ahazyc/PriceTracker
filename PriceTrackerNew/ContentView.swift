import SwiftUI
import SwiftData

// MARK: - Sidebar Item Enum
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

// MARK: - Home View with Management Features
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Product.sortOrder) var products: [Product]
    
    @State private var urlInput: String = ""
    @State private var isAnalyzing: Bool = false
    @State private var editingProduct: Product? = nil
    
    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                inputSection
                    .padding()
                    .background(Color(UIColor.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 5)
                
                if products.isEmpty {
                    ContentUnavailableView(
                        "Inventory Empty",
                        systemImage: "snowboard",
                        description: Text("Paste a gear link to start tracking")
                    )
                } else {
                    List {
                        ForEach(products) { product in
                            ProductCardView(product: product)
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .swipeActions(edge: .leading) {
                                    Button {
                                        editingProduct = product
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.orange)
                                }
                        }
                        .onDelete(perform: deleteItems)
                        .onMove(perform: moveItems)
                    }
                    .listStyle(.plain)
                    .padding(.top, 8)
                }
            }
        }
        .navigationTitle("Gear Tracker")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            EditButton()
        }
        .sheet(item: $editingProduct) { product in
            EditProductSheet(product: product)
        }
    }
    
    private var inputSection: some View {
        HStack(spacing: 12) {
            HStack {
                Image(systemName: "link")
                    .foregroundColor(.secondary)
                TextField("Paste link (Shopify/Corbetts)...", text: $urlInput)
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
                    imageURL: info.imageURL,
                    targetPrice: info.price,
                    currentPrice: info.price,
                    sortOrder: products.count
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
        updateSortOrders()
    }
    
    private func moveItems(from source: IndexSet, to destination: Int) {
        var revisedItems = products
        revisedItems.move(fromOffsets: source, toOffset: destination)
        for (index, item) in revisedItems.enumerated() {
            item.sortOrder = index
        }
    }
    
    private func updateSortOrders() {
        for (index, item) in products.enumerated() {
            item.sortOrder = index
        }
    }
}

// MARK: - Edit Product Sheet
struct EditProductSheet: View {
    @Environment(\.dismiss) var dismiss
    @Bindable var product: Product
    @State private var newName: String = ""
    @State private var newInitialPrice: Double = 0.0
    
    var body: some View {
        NavigationStack {
            Form {
                Section("General Information") {
                    TextField("Product Name", text: $newName)
                }
                
                Section("Historical Reference") {
                    HStack {
                        Text("Recorded Price")
                        Spacer()
                        TextField("Amount", value: $newInitialPrice, format: .number.precision(.fractionLength(2)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    Text("This is the baseline price used to calculate discounts.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                newName = product.name
                newInitialPrice = product.initialPrice
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        product.name = newName
                        product.initialPrice = newInitialPrice
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Settings View showing compatibility
struct SettingsView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.blue)
                            .font(.title3)
                        Text("Supported Sites")
                            .font(.headline)
                    }
                    
                    Text("Current supported e-commerce platforms:")
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
                            Text("Such as Skiis & Biikes, Burton, Salomon and local gear shops.")
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
                            Text("Custom extraction support for Corbetts.com prices.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 8)
            } header: {
                Text("Compatibility")
            } footer: {
                Text("More sites are being added...")
            }
        }
        .navigationTitle("Settings")
    }
}

// MARK: - Product Card View
struct ProductCardView: View {
    let product: Product
    
    var discountPercentage: Int {
        guard product.initialPrice > product.currentPrice, product.initialPrice > 0 else { return 0 }
        let discount = ((product.initialPrice - product.currentPrice) / product.initialPrice) * 100
        return Int(discount)
    }
    
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
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(isPriceDropped ? Color.red.opacity(0.1) : Color.blue.opacity(0.1))
                    .frame(width: 50, height: 50)
                
                if let imageURLString = product.imageURL, let url = URL(string: imageURLString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable()
                                 .aspectRatio(contentMode: .fill)
                                 .frame(width: 50, height: 50)
                                 .clipShape(RoundedRectangle(cornerRadius: 12))
                        case .failure(_), .empty:
                            iconView
                        @unknown default:
                            iconView
                        }
                    }
                } else {
                    iconView
                }
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
            
            VStack(alignment: .trailing, spacing: 4) {
                // Top: Large Current Price
                Text("$\(product.currentPrice, specifier: "%.2f")")
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(isPriceDropped ? .red : .primary)
                    .lineLimit(1)
                
                // Middle: Discount Badge (only if applicable)
                if isPriceDropped {
                    Text("\(discountPercentage)% OFF")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .cornerRadius(4)
                }
                
                // Bottom: Original Recorded Price
                Text("Recorded: $\(product.initialPrice, specifier: "%.2f")")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
    
    private var iconView: some View {
        Image(systemName: isPriceDropped ? "arrow.down.circle.fill" : "snowboard")
            .font(.title2)
            .foregroundColor(isPriceDropped ? .red : .blue)
    }
}
