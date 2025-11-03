import Foundation

struct AppURLParser {
    
    // Возвращает (trackId, country) или nil, если распарсить не удалось
    static func parse(url: String) -> (trackId: Int64, country: String)? {
        // Регулярное выражение для поиска ID и кода страны в URL
        // Оно ищет:
        // - опционально /<2 буквы>/
        // - /id<число>
        let pattern = #"/([a-z]{2}/)?app/.*/id(\d+)"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }
        
        let range = NSRange(url.startIndex..<url.endIndex, in: url)
        
        guard let match = regex.firstMatch(in: url, options: [], range: range) else {
            // Если ссылка не подошла, может, пользователь ввел просто ID?
            if let trackId = Int64(url) {
                // Используем регион устройства по умолчанию
                let defaultCountry = Locale.current.region?.identifier.lowercased() ?? "us"
                return (trackId, defaultCountry)
            }
            return nil
        }
        
        // Извлекаем ID
        guard let idRange = Range(match.range(at: 2), in: url),
              let trackId = Int64(url[idRange]) else {
            return nil
        }
        
        // Извлекаем код страны (он опциональный)
        var country = Locale.current.region?.identifier.lowercased() ?? "us"
        if let countryRange = Range(match.range(at: 1), in: url) {
            // Убираем слэш в конце, если он есть
            country = String(url[countryRange]).replacingOccurrences(of: "/", with: "")
        }
        
        return (trackId, country)
    }
    
    static func parse(multiLineText: String) -> [(trackId: Int64, country: String)] {
           // Разбиваем текст на строки, убираем пустые
           let lines = multiLineText.split(whereSeparator: \.isNewline).map(String.init)
           
           // Для каждой строки вызываем наш старый парсер
           let parsedPairs = lines.compactMap { parse(url: $0) }
           
           // Убираем дубликаты, чтобы не искать одно и то же приложение дважды
           var uniquePairs = [(trackId: Int64, country: String)]()
           var seen = Set<String>()
           
           for pair in parsedPairs {
               let key = "\(pair.trackId)-\(pair.country)"
               if !seen.contains(key) {
                   uniquePairs.append(pair)
                   seen.insert(key)
               }
           }
           
           return uniquePairs
       }
}
