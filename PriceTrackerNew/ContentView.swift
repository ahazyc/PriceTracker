import SwiftUI
import SwiftData

// MARK: - 侧边栏项定义
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
                Text("请选择一个选项")
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - 主页视图
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
                inputSection
                    .padding()
                    .background(Color(UIColor.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 5)
                
                if products.isEmpty {
                    ContentUnavailableView(
                        "装备库空空如也",
                        systemImage: "snowboard",
                        description: Text("复制滑雪装备的链接并粘贴到上方开始追踪")
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
        .navigationTitle("装备追踪")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var inputSection: some View {
        HStack(spacing: 12) {
            HStack {
                Image(systemName: "link")
                    .foregroundColor(.secondary)
                TextField("粘贴装备链接 (支持 Shopify/Corbetts)...", text: $urlInput)
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
                    Text("添加")
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

// MARK: - 设置视图
struct SettingsView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.blue)
                            .font(.title3)
                        Text("支持的网站类型")
                            .font(.headline)
                    }
                    
                    Text("目前我们的智能解析引擎支持以下架构：")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Divider()
                    
                    HStack(alignment: .top) {
                        Image(systemName: "cart.fill")
                            .foregroundColor(.orange)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Shopify 官方网站")
                                .font(.system(.body, design: .rounded))
                                .fontWeight(.semibold)
                            Text("例如：Skiis & Biikes, Burton, Salomon 等主流户外品牌官网及第三方零售店。")
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
                            Text("专门针对 Corbetts.com 的价格和名称提取支持。")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 8)
            } header: {
                Text("网站支持")
            } footer: {
                Text("更多网站支持正在开发中...")
            }
        }
        .navigationTitle("设置")
    }
}

// MARK: - 商品卡片视图 (回滚版本)
struct ProductCardView: View {
    let product: Product
    
    var cleanDomain: String {
        guard let url = URL(string: product.urlString),
              let host = url.host else {
            return "未知来源"
        }
        return host.replacingOccurrences(of: "www.", with: "")
    }
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 50, height: 50)
                Image(systemName: "snowboard")
                    .font(.title2)
                    .foregroundColor(.blue)
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
                Text("$\(product.currentPrice, specifier: "%.2f")")
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("实时价格")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(4)
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}
