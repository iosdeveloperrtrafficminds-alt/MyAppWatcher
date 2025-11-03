import Foundation
import RealmSwift

// НОВЫЙ Enum для результата
enum AppUpdateResult {
    case changed(from: AppStatus, to: AppStatus)
    case unchanged
    case error
}

// Эта операция проверяет одно приложение
class AppUpdateOperation: Operation {
    let appKey: String
    
    // ИЗМЕНЕНИЕ: onCompletion теперь передает наш новый Enum
    var onCompletion: ((AppUpdateResult) -> Void)?
    
    init(appKey: String) {
        self.appKey = appKey
    }
    
    override func main() {
        if isCancelled { return }
        
        guard let realm = try? Realm(configuration: RealmProvider.configuration, queue: nil),
              let app = realm.object(ofType: AppEntity.self, forPrimaryKey: appKey),
              let url = app.appStoreURL else {
            DispatchQueue.main.async { self.onCompletion?(.error) }
            return
        }
        
        let oldStatus = app.status // Запоминаем старый статус
        var newStatus: AppStatus = .unavailable
        
        // --- СИНХРОННЫЙ СЕТЕВОЙ ЗАПРОС ---
        let semaphore = DispatchSemaphore(value: 0)
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 15
        
        URLSession.shared.dataTask(with: request) { _, response, _ in
            if let httpResponse = response as? HTTPURLResponse {
                print("DEBUG: App URL: \(url.absoluteString) | Status Code: \(httpResponse.statusCode)")
                switch httpResponse.statusCode {
                case 200...399: newStatus = .live
                case 404: newStatus = .removed
                default: newStatus = .unavailable
                }
            } else {
                newStatus = .unavailable
            }
            semaphore.signal()
        }.resume()
        semaphore.wait()
        // --- КОНЕЦ СИНХРОННОГО ЗАПРОСА ---

        if isCancelled { return }
        
        var finalResult: AppUpdateResult = .unchanged
        
        if newStatus != .unavailable {
            if app.status != newStatus {
                try? realm.write {
                    app.status = newStatus
                    app.lastCheckedAt = Date()
                    
                    if newStatus == .removed {
                                           app.banDate = Date()
                                       }
                                       if newStatus == .live {
                                           app.banDate = nil
                                       }
                    // Создание ChangeEvent можно добавить сюда, если нужно
                }
                finalResult = .changed(from: oldStatus, to: newStatus) // Сообщаем об изменении
            } else {
                try? realm.write {
                    app.lastCheckedAt = Date()
                }
                finalResult = .unchanged // Сообщаем, что ничего не поменялось
            }
        } else {
            finalResult = .error // Сообщаем об ошибке
        }
        
        // Возвращаем результат на главный поток
        DispatchQueue.main.async {
            self.onCompletion?(finalResult)
        }
    }
}
