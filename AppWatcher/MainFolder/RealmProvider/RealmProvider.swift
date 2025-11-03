import Foundation
import RealmSwift

enum RealmProvider {
    // ID вашей App Group из Шага 1
    static let appGroupId = "group.com.AppWatcher" 

    static var configuration: Realm.Configuration {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else {
            fatalError("Не удалось получить доступ к контейнеру App Group. Проверьте идентификатор.")
        }
        
        let realmURL = containerURL.appendingPathComponent("shared.realm")
        
        var config = Realm.Configuration.defaultConfiguration
        config.fileURL = realmURL
        
        return config
    }
    
    // Удобный метод для асинхронного доступа к Realm с общей конфигурацией
    static func realm() async throws -> Realm {
        return try await Realm(configuration: configuration, actor: MainActor.shared)
    }
}
