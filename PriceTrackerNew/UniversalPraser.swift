import Foundation

struct ProductInfo {
    let name: String
    let price: Double
    let imageURL: String?
}

class UniversalParser {
    func fetchProduct(from urlString: String) async -> ProductInfo? {
        print("DEBUG: [Parser] Starting analysis for URL: \(urlString)")
        
        if urlString.contains("products/") {
            let baseParams = urlString.components(separatedBy: "?")[0]
            let jsonURL = baseParams + ".js"
            if let info = await fetchViaShopifyJSON(jsonURL) {
                return info
            }
        }
        
        if urlString.contains("corbetts.com") {
            if let info = await fetchViaCorbettsHTML(urlString) {
                return info
            }
        }
        
        return await fetchViaHTML(urlString)
    }
    
    private func fetchViaShopifyJSON(_ urlString: String) async -> ProductInfo? {
        guard let url = URL(string: urlString) else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let name = json["title"] as? String ?? "Unknown Product"
                let priceRaw = json["price"] as? Double ?? 0.0
                // Shopify: Get featured_image and prefix with https: if needed
                var imgURL = json["featured_image"] as? String
                if let url = imgURL, url.hasPrefix("//") {
                    imgURL = "https:" + url
                }
                return ProductInfo(name: name, price: priceRaw / 100.0, imageURL: imgURL)
            }
        } catch {
            print("DEBUG: [Shopify] Error: \(error)")
        }
        return nil
    }
    
    private func fetchViaCorbettsHTML(_ urlString: String) async -> ProductInfo? {
        guard let url = URL(string: urlString) else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let html = String(data: data, encoding: .utf8) else { return nil }
            let range = NSRange(html.startIndex..<html.endIndex, in: html)

            // 1. Extract Price
            let pricePattern = "Now: CAD \\$([0-9,.]+)"
            let priceRegex = try NSRegularExpression(pattern: pricePattern, options: [])
            var extractedPrice: Double = 0.0
            if let match = priceRegex.firstMatch(in: html, options: [], range: range) {
                if let pRange = Range(match.range(at: 1), in: html) {
                    let pStr = html[pRange].replacingOccurrences(of: ",", with: "")
                    extractedPrice = Double(pStr) ?? 0.0
                }
            }
            
            // 2. Extract Image from OpenGraph (og:image)
            let imgPattern = #"property="og:image" content="(.*?)""#
            let imgRegex = try NSRegularExpression(pattern: imgPattern, options: [.caseInsensitive])
            var extractedImgURL: String? = nil
            if let match = imgRegex.firstMatch(in: html, options: [], range: range) {
                if let iRange = Range(match.range(at: 1), in: html) {
                    extractedImgURL = String(html[iRange])
                }
            }
            
            // 3. Extract Name
            let titlePattern = "<title>(.*?)</title>"
            let titleRegex = try NSRegularExpression(pattern: titlePattern, options: [.caseInsensitive])
            var extractedName = "Corbetts Item"
            if let match = titleRegex.firstMatch(in: html, options: [], range: range) {
                if let nRange = Range(match.range(at: 1), in: html) {
                    extractedName = String(html[nRange]).replacingOccurrences(of: " - Corbetts", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            
            if extractedPrice > 0 {
                return ProductInfo(name: extractedName, price: extractedPrice, imageURL: extractedImgURL)
            }
        } catch {
            print("DEBUG: [Corbetts] Error: \(error)")
        }
        return nil
    }
    
    private func fetchViaHTML(_ urlString: String) async -> ProductInfo? { return nil }
}
