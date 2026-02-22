import UIKit
import Social
import SwiftUI
import SwiftData
import UniformTypeIdentifiers

class ShareViewController: SLComposeServiceViewController {
    // 1. 配置相同的共享容器
    lazy var sharedModelContainer: ModelContainer = {
        let schema = Schema([Product.self])
        let config = ModelConfiguration(groupContainer: .identifier("group.ahazyc.PriceTracker"))
        return try! ModelContainer(for: schema, configurations: [config])
    }()

    override func isContentValid() -> Bool {
        // 只有在能获取到 URL 时才允许点击“发送” (这里简单返回 true，在 didSelectPost 逻辑中校验)
        return true
    }

    override func didSelectPost() {
        // 2. 获取 Safari 传来的网页 URL
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachment = item.attachments?.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.url.identifier) }) else {
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            return
        }

        attachment.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { (urlData, error) in
            guard let url = urlData as? URL else {
                self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
                return
            }

            let urlString = url.absoluteString
            let parser = UniversalParser()

            // 3. 执行异步解析并保存
            Task {
                if let info = await parser.fetchProduct(from: urlString) {
                    let newProduct = Product(
                        name: info.name,
                        urlString: urlString,
                        targetPrice: info.price,
                        currentPrice: info.price
                    )
                    
                    // 4. 插入到共享数据库
                    await MainActor.run {
                        self.sharedModelContainer.mainContext.insert(newProduct)
                        try? self.sharedModelContainer.mainContext.save()
                        
                        // 5. 完成并关闭插件
                        self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
                    }
                } else {
                    // 解析失败时的简单处理：直接关闭
                    await MainActor.run {
                        self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
                    }
                }
            }
        }
    }

    override func configurationItems() -> [Any]! {
        return []
    }
}
