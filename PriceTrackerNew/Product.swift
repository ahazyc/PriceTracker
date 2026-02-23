import Foundation
import SwiftData

@Model
class Product {
    var id: UUID
    var name: String
    var urlString: String
    var imageURL: String?    // Stores the product image URL
    var initialPrice: Double
    var targetPrice: Double
    var currentPrice: Double
    var addedDate: Date
    
    init(name: String, urlString: String, imageURL: String? = nil, targetPrice: Double, currentPrice: Double) {
        self.id = UUID()
        self.name = name
        self.urlString = urlString
        self.imageURL = imageURL
        self.initialPrice = currentPrice
        self.targetPrice = targetPrice
        self.currentPrice = currentPrice
        self.addedDate = Date()
    }
}
