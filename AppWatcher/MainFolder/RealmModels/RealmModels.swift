import Foundation
import RealmSwift

enum AppStatus: String, PersistableEnum {
    case live
    case removed
    case unavailable
}

enum AppOwnership: String, PersistableEnum {
    case mine = "Моё"
    case competitor = "Конкурент"
}

class AppEntity: Object, ObjectKeyIdentifiable {
    @Persisted(primaryKey: true) var compoundKey: String
    @Persisted var trackId: Int64
    @Persisted var country: String
    
    @Persisted var name: String
    @Persisted var version: String
    @Persisted var iconUrl: String?
    @Persisted var lastReleaseDate: Date
    @Persisted var releaseNotes: String?
    @Persisted var descriptionText: String?
    
    @Persisted var sellerName: String?
    @Persisted var primaryGenreName: String?
    // Явно указываем, что это List из RealmSwift
    @Persisted var screenshotUrls: RealmSwift.List<String>
    
    @Persisted var status: AppStatus = .live
    // Явно указываем, что это List из RealmSwift
    @Persisted var changes: RealmSwift.List<ChangeEvent>
    
    @Persisted var dateAdded: Date = Date()
    @Persisted var lastCheckedAt: Date?
    @Persisted var ownership: AppOwnership = .competitor
    @Persisted var firstReleaseDate: Date? // Дата самого первого релиза
    @Persisted var banDate: Date? // Дата, когда мы обнаружили бан
    @Persisted var tags: List<AppTag>
    
    
    var appStoreURL: URL? {
        let sanitizedName = name
            .lowercased()
            .components(separatedBy: .alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        
        return URL(string: "https://apps.apple.com/\(country)/app/\(sanitizedName)/id\(trackId)")
    }
    
    convenience init(trackId: Int64, country: String, name: String, version: String, iconUrl: String?, lastReleaseDate: Date, releaseNotes: String?, descriptionText: String?, sellerName: String?, primaryGenreName: String?, screenshotUrls: [String], ownership: AppOwnership = .competitor, firstReleaseDate: Date?) {
        self.init()
        self.trackId = trackId
        self.country = country
        self.compoundKey = "\(trackId)-\(country)"
        self.name = name
        self.version = version
        self.iconUrl = iconUrl
        self.lastReleaseDate = lastReleaseDate
        self.releaseNotes = releaseNotes
        self.descriptionText = descriptionText
        self.sellerName = sellerName
        self.primaryGenreName = primaryGenreName
        self.screenshotUrls.append(objectsIn: screenshotUrls)
        self.ownership = ownership
        self.firstReleaseDate = firstReleaseDate
    }
}



enum ChangeType: String, PersistableEnum {
    case version
    case name
    case icon
    case releaseNotes
    case description
    case status
}

class ChangeEvent: Object, ObjectKeyIdentifiable {
    @Persisted(primaryKey: true) var id: ObjectId
    @Persisted var date: Date = Date()
    @Persisted var type: ChangeType
    
    @Persisted var oldValue: String?
    @Persisted var newValue: String?
    
    // Обратная связь к AppEntity
    @Persisted(originProperty: "changes") var app: LinkingObjects<AppEntity>
    
    // Обновленный инициализатор, который принимает "родителя"
    convenience init(app: AppEntity, type: ChangeType, oldValue: String?, newValue: String?) {
        self.init()
        self.type = type
        self.oldValue = oldValue
        self.newValue = newValue
        
        // Магия Realm: добавляем себя в список изменений родителя
        app.changes.append(self)
    }
}

class AppTag: Object, ObjectKeyIdentifiable {
    @Persisted(primaryKey: true) var name: String
    
    // Обратная связь: список приложений, использующих этот тег
    @Persisted(originProperty: "tags") var apps: LinkingObjects<AppEntity>
    
    convenience init(name: String) {
        self.init()
        // Приводим тег к нижнему регистру и убираем лишние пробелы для уникальности
        self.name = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
