import Foundation
import RealmSwift

enum RealmProvider {
    static let appGroupId = "group.com.MyAppWatcher"

    static var configuration: Realm.Configuration {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else {
            // Эта ошибка теперь не должна возникать, но оставим ее как страховку
            fatalError("Не удалось получить доступ к контейнеру App Group. Проверьте идентификатор и настройки таргета.")
        }
        
        let realmURL = containerURL.appendingPathComponent("shared.realm")
        
        var config = Realm.Configuration.defaultConfiguration
        config.fileURL = realmURL
        
        // Важно: Укажем версию схемы, чтобы избежать проблем с миграцией
        // Если вы добавляли поля, увеличьте эту цифру
        config.schemaVersion = 1
        config.migrationBlock = { migration, oldSchemaVersion in
            if oldSchemaVersion < 1 {
                // Миграций пока нет, но заготовка полезна
            }
        }
        
        return config
    }
    
    static func realm() async throws -> Realm {
        return try await Realm(configuration: configuration, actor: MainActor.shared)
    }
}
