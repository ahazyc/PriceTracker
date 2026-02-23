import Foundation
import UIKit

struct ImageStorage {
    static let appGroupIdentifier = "group.ahazyc.PriceTracker"
    
    // Get the base URL for the shared App Group container
    static var sharedContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }
    
    // Save image data to the shared container and return the unique filename
    static func saveImage(from urlString: String, id: UUID) async -> String? {
        guard let url = URL(string: urlString),
              let sharedURL = sharedContainerURL else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let fileName = "\(id.uuidString).jpg"
            let fileURL = sharedURL.appendingPathComponent(fileName)
            
            try data.write(to: fileURL)
            print("DEBUG: [ImageStorage] Image saved to \(fileName)")
            return fileName
        } catch {
            print("DEBUG: [ImageStorage] Failed to save image: \(error)")
            return nil
        }
    }
    
    // Get the local URL for a saved image
    static func getLocalURL(for fileName: String) -> URL? {
        return sharedContainerURL?.appendingPathComponent(fileName)
    }
    
    // Delete image when product is removed
    static func deleteImage(fileName: String) {
        guard let fileURL = getLocalURL(for: fileName) else { return }
        try? FileManager.default.removeItem(at: fileURL)
    }
}
