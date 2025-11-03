

import Foundation
import RealmSwift

struct UpdateResult {
    let checkedCount: Int
    let updatedCount: Int
    let removedCount: Int
    let restoredCount: Int
    let errorCount: Int
}

@MainActor
class UpdateManager: ObservableObject {
    
    @Published var isUpdating = false
    @Published var progress: Double = 0.0
    @Published var lastUpdateResult: UpdateResult?
    @Published var isUpdatingSingleApp: Bool = false
    
    private let apiService = iTunesAPIService()
    
    private let updateQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInitiated
        return queue
    }()
    
    func updateAllApps() async {
        if isUpdating { return }
        
        isUpdating = true
        progress = 0.0
        lastUpdateResult = nil
        
        guard let realm = try? await RealmProvider.realm() else {
            isUpdating = false
            return
        }
        
        let allAppKeys = Array(realm.objects(AppEntity.self).map { $0.compoundKey })
        
        let totalApps = allAppKeys.count
        guard totalApps > 0 else {
            isUpdating = false
            return
        }
        
        var checkedCount = 0
        var updatedCount = 0
        var removedCount = 0
        var restoredCount = 0
        var errorCount = 0
        
        let operations = allAppKeys.map { key -> AppUpdateOperation in
            let operation = AppUpdateOperation(appKey: key)
            
            // ИЗМЕНЕНИЕ: onCompletion теперь принимает наш новый Enum
            operation.onCompletion = { [weak self] result in
                guard let self = self else { return }
                
                checkedCount += 1
                self.progress = Double(checkedCount) / Double(totalApps)
                
                // --- НОВАЯ, ПРОСТАЯ ЛОГИКА ПОДСЧЕТА ---
                switch result {
                case .changed(let from, let to):
                    updatedCount += 1
                    if from == .live && to == .removed {
                        removedCount += 1
                    }
                    if from == .removed && to == .live {
                        restoredCount += 1
                    }
                case .unchanged:
                    // Ничего не делаем со счетчиками
                    break
                case .error:
                    errorCount += 1
                }
                
                // Когда все операции завершены, показываем результат
                if checkedCount == totalApps {
                    self.lastUpdateResult = UpdateResult(
                        checkedCount: totalApps,
                        updatedCount: updatedCount,
                        removedCount: removedCount,
                        restoredCount: restoredCount,
                        errorCount: errorCount
                    )
                    self.isUpdating = false
                }
            }
            return operation
        }
        
        updateQueue.addOperations(operations, waitUntilFinished: false)
    }
    
    func cancelAllUpdates() {
        updateQueue.cancelAllOperations()
        isUpdating = false
    }
    
    func updateSingleApp(appKey: String) async {
        // Теперь функция принимает ключ, а не объект
        if isUpdatingSingleApp { return }
        
        isUpdatingSingleApp = true
        
        // Находим "живой" объект в главном Realm по ключу
        guard let realm = try? await RealmProvider.realm(),
              let appToUpdate = realm.object(ofType: AppEntity.self, forPrimaryKey: appKey),
              !appToUpdate.isInvalidated,
              let appURL = appToUpdate.appStoreURL else {
            isUpdatingSingleApp = false
            return
        }
        
        let oldStatus = appToUpdate.status
        let newStatus = await iTunesAPIService().checkStatus(for: appURL)
        
        if newStatus != .unavailable && oldStatus != newStatus {
            try? realm.write {
                appToUpdate.status = newStatus
                appToUpdate.lastCheckedAt = Date()
                _ = ChangeEvent(app: appToUpdate, type: .status, oldValue: oldStatus.rawValue, newValue: newStatus.rawValue)
                
                if newStatus == .removed {
                    appToUpdate.banDate = Date()
                }
                if newStatus == .live {
                    appToUpdate.banDate = nil
                }
            }
        } else if newStatus != .unavailable {
            try? realm.write {
                appToUpdate.lastCheckedAt = Date()
            }
        }
        
        isUpdatingSingleApp = false
    }
    
    //    func performTestBackgroundTask() {
    //        print("--- [ТЕСТ] Запуск тестовой фоновой задачи ---")
    //
    //        // Запускаем в отдельном потоке, чтобы не блокировать UI
    //        Task(priority: .background) {
    //            // Открываем Realm в этом фоновом потоке
    //            guard let backgroundRealm = try? Realm(configuration: RealmProvider.configuration, queue: nil) else {
    //                print("--- [ТЕСТ] Ошибка: Не удалось открыть Realm в фоне.")
    //                return
    //            }
    //
    //            // Находим все "мои" приложения
    //            let myApps = backgroundRealm.objects(AppEntity.self).where { $0.ownership == .mine && $0.status == .live }
    //
    //            print("--- [ТЕСТ] Найдено 'моих' живых приложений для проверки: \(myApps.count)")
    //
    //            for app in myApps {
    //                guard let url = app.appStoreURL else { continue }
    //
    //                // Проверяем статус
    //                let newStatus = await self.apiService.checkStatus(for: url)
    //
    //                if newStatus == .removed {
    //                    print("--- [ТЕСТ] ОБНАРУЖЕН БАН для: \(app.name)! ---")
    //
    //                    let appName = app.name // Захватываем имя перед транзакцией
    //
    //                    // Обновляем базу
    //                    try? backgroundRealm.write {
    //                        app.status = .removed
    //                        app.banDate = Date()
    //                    }
    //
    //                    // Отправляем уведомление
    //                    NotificationManager.sendBanNotification(appName: appName)
    //                } else {
    //                    print("--- [ТЕСТ] Статус для '\(app.name)' - OK.")
    //                }
    //            }
    //            print("--- [ТЕСТ] Тестовая фоновая задача завершена. ---")
    //        }
    //    }
    
    //    func performTestBackgroundTask() {
    //        print("--- [ТЕСТ] Запуск тестовой фоновой задачи ---")
    //
    //        // 1. Получаем ключи "моих" приложений на том потоке, где нас вызвали
    //        guard let realm = try? Realm(configuration: RealmProvider.configuration, queue: nil) else {
    //            print("--- [ТЕСТ] Ошибка: Не удалось открыть Realm.")
    //            return
    //        }
    //
    //        let myAppKeys = Array(realm.objects(AppEntity.self)
    //                              .where { $0.ownership == .mine && $0.status == .live }
    //                              .map { $0.compoundKey })
    //
    //        print("--- [ТЕСТ] Найдено 'моих' живых приложений для проверки: \(myAppKeys.count)")
    //
    //        if myAppKeys.isEmpty {
    //            print("--- [ТЕСТ] Нет приложений для проверки. Завершаю.")
    //            return
    //        }
    //
    //        // 2. Создаем операции для каждого приложения
    //        let operations = myAppKeys.map { key -> AppUpdateOperation in
    //            let operation = AppUpdateOperation(appKey: key)
    //
    //            operation.onCompletion = { result in
    //                // Этот блок выполняется на главном потоке после каждой операции
    //                switch result {
    //                // --- ИСПРАВЛЕНИЕ ЗДЕСЬ ---
    //                // Обрабатываем оба успешных случая: когда статус изменился и когда нет
    //                case .changed(_, let to): // Нам важен только новый статус `to`
    //                    let mainRealm = try! Realm(configuration: RealmProvider.configuration)
    //                    if let app = mainRealm.object(ofType: AppEntity.self, forPrimaryKey: key) {
    //                        if to == .removed {
    //                            print("--- [ТЕСТ] ОБНАРУЖЕН БАН для: \(app.name)! Отправляю уведомление. ---")
    //                            NotificationManager.sendBanNotification(appName: app.name)
    //                        } else {
    //                            print("--- [ТЕСТ] Статус для '\(app.name)' изменился, но это не бан.")
    //                        }
    //                    }
    //                case .unchanged:
    //                    let mainRealm = try! Realm(configuration: RealmProvider.configuration)
    //                    if let app = mainRealm.object(ofType: AppEntity.self, forPrimaryKey: key) {
    //                        print("--- [ТЕСТ] Статус для '\(app.name)' - OK (не изменился).")
    //                    }
    //                // --- КОНЕЦ ИСПРАВЛЕНИЯ ---
    //
    //                case .error:
    //                    print("--- [ТЕСТ] Ошибка при проверке приложения \(key).")
    //                }
    //            }
    //            return operation
    //        }
    //
    //        // 3. Добавляем операции в нашу существующую очередь
    //        // Они будут выполняться последовательно в фоне.
    //        print("--- [ТЕСТ] Добавляю \(operations.count) операций в очередь. ---")
    //        updateQueue.addOperations(operations, waitUntilFinished: false)
    //        // Добавляем операцию, которая выполнится после всех проверок
    //        updateQueue.addOperation {
    //             print("--- [ТЕСТ] Тестовая фоновая задача (все операции в очереди) завершена. ---")
    //        }
    //    }
}
