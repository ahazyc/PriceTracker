import Foundation

struct ProductInfo {
    let name: String
    let price: Double
    let imageURL: String?
}

class UniversalParser {
    func fetchProduct(from urlString: String) async -> ProductInfo? {
        print("DEBUG: [Parser] 开始解析 URL: \(urlString)")
        
        if urlString.contains("products/") {
            let baseParams = urlString.components(separatedBy: "?")[0]
            let jsonURL = baseParams + ".js"
            if let info = await fetchViaShopifyJSON(jsonURL) {
                return info
            }
        }
        
        if urlString.contains("corbetts.com") {
            print("DEBUG: [Parser] 进入 Corbetts 专用解析器")
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
                let name = json["title"] as? String ?? "未知商品"
                let priceRaw = json["price"] as? Double ?? 0.0
                return ProductInfo(name: name, price: priceRaw / 100.0, imageURL: nil)
            }
        } catch {
            print("DEBUG: [Shopify] 解析失败: \(error)")
        }
        return nil
    }
    
    private func fetchViaCorbettsHTML(_ urlString: String) async -> ProductInfo? {
        guard let url = URL(string: urlString) else { return nil }
        do {
            print("DEBUG: [Corbetts] 正在请求 HTML 数据...")
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let html = String(data: data, encoding: .utf8) else { 
                print("DEBUG: [Corbetts] 无法将 Data 转换为 UTF8 字符串")
                return nil 
            }
            
            print("DEBUG: [Corbetts] HTML 下载成功，长度: \(html.count)")

            // 策略 1: 查找 "Now: CAD $1,149.99"
            // 策略 2: 查找 "CAD $1,149.99"
            // 策略 3: 查找 "$1,149.99"
            let patterns = [
                "Now: CAD \\$([0-9,.]+)",
                "CAD \\$([0-9,.]+)",
                "\\$([0-9,.]+)"
            ]
            
            var extractedPrice: Double = 0.0
            let range = NSRange(html.startIndex..<html.endIndex, in: html)

            for pattern in patterns {
                let regex = try NSRegularExpression(pattern: pattern, options: [])
                if let match = regex.firstMatch(in: html, options: [], range: range) {
                    if let pRange = Range(match.range(at: 1), in: html) {
                        let pStr = html[pRange].replacingOccurrences(of: ",", with: "")
                        if let price = Double(pStr), price > 0 {
                            extractedPrice = price
                            print("DEBUG: [Corbetts] 使用模式 [\(pattern)] 成功提取价格: \(extractedPrice)")
                            break
                        }
                    }
                }
            }
            
            // 提取名称
            let titlePattern = "<title>(.*?)</title>"
            let titleRegex = try NSRegularExpression(pattern: titlePattern, options: [.caseInsensitive])
            var extractedName = "Corbetts 商品"
            if let match = titleRegex.firstMatch(in: html, options: [], range: range) {
                if let nRange = Range(match.range(at: 1), in: html) {
                    extractedName = String(html[nRange])
                        .replacingOccurrences(of: " - Corbetts", with: "")
                        .replacingOccurrences(of: "&amp;", with: "&")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    print("DEBUG: [Corbetts] 提取名称: \(extractedName)")
                }
            }
            
            if extractedPrice > 0 {
                return ProductInfo(name: extractedName, price: extractedPrice, imageURL: nil)
            } else {
                print("DEBUG: [Corbetts] 未能在页面中找到任何有效的价格模式")
            }
        } catch {
            print("DEBUG: [Corbetts] 解析过程发生异常: \(error)")
        }
        return nil
    }
    
    private func fetchViaHTML(_ urlString: String) async -> ProductInfo? { return nil }
}
