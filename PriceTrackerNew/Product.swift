import Foundation
import SwiftData

@Model
class Product {
    var id: UUID
    var name: String
    var urlString: String
    var targetPrice: Double
    var currentPrice: Double
    var addedDate: Date
    
    init(name: String, urlString: String, targetPrice: Double, currentPrice: Double) {
        self.id = UUID()
        self.name = name
        self.urlString = urlString
        self.targetPrice = targetPrice
        self.currentPrice = currentPrice
        self.addedDate = Date()
    }
}
