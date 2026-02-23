import Foundation
import SwiftData

@Model
class Product {
    var id: UUID
    var name: String
    var urlString: String
    var imageURL: String?
    var localImageName: String? // New: Filename of the image in shared storage
    var initialPrice: Double
    var targetPrice: Double
    var currentPrice: Double
    var addedDate: Date
    var sortOrder: Int
    
    init(name: String, urlString: String, imageURL: String? = nil, localImageName: String? = nil, targetPrice: Double, currentPrice: Double, sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.urlString = urlString
        self.imageURL = imageURL
        self.localImageName = localImageName
        self.initialPrice = currentPrice
        self.targetPrice = targetPrice
        self.currentPrice = currentPrice
        self.addedDate = Date()
        self.sortOrder = sortOrder
    }
}
