import Foundation

struct ProductInfo {
    let name: String
    let price: Double
    let imageURL: String?
}

class UniversalParser {
    func fetchProduct(from urlString: String) async -> ProductInfo? {
        var finalURLString = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !finalURLString.lowercased().hasPrefix("http://") && !finalURLString.lowercased().hasPrefix("https://") {
            finalURLString = "https://" + finalURLString
        }
        
        print("DEBUG: [Parser] Starting analysis for URL: \(finalURLString)")
        
        if finalURLString.contains("amazon.") {
            if let info = await fetchViaAmazonHTML(finalURLString) { return info }
        }
        
        if finalURLString.contains("products/") {
            let baseParams = finalURLString.components(separatedBy: "?")[0]
            let jsonURL = baseParams + ".js"
            if let info = await fetchViaShopifyJSON(jsonURL) { return info }
        }
        
        if finalURLString.contains("corbetts.com") {
            if let info = await fetchViaCorbettsHTML(finalURLString) { return info }
        }
        
        return await fetchViaHTML(finalURLString)
    }
    
    // ... Amazon and Shopify methods unchanged ...
    private func fetchViaAmazonHTML(_ urlString: String) async -> ProductInfo? {
        guard let url = URL(string: urlString) else { return nil }
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let html = String(data: data, encoding: .utf8) else { return nil }
            let range = NSRange(html.startIndex..<html.endIndex, in: html)

            let pricePatterns = [
                #"class="a-offscreen">\$([0-9,.]+)"#,
                #"\"priceAmount\":([0-9.]+)"#,
                #"id="priceblock_ourprice".*?>\$([0-9,.]+)"#
            ]
            var extractedPrice: Double = 0.0
            for pattern in pricePatterns {
                let regex = try NSRegularExpression(pattern: pattern, options: [])
                if let match = regex.firstMatch(in: html, options: [], range: range) {
                    if let pRange = Range(match.range(at: 1), in: html) {
                        let pStr = html[pRange].replacingOccurrences(of: ",", with: "")
                        extractedPrice = Double(pStr) ?? 0.0
                        if extractedPrice > 0 { break }
                    }
                }
            }
            
            let namePattern = #"id="productTitle".*?>(.*?)</span>"#
            let nameRegex = try NSRegularExpression(pattern: namePattern, options: [.dotMatchesLineSeparators])
            var extractedName = "Amazon Item"
            if let match = nameRegex.firstMatch(in: html, options: [], range: range) {
                if let nRange = Range(match.range(at: 1), in: html) {
                    extractedName = String(html[nRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            
            var extractedImgURL: String? = nil
            let imgPatterns = [
                #"property="og:image" content="(.*?)""#,
                #"data-old-hires="(.*?)""#,
                #"data-a-dynamic-image="\{(.*?):"#,
                #"\"landingImage\":\"(.*?)\""#,
                #"id="landingImage".*?src="(.*?)""#
            ]
            for pattern in imgPatterns {
                let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
                if let match = regex.firstMatch(in: html, options: [], range: range) {
                    if let iRange = Range(match.range(at: 1), in: html) {
                        let candidate = String(html[iRange]).replacingOccurrences(of: "\\/", with: "/")
                        if candidate.hasPrefix("http") {
                            extractedImgURL = candidate
                            break
                        }
                    }
                }
            }
            
            if extractedPrice > 0 {
                return ProductInfo(name: extractedName, price: extractedPrice, imageURL: extractedImgURL)
            }
        } catch {
            print("DEBUG: [Amazon] Parse error: \(error)")
        }
        return nil
    }

    private func fetchViaShopifyJSON(_ urlString: String) async -> ProductInfo? {
        guard let url = URL(string: urlString) else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let name = json["title"] as? String ?? "Unknown Product"
                let priceRaw = json["price"] as? Double ?? 0.0
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

            // 🚀 Improved: Scoped regex to target the "Now" price specifically
            // Corbetts structure usually: "Now: <span class='price price--withoutTax'>CAD $1,149.99</span>"
            // We look for "Now:" followed closely by "CAD $"
            let pricePatterns = [
                #"Now:.*?CAD\s*\$([0-9,.]+)"#,  // Most specific: "Now:... CAD $1149.99"
                #"class="price--withoutTax">CAD\s*\$([0-9,.]+)"#, // Fallback: CSS class
                #"meta property="product:price:amount" content="([0-9.]+)"# // Schema fallback
            ]
            
            var extractedPrice: Double = 0.0
            for pattern in pricePatterns {
                let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
                if let match = regex.firstMatch(in: html, options: [], range: range) {
                    if let pRange = Range(match.range(at: 1), in: html) {
                        let pStr = html[pRange].replacingOccurrences(of: ",", with: "")
                        extractedPrice = Double(pStr) ?? 0.0
                        if extractedPrice > 100 { // Basic sanity check: ski gear shouldn't be $5
                            print("DEBUG: [Corbetts] Found valid price: \(extractedPrice)")
                            break 
                        }
                    }
                }
            }
            
            // Image extraction
            let imgPattern = #"property="og:image" content="(.*?)""#
            let imgRegex = try NSRegularExpression(pattern: imgPattern, options: [.caseInsensitive])
            var extractedImgURL: String? = nil
            if let match = imgRegex.firstMatch(in: html, options: [], range: range) {
                if let iRange = Range(match.range(at: 1), in: html) {
                    extractedImgURL = String(html[iRange])
                }
            }
            
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
            } else {
                print("DEBUG: [Corbetts] Price extraction failed.")
            }
        } catch {
            print("DEBUG: [Corbetts] Error: \(error)")
        }
        return nil
    }
    
    private func fetchViaHTML(_ urlString: String) async -> ProductInfo? { return nil }
}
