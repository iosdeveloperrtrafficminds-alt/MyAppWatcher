import Foundation
import UserNotifications

class NotificationManager {
    
    static func sendBanNotification(appName: String) {
        let content = UNMutableNotificationContent()
        content.title = "Приложение забанено!"
        content.body = "Приложение \"\(appName)\" было удалено из App Store."
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil) // nil trigger = отправить сразу
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Ошибка при отправке уведомления: \(error.localizedDescription)")
            } else {
                print("Уведомление о бане для '\(appName)' успешно запланировано.")
            }
        }
    }
}
