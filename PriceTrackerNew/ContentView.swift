import SwiftUI
import SwiftData
import WidgetKit

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

// MARK: - Home View
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Product.sortOrder) var products: [Product]
    
    @State private var urlInput: String = ""
    @State private var isAnalyzing: Bool = false
    @State private var isRefreshing: Bool = false // Track refresh status
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
                    .refreshable {
                        await refreshAllPrices() // Standard pull-to-refresh
                    }
                }
            }
            
            // Loading overlay for bulk refresh
            if isRefreshing {
                VStack {
                    ProgressView("Updating Prices...")
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                }
            }
        }
        .navigationTitle("Gear Tracker")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    Button(action: {
                        Task { await refreshAllPrices() }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isRefreshing)
                    
                    EditButton()
                }
            }
        }
        .sheet(item: $editingProduct) { product in
            EditProductSheet(product: product)
        }
        .onAppear {
            // Auto-refresh when app opens (optional, can be limited to once a day)
            Task { await refreshAllPrices() }
        }
    }
    
    // MARK: - Logic: Refresh All Prices
    private func refreshAllPrices() async {
        guard !products.isEmpty else { return }
        
        await MainActor.run { isRefreshing = true }
        let parser = UniversalParser()
        
        // Use a TaskGroup or simple loop to update each product
        for product in products {
            if let info = await parser.fetchProduct(from: product.urlString) {
                await MainActor.run {
                    product.currentPrice = info.price
                    // If image is missing but now found, update it
                    if product.localImageName == nil, let imgURL = info.imageURL {
                        Task {
                            let local = await ImageStorage.saveImage(from: imgURL, id: product.id)
                            product.localImageName = local
                        }
                    }
                }
            }
        }
        
        await MainActor.run {
            try? modelContext.save()
            isRefreshing = false
            WidgetCenter.shared.reloadAllTimelines() // Sync widget immediately
        }
    }
    
    private var inputSection: some View {
        HStack(spacing: 12) {
            HStack {
                Image(systemName: "link")
                    .foregroundColor(.secondary)
                TextField("Paste link (Shopify/Corbetts/Amazon)...", text: $urlInput)
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
        let productID = UUID()
        
        Task {
            if let info = await parser.fetchProduct(from: urlInput) {
                var localName: String? = nil
                if let imgURL = info.imageURL {
                    localName = await ImageStorage.saveImage(from: imgURL, id: productID)
                }
                
                let newProduct = Product(
                    name: info.name,
                    urlString: urlInput,
                    imageURL: info.imageURL,
                    localImageName: localName,
                    targetPrice: info.price,
                    currentPrice: info.price,
                    sortOrder: products.count
                )
                newProduct.id = productID
                
                await MainActor.run {
                    modelContext.insert(newProduct)
                    urlInput = ""
                    isAnalyzing = false
                    WidgetCenter.shared.reloadAllTimelines()
                }
            } else {
                await MainActor.run { isAnalyzing = false }
            }
        }
    }

    private func deleteItems(offsets: IndexSet) {
        for index in offsets {
            let product = products[index]
            if let localName = product.localImageName {
                ImageStorage.deleteImage(fileName: localName)
            }
            modelContext.delete(product)
        }
        updateSortOrders()
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    private func moveItems(from source: IndexSet, to destination: Int) {
        var revisedItems = products
        revisedItems.move(fromOffsets: source, toOffset: destination)
        for (index, item) in revisedItems.enumerated() {
            item.sortOrder = index
        }
        WidgetCenter.shared.reloadAllTimelines()
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
                        WidgetCenter.shared.reloadAllTimelines()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Settings View
struct SettingsView: View {
    var body: some View {
        List {
            Section("Compatibility") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "checkmark.seal.fill").foregroundColor(.blue)
                        Text("Supported Sites").font(.headline)
                    }
                    Divider()
                    Label("Amazon (.ca, .com)", systemImage: "cart.fill").foregroundColor(.orange)
                    Label("Shopify Stores", systemImage: "cart.fill").foregroundColor(.green)
                    Label("Corbetts.com", systemImage: "cart.fill").foregroundColor(.blue)
                }
                .padding(.vertical, 8)
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
    
    var isPriceDropped: Bool { product.currentPrice < product.initialPrice }
    
    var cleanDomain: String {
        guard let url = URL(string: product.urlString), let host = url.host else { return "Unknown" }
        return host.replacingOccurrences(of: "www.", with: "")
    }
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(isPriceDropped ? Color.red.opacity(0.1) : Color.blue.opacity(0.1))
                    .frame(width: 50, height: 50)
                
                if let localName = product.localImageName, 
                   let localURL = ImageStorage.getLocalURL(for: localName),
                   let uiImage = UIImage(contentsOfFile: localURL.path) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 50, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    Image(systemName: isPriceDropped ? "arrow.down.circle.fill" : "snowboard")
                        .font(.title2)
                        .foregroundColor(isPriceDropped ? .red : .blue)
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(product.name).font(.system(.body, design: .rounded)).fontWeight(.semibold).lineLimit(2)
                Text(cleanDomain).font(.caption).foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("$\(product.currentPrice, specifier: "%.2f")")
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(isPriceDropped ? .red : .primary)
                    .lineLimit(1)
                
                if isPriceDropped {
                    Text("\(discountPercentage)% OFF")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .cornerRadius(4)
                }
                
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
}
