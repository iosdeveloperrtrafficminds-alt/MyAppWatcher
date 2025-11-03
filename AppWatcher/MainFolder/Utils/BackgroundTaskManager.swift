import Foundation
@preconcurrency import BackgroundTasks
import RealmSwift

@MainActor
class BackgroundTaskManager {
    
    static let refreshTaskIdentifier = "com.appwatch.refresh"
    
    // 1. Регистрация задачи
    func registerBackgroundTask() {
        let registrationResult = BGTaskScheduler.shared.register(forTaskWithIdentifier: BackgroundTaskManager.refreshTaskIdentifier, using: nil) { task in
            // Превращаем вызов в асинхронную задачу
            Task {
                await self.handleAppRefresh(task: task as! BGAppRefreshTask)
            }
        }
        
        // Добавим лог, чтобы видеть результат регистрации
        if registrationResult {
            print("BGTask: Успешно зарегистрирован обработчик для задачи \(BackgroundTaskManager.refreshTaskIdentifier)")
        } else {
            print("BGTask: Ошибка при регистрации обработчика для задачи \(BackgroundTaskManager.refreshTaskIdentifier)")
        }
    }
    
    // 2. Планирование задачи (без изменений)
    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: BackgroundTaskManager.refreshTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 6 * 60 * 60)
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("BGTask: Успешно запланирована фоновая проверка.")
        } catch {
            print("BGTask: Не удалось запланировать фоновую проверку: \(error)")
        }
    }
    
    // 3. Выполнение задачи (ПОЛНОСТЬЮ ПЕРЕПИСАНО)
    private func handleAppRefresh(task: BGAppRefreshTask) async {
        // Планируем следующую проверку
        scheduleAppRefresh()
        
        // Устанавливаем обработчик на случай, если время выйдет
        task.expirationHandler = {
            print("BGTask: Время вышло! Задача прервана.")
            task.setTaskCompleted(success: false)
        }

        print("BGTask: Фоновая задача запущена. Начинаю проверку 'моих' приложений.")
        
        // Выполняем реальную работу
        let success = await performBackgroundCheck()
        
        // Сообщаем системе о завершении
        print("BGTask: Фоновая работа завершена с результатом: \(success ? "успех" : "неудача").")
        task.setTaskCompleted(success: success)
    }
    
    // НОВАЯ ФУНКЦИЯ: Изолированная логика проверки
    private func performBackgroundCheck() async -> Bool {
        // Открываем Realm в этом фоновом потоке
        guard let backgroundRealm = try? Realm(configuration: RealmProvider.configuration, queue: nil) else {
            print("BGTask Error: Не удалось открыть Realm в фоне.")
            return false
        }
        
        let myApps = backgroundRealm.objects(AppEntity.self)
            .where { $0.ownership == .mine && $0.status == .live }
            .freeze() // Используем "замороженную" коллекцию для безопасности
        
        if myApps.isEmpty {
            print("BGTask: Нет 'моих' живых приложений для проверки.")
            return true // Задача выполнена успешно, просто нечего было делать
        }
        
        print("BGTask: Найдено для проверки: \(myApps.count) приложений.")
        
        // Последовательно проверяем каждое приложение
        for app in myApps {
            guard let url = app.appStoreURL else { continue }
            
            let apiService = iTunesAPIService()
            let newStatus = await apiService.checkStatus(for: url)
            
            if newStatus == .removed {
                print("BGTask: ОБНАРУЖЕН БАН для: \(app.name)! Обновляю базу и шлю уведомление.")
                
                // Для записи нам нужен "живой" объект
                guard let liveApp = app.thaw(),
                      let realm = liveApp.realm else { continue }
                
                try? realm.write {
                    liveApp.status = .removed
                    liveApp.banDate = Date()
                }
                
                NotificationManager.sendBanNotification(appName: app.name)
            }
        }
        
        return true // Вся работа успешно выполнена
    }
}
