


import UIKit
import Social
import UniformTypeIdentifiers
import RealmSwift
import SwiftUI

class ShareViewController: UIViewController {
    
    // Свойства для хранения состояния
    private var ownership: AppOwnership = .competitor
    private var foundURL: URL?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Делаем фон полупрозрачным, чтобы было видно хост-приложение
        self.view.backgroundColor = .black.withAlphaComponent(0.4)
        
        Task {
            await setupView()
        }
    }

    private func setupView() async {
        // 1. Сначала ищем URL в данных, которыми поделились
        guard let url = await findURLInContext() else {
            // Если URL не найден, показываем ошибку (можно улучшить, добавив UI)
            print("🛑 [ShareVC] URL не найден. Закрываюсь.")
            closeExtension(withError: true)
            return
        }
        self.foundURL = url
        
        // 2. Теперь, когда URL есть, показываем наш SwiftUI UI
        let rootView = ShareExtensionRootView(
            ownership: .init(
                get: { self.ownership },
                set: { self.ownership = $0 }
            ),
            onSave: { self.handleSave() },
            onCancel: { self.closeExtension(withError: true) }
        )
        
        let hostingController = UIHostingController(rootView: rootView)
        hostingController.view.backgroundColor = .clear
        
        self.addChild(hostingController)
        self.view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
        
        // Размещаем UI по центру
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            hostingController.view.centerYAnchor.constraint(equalTo:self.view.centerYAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor)
        ])
    }
    
    private func handleSave() {
        // Убираем UI выбора, чтобы показать фидбек
        self.view.subviews.forEach { $0.removeFromSuperview() }
        self.children.forEach { $0.removeFromParent() }
        
        // Запускаем сохранение в фоне и сразу показываем фидбек
        Task {
            _ = await process(url: self.foundURL!, ownership: self.ownership)
        }
        showSuccessAndClose()
    }
    
    // Эта функция ищет URL и возвращает его, или nil
    private func findURLInContext() async -> URL? {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = extensionItem.attachments else {
            return nil
        }
        
        for itemProvider in attachments {
            if itemProvider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                if let item = try? await itemProvider.loadItem(forTypeIdentifier: UTType.url.identifier),
                   let url = item as? URL ?? (item as? NSURL) as? URL {
                    return url
                }
            }
        }
        return nil
    }
    
    // Функция process теперь принимает ownership
    private func process(url: URL, ownership: AppOwnership) async -> Bool {
        guard let (trackId, country) = AppURLParser.parse(url: url.absoluteString) else {
            return false
        }
        
        let compoundKey = "\(trackId)-\(country)"
        
        do {
            let realm = try await RealmProvider.realm()
            if realm.object(ofType: AppEntity.self, forPrimaryKey: compoundKey) != nil {
                return false // Уже есть
            }
            
            let apiService = iTunesAPIService()
            let details = try await apiService.lookup(trackId: trackId, country: country)
            
            try realm.write {
                let screenshots = (details.screenshotUrls ?? []) + (details.ipadScreenshotUrls ?? [])
                let releaseDate = isoDate(from: details.currentVersionReleaseDate) ?? Date()
                let firstReleaseDate = isoDate(from: details.releaseDate)
                
                // Используем новый convenience init
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
                    ownership: ownership,
                    firstReleaseDate: firstReleaseDate
                )
                realm.add(newApp)
            }
            return true // Успешно добавили
            
        } catch {
            print("🛑 [process] КРИТИЧЕСКАЯ ОШИБКА в функции process: \(error.localizedDescription)")
            return false
        }
    }
    
    private func showSuccessAndClose() {
        let feedbackView = ShareFeedbackView()
        let hostingController = UIHostingController(rootView: feedbackView)
        hostingController.view.backgroundColor = .clear
        
        self.addChild(hostingController)
        self.view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
        
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            hostingController.view.centerYAnchor.constraint(equalTo: self.view.centerYAnchor)
        ])
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.closeExtension(withError: false)
        }
    }
    
    private func closeExtension(withError: Bool) {
        if withError {
            self.extensionContext?.cancelRequest(withError: NSError(domain: "AppWatchError", code: 0))
        } else {
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }
    
    private func isoDate(from dateString: String?) -> Date? {
        guard let dateString else { return nil }
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: dateString)
    }
}
