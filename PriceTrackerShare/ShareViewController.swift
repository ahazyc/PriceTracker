import UIKit
import Social
import SwiftUI
import SwiftData
import UniformTypeIdentifiers

class ShareViewController: SLComposeServiceViewController {
    lazy var sharedModelContainer: ModelContainer = {
        let schema = Schema([Product.self])
        let config = ModelConfiguration(groupContainer: .identifier("group.ahazyc.PriceTracker"))
        return try! ModelContainer(for: schema, configurations: [config])
    }()

    override func isContentValid() -> Bool {
        return true
    }

    override func didSelectPost() {
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

            Task {
                if let info = await parser.fetchProduct(from: urlString) {
                    let newProduct = Product(
                        name: info.name,
                        urlString: urlString,
                        imageURL: info.imageURL, // Pass imageURL from parser
                        targetPrice: info.price,
                        currentPrice: info.price
                    )
                    
                    await MainActor.run {
                        self.sharedModelContainer.mainContext.insert(newProduct)
                        try? self.sharedModelContainer.mainContext.save()
                        self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
                    }
                } else {
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
