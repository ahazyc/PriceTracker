import Foundation
import UIKit

struct ImageStorage {
    static let appGroupIdentifier = "group.ahazyc.PriceTracker"
    
    // 🚀 Improved: Explicitly use Library/Caches for shared data
    static var sharedContainerURL: URL? {
        guard let baseURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else { return nil }
        let cachesURL = baseURL.appendingPathComponent("Library/Caches", isDirectory: true)
        
        // Ensure the Caches directory exists
        try? FileManager.default.createDirectory(at: cachesURL, withIntermediateDirectories: true)
        return cachesURL
    }
    
    static func saveImage(from urlString: String, id: UUID) async -> String? {
        guard let url = URL(string: urlString),
              let storageURL = sharedContainerURL else { 
            print("DEBUG: [ImageStorage] Failed to get shared container URL")
            return nil 
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let fileName = "\(id.uuidString).jpg"
            let fileURL = storageURL.appendingPathComponent(fileName)
            
            try data.write(to: fileURL)
            print("DEBUG: [ImageStorage] SUCCESS: Saved to \(fileURL.path)")
            return fileName
        } catch {
            print("DEBUG: [ImageStorage] ERROR: \(error)")
            return nil
        }
    }
    
    static func getLocalURL(for fileName: String) -> URL? {
        return sharedContainerURL?.appendingPathComponent(fileName)
    }
    
    static func deleteImage(fileName: String) {
        guard let fileURL = getLocalURL(for: fileName) else { return }
        try? FileManager.default.removeItem(at: fileURL)
    }
}
