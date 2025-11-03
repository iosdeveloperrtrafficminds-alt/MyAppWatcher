import Foundation
import RealmSwift

// НОВОЕ: Структура для хранения результата поиска одного приложения
struct SearchResult: Identifiable {
    let id: Int64
    let details: iTunesLookupResult.AppDetails
    var isAlreadyAdded: Bool = false
    var ownership: AppOwnership = .competitor
}

@MainActor
class AddAppViewModel: ObservableObject {
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Теперь это массив результатов
    @Published var searchResults: [SearchResult] = []
    
    // Свойство для отслеживания прогресса сохранения
    @Published var saveProgress: Double = 0.0
    @Published var isSaving = false
    
    // Свойство для уведомления View об успешном сохранении
    @Published var didSaveApps = false
    
    private let apiService = iTunesAPIService()
    
    func search(for multiLineInput: String) async {
        if isLoading || isSaving { return }
        
        isLoading = true
        errorMessage = nil
        searchResults = []
        
        let parsedPairs = AppURLParser.parse(multiLineText: multiLineInput)
        
        if parsedPairs.isEmpty {
            errorMessage = "Не найдено ни одной валидной ссылки или ID."
            isLoading = false
            return
        }
        
        // Используем TaskGroup для параллельного выполнения сетевых запросов
        await withTaskGroup(of: iTunesLookupResult.AppDetails?.self) { group in
            for pair in parsedPairs {
                group.addTask {
                    // Возвращаем nil в случае ошибки, чтобы не прерывать всю группу
                    return try? await self.apiService.lookup(trackId: pair.trackId, country: pair.country)
                }
            }
            
            // Собираем результаты по мере их поступления
            for await result in group {
                if let details = result {
                    // Проверяем, не добавлено ли приложение уже в базу
                    let realm = try! await RealmProvider.realm()
                    let compoundKey = "\(details.trackId)-\(AppURLParser.parse(url: "id\(details.trackId)")?.country ?? "us")"
                    let isAdded = realm.object(ofType: AppEntity.self, forPrimaryKey: compoundKey) != nil
                    
                    let searchResult = SearchResult(id: details.trackId, details: details, isAlreadyAdded: isAdded)
                    self.searchResults.append(searchResult)
                }
            }
        }
        
        isLoading = false
    }
    
    func saveSelectedApps() async {
        if isSaving { return }
        
        // Фильтруем только те, что еще не добавлены
        let appsToSave = searchResults.filter { !$0.isAlreadyAdded }
        
        guard !appsToSave.isEmpty else {
            errorMessage = "Все найденные приложения уже отслеживаются."
            return
        }
        
        isSaving = true
        saveProgress = 0.0
        
        let realm = try! await RealmProvider.realm()
        
        try! realm.write {
            for (index, result) in appsToSave.enumerated() {
                let details = result.details
                
                print("--- PARSED SCREENSHOTS for: \(details.trackName ?? "N/A") ---")
                print("iPhone screenshots (screenshotUrls): \(details.screenshotUrls ?? [])")
                print("iPad screenshots (ipadScreenshotUrls): \(details.ipadScreenshotUrls ?? [])")
                
                let screenshots = (details.screenshotUrls ?? []) + (details.ipadScreenshotUrls ?? [])
                
                print("Combined array to save: \(screenshots)")
                print("---------------------------------------")
                
                let releaseDate = isoDate(from: details.currentVersionReleaseDate) ?? Date()
                let firstReleaseDate = isoDate(from: details.releaseDate)
                let country = AppURLParser.parse(url: "id\(details.trackId)")?.country ?? "us"
                
                let newApp = AppEntity(
                    trackId: details.trackId,
                    country: country,
                    name: details.trackName ?? "N/A",
                    version: details.version ?? "N/A",
                    iconUrl: details.artworkUrl512,
                    lastReleaseDate: releaseDate,
                    releaseNotes: details.releaseNotes,
                    descriptionText: details.description,
                    sellerName: details.sellerName,
                    primaryGenreName: details.primaryGenreName,
                    screenshotUrls: screenshots,
                    ownership: result.ownership,
                    firstReleaseDate: firstReleaseDate
                )
                
                realm.add(newApp, update: .modified) // Используем .modified на случай, если ключ уже есть
                
                // Обновляем прогресс
                saveProgress = Double(index + 1) / Double(appsToSave.count)
            }
        }
        
        isSaving = false
        didSaveApps = true
    }
    
    private func isoDate(from dateString: String?) -> Date? {
        guard let dateString else { return nil }
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: dateString)
    }
}
