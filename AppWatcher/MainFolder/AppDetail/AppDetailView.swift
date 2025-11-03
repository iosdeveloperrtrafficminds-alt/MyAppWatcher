

import SwiftUI
import RealmSwift

struct AppDetailView: View {
    
    @ObservedRealmObject var app: AppEntity
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var isShowingDeleteAlert = false
    @State private var newTagName: String = ""
    
    @StateObject private var updateManager = UpdateManager()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) { // Увеличим spacing
                // --- HEADER ---
                AppDetailHeaderView(app: app)
                    .padding(.horizontal)
                
                if let url = app.appStoreURL {
                    Link(destination: url) {
                        Text("Открыть в App Store")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(10)
                            .background(Color.accentColor.opacity(0.1))
                            .foregroundColor(.accentColor)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }
                
                // --- НОВЫЙ ИНФО-БЛОК ---
                VStack(alignment: .leading, spacing: 12) {
                    // Кнопка обновления
                    Button(action: {
                        Task { await updateManager.updateSingleApp(appKey: app.compoundKey) }
                    }) {
                        
                        HStack {
                            if updateManager.isUpdatingSingleApp {
                                ProgressView()
                                    .frame(width: 20, height: 20)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                            Text(updateManager.isUpdatingSingleApp ? "Проверка..." : "Проверить статус")
                        }
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(10)
                        .background(Color.accentColor.opacity(0.1))
                        .foregroundColor(.accentColor)
                        .cornerRadius(10)
                    }
                    .disabled(updateManager.isUpdatingSingleApp)
                    
                    // Информация о типе
                    HStack {
                        Text("Тип:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(app.ownership.rawValue)
                            .fontWeight(.semibold)
                        if app.ownership == .mine {
                            Image(systemName: "person.circle.fill")
                        }
                    }
                    
                    // Даты
                    if let firstRelease = app.firstReleaseDate {
                        HStack {
                            Text("Первый релиз:")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(firstRelease, style: .date)
                        }
                    }
                    
                    HStack {
                        Text("Добавлено в трекер:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(app.dateAdded, style: .date)
                    }
                    
                    // Информация о бане
                    if app.status == .removed, let banDate = app.banDate, let firstRelease = app.firstReleaseDate {
                        HStack {
                            Text("Дата бана:")
                                .foregroundColor(.red.opacity(0.8))
                            Spacer()
                            Text(banDate, style: .date)
                                .foregroundColor(.red)
                        }
                        
                        HStack {
                            Text("Время жизни:")
                                .foregroundColor(.red.opacity(0.8))
                            Spacer()
                            Text(lifetimeString(from: firstRelease, to: banDate))
                                .fontWeight(.bold)
                                .foregroundColor(.red)
                        }
                    }
                }
                .padding(.horizontal)
                
                Divider()
                
                // --- НОВЫЙ БЛОК: Управление тегами ---
                VStack(alignment: .leading) {
                    Text("Теги")
                        .font(.headline)
                    
                    // Отображение существующих тегов
                    if !app.tags.isEmpty {
                        // Используем кастомный Flow-layout для красивого отображения тегов
                        TagCloudView(tags: app.tags.map(\.name)) { tagNameToDelete in
                            deleteTag(name: tagNameToDelete)
                        }
                    } else {
                        Text("Теги не добавлены")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    }
                    
                    // Поле для добавления нового тега
                    HStack {
                        TextField("Добавить тег...", text: $newTagName)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit(addTag) // Добавляем по нажатию Enter
                        
                        Button(action: addTag) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                        }
                        .disabled(newTagName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal)
                
                Divider()
                
                // 3. Версия и дата
                VStack(alignment: .leading) {
                    Text("Версия \(app.version)")
                        .font(.headline)
                    Text("Последнее обновление: \(app.lastReleaseDate, style: .date)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                }
                .padding(.horizontal)
                
                // 4. "Что нового" (Release Notes)
                if let notes = app.releaseNotes, !notes.isEmpty {
                    VStack(alignment: .leading) {
                        Text("Что нового")
                            .font(.headline)
                        Text(notes)
                            .font(.body)
                    }
                    .padding(.horizontal)
                }
                
                // 5. Скриншоты
                if !app.screenshotUrls.isEmpty {
                    VStack(alignment: .leading) {
                        Text("Скриншоты")
                            .font(.headline)
                            .padding(.horizontal)
                        AppDetailScreenshotsView(screenshots: app.screenshotUrls)
                    }
                }
                
                // 6. Описание
                if let description = app.descriptionText, !description.isEmpty {
                    DisclosureGroup("Описание") {
                        Text(description)
                            .font(.body)
                    }
                    .padding(.horizontal)
                }
                
                // 7. История изменений (пока просто заглушка)
                VStack(alignment: .leading) {
                    Text("История изменений")
                        .font(.headline)
                    if app.changes.isEmpty {
                        Text("Пока не было изменений.")
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    } else {
                        // Здесь будет список изменений на следующих этапах
                        Text("Изменений: \(app.changes.count)")
                    }
                }
                .padding()
                
            }
            .padding(.vertical)
        }
        .navigationTitle(app.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .destructiveAction) {
                Button(role: .destructive) {
                    // Показываем диалог перед удалением
                    isShowingDeleteAlert = true
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
        // НОВЫЙ БЛОК: Диалог подтверждения
        .alert("Удалить приложение?", isPresented: $isShowingDeleteAlert) {
            Button("Удалить", role: .destructive) {
                deleteApp()
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Это действие нельзя будет отменить. Вся история изменений для \"\(app.name)\" будет потеряна.")
        }
    }
    
    private func deleteApp() {
        // Проверяем, что объект все еще существует и не "заморожен"
        guard let appToDelete = app.thaw(), !appToDelete.isInvalidated else {
            // Если что-то пошло не так, просто ничего не делаем
            return
        }
        
        // Получаем доступ к Realm, в котором "живет" наш объект
        guard let realm = appToDelete.realm else {
            return
        }
        
        do {
            try realm.write {
                realm.delete(appToDelete)
            }
            // Если удаление прошло успешно, закрываем экран
            dismiss()
        } catch {
            print("Ошибка при удалении приложения: \(error.localizedDescription)")
            // Здесь можно показать алерт об ошибке, если нужно
        }
    }
    
    private func lifetimeString(from startDate: Date, to endDate: Date) -> String {
        let components = Calendar.current.dateComponents([.day, .month, .year], from: startDate, to: endDate)
        
        if let years = components.year, years > 0 {
            return "\(years) г."
        }
        if let months = components.month, months > 0 {
            return "\(months) мес."
        }
        if let days = components.day, days >= 0 {
            return "\(days) д."
        }
        return "N/A"
    }
    
    private func addTag() {
        let tagName = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        if tagName.isEmpty { return }
        
        // 1. "Размораживаем" объект приложения, чтобы с ним можно было работать
        guard let thawedApp = app.thaw(), !thawedApp.isInvalidated,
              let realm = thawedApp.realm else {
            print("Не удалось получить 'живой' объект AppEntity для добавления тега.")
            return
        }
        
        try? realm.write {
            // Ищем, существует ли уже такой тег в базе
            var tagToAdd: AppTag
            if let existingTag = realm.object(ofType: AppTag.self, forPrimaryKey: tagName.lowercased()) {
                tagToAdd = existingTag
            } else {
                // Если нет - создаем новый
                tagToAdd = AppTag(name: tagName)
            }
            
            // Добавляем тег к "живому" объекту приложения, если его еще нет
            if !thawedApp.tags.contains(tagToAdd) {
                thawedApp.tags.append(tagToAdd)
            }
        }
        
        // Очищаем поле ввода
        newTagName = ""
    }
    
    private func deleteTag(name: String) {
        // 1. "Размораживаем" объект
        guard let thawedApp = app.thaw(), !thawedApp.isInvalidated,
              let realm = thawedApp.realm else {
            return
        }
        
        // 2. Ищем индекс тега в "размороженном" объекте
        guard let tagIndex = thawedApp.tags.firstIndex(where: { $0.name == name }) else { return }
        
        try? realm.write {
            // 3. Удаляем тег из "размороженного" объекта
            thawedApp.tags.remove(at: tagIndex)
        }
    
    }
}
