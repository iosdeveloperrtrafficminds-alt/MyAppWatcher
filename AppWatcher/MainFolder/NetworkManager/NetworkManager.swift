import Foundation

// Эта структура соответствует JSON-ответу от lookup API
struct iTunesLookupResult: Codable {
    let resultCount: Int
    let results: [AppDetails]

    struct AppDetails: Codable {
        let trackId: Int64
        let trackName: String?
        let bundleId: String?
        
        let version: String?
        let currentVersionReleaseDate: String? // Приходит как строка, будем парсить в Date
        let releaseDate: String?
        let releaseNotes: String?
        let description: String?

        let sellerName: String?
        let primaryGenreName: String?
        
        let artworkUrl512: String? // URL иконки
        let screenshotUrls: [String]?
        let ipadScreenshotUrls: [String]?
    }
}

// Файл Network/APIErrors.swift
enum APIError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case appNotFound
    case decodingError(Error)
    case serverError(statusCode: Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Неверный URL запроса."
        case .networkError(let error): return "Ошибка сети: \(error.localizedDescription)"
        case .appNotFound: return "Приложение не найдено в данном регионе."
        case .decodingError: return "Ошибка при обработке ответа от сервера."
        case .serverError(let statusCode): return "Сервер вернул ошибку: \(statusCode)."
        }
    }
}


class iTunesAPIService {
    
    private let session: URLSession
    private let decoder: JSONDecoder
    
    // --- ИЗМЕНЕНИЕ №1: Улучшенная инициализация сессии ---
    init() {
        // Создаем стандартную конфигурацию сессии
        let configuration = URLSessionConfiguration.default
        // Устанавливаем разумный таймаут для запросов
        configuration.timeoutIntervalForRequest = 15.0 // 15 секунд
        
        self.session = URLSession(configuration: configuration)
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }
    
        func lookup(trackId: Int64, country: String) async throws -> iTunesLookupResult.AppDetails {
            // 1. Формируем URL
            var components = URLComponents(string: "https://itunes.apple.com/lookup")!
            components.queryItems = [
                URLQueryItem(name: "id", value: String(trackId)),
                URLQueryItem(name: "country", value: country),
                URLQueryItem(name: "entity", value: "software")
            ]
    
            guard let url = components.url else {
                throw APIError.invalidURL
            }
    
            // 2. Делаем запрос (ИСПРАВЛЕНО)
            let (data, response) = try await session.data(from: url)
    
            // 3. Проверяем ответ сервера
            guard let httpResponse = response as? HTTPURLResponse else {
                // Если response не HTTPURLResponse, что-то совсем пошло не так
                throw APIError.networkError(NSError(domain: "InvalidResponse", code: 0, userInfo: nil))
            }
    
            guard (200...299).contains(httpResponse.statusCode) else {
                throw APIError.serverError(statusCode: httpResponse.statusCode)
            }
    
            if let jsonString = String(data: data, encoding: .utf8) {
                        print("--- RAW JSON RESPONSE for trackId: \(trackId), country: \(country) ---")
                        print(jsonString)
                        print("---------------------------------------")
                    }
    
            // 4. Декодируем JSON
            do {
                let lookupResult = try decoder.decode(iTunesLookupResult.self, from: data)
    
                // 5. Проверяем, что приложение нашлось
                if lookupResult.resultCount > 0, let appDetails = lookupResult.results.first {
                    return appDetails
                } else {
                    throw APIError.appNotFound
                }
            } catch {
                throw APIError.decodingError(error)
            }
        }

    /// (Новый метод) Проверяет доступность страницы приложения в App Store.
    func checkStatus(for appURL: URL) async -> AppStatus {
        var request = URLRequest(url: appURL)
        request.httpMethod = "HEAD"
        // --- ИЗМЕНЕНИЕ №2: Явно отключаем кэширование для этого запроса ---
        // Мы всегда хотим получить самый свежий статус, а не ответ из кэша.
        request.cachePolicy = .reloadIgnoringLocalCacheData

        do {
            let (_, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return .unavailable
            }
            
            print("DEBUG: App URL: \(appURL.absoluteString) | Status Code: \(httpResponse.statusCode)")

            switch httpResponse.statusCode {
            case 200...399:
                return .live
            case 404:
                return .removed
            default:
                return .unavailable
            }
        } catch {
            print("DEBUG: Network error checking status for \(appURL.absoluteString): \(error.localizedDescription)")
            return .unavailable
        }
    }
}
