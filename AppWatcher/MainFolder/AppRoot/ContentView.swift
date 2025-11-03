import SwiftUI
import RealmSwift

struct ContentView: View {
    // Состояние для хранения выбранного фильтра.
    @State private var selectedStatusFilter: AppStatus? = nil
    
    // Состояние для хранения текста из поля поиска
    @State private var searchText = ""
    
    // @ObservedResults - это "живая" коллекция из Realm.
    @ObservedResults(
        AppEntity.self,
        configuration: RealmProvider.configuration, // <<< ВОТ ОНО!
        sortDescriptor: SortDescriptor(keyPath: "dateAdded", ascending: false)
    ) var apps
    
    @ObservedResults(
           AppTag.self,
           configuration: RealmProvider.configuration, // <<< ДОБАВЛЯЕМ ЭТУ СТРОКУ
           sortDescriptor: SortDescriptor(keyPath: "name")
       ) var allTags
    
    // Создаем экземпляр нашего менеджера для обновлений
    @StateObject private var updateManager = UpdateManager()
    
    @State private var isShowingAddAppView = false
    // Состояние для показа алерта с результатами
    @State private var showUpdateResultAlert = false
    @State private var selectedOwnershipFilter: AppOwnership? = nil
    // НОВОЕ: Состояние для выбранного тега
    @State private var selectedTagFilter: String? = nil
    
    var body: some View {
        NavigationStack {
            VStack {
                // Сегментный контрол для фильтрации
                Picker("Статус", selection: $selectedStatusFilter) {
                    // ИСПРАВЛЕНО: Правильный синтаксис для тегов
                    Text("Все").tag(Optional<AppStatus>.none)
                    Text("Живые").tag(Optional(AppStatus.live))
                    Text("Забаненные").tag(Optional(AppStatus.removed))
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                Picker("Тип", selection: $selectedOwnershipFilter) {
                    Text("Все типы").tag(Optional<AppOwnership>.none)
                    Text("Мои").tag(Optional(AppOwnership.mine))
                    Text("Конкуренты").tag(Optional(AppOwnership.competitor))
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                HStack {
                        Text("Фильтр по тегу:")
                    Menu {
                        Button("Все теги") { selectedTagFilter = nil }
                        
                        // Проверяем, не пуста ли коллекция, перед тем как рисовать Divider
                        if !allTags.isEmpty {
                            Divider()
                            ForEach(allTags) { tag in
                                // Удостоверимся, что тег не удален
                                if !tag.isInvalidated {
                                    Button(tag.name) { selectedTagFilter = tag.name }
                                }
                            }
                        }
                    } label: {
                            HStack {
                                Text(selectedTagFilter ?? "Все теги")
                                Image(systemName: "chevron.down")
                            }
                            .padding(8)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                
                // Прогресс-бар
                if updateManager.isUpdating {
                    ProgressView(value: updateManager.progress)
                        .progressViewStyle(.linear)
                        .padding(.horizontal)
                        .animation(.default, value: updateManager.progress)
                }
                
                // Используем наш новый отфильтрованный список
                List {
                    // Передаем отфильтрованные результаты в ForEach
                    ForEach(filteredApps()) { app in
                        NavigationLink {
                            AppDetailView(app: app)
                        } label: {
                            AppRowView(app: app)
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("AppWatcher")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    // Кнопка "Обновить всё"
                    Button(action: {
                        Task {
                            await updateManager.updateAllApps()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(updateManager.isUpdating || apps.isEmpty) // Блокируем, если обновляется или список пуст
                    
                    // Кнопка "Добавить"
                    Button(action: { isShowingAddAppView = true }) {
                        Image(systemName: "plus")
                    }
                    .disabled(updateManager.isUpdating)
                }
            }
            .sheet(isPresented: $isShowingAddAppView) {
                AddAppView()
            }
            .searchable(text: $searchText, prompt: "Поиск")
            .overlay {
                if apps.isEmpty {
                    emptyStateView // Показываем, если вообще нет приложений
                } else if filteredApps().isEmpty {
                    noResultsView // Показываем, если ничего не нашлось по фильтрам
                }
            }
        }
        // Следим за окончанием обновления, чтобы показать алерт
        .onChange(of: updateManager.isUpdating) { _, isUpdatingAfterChange in
            if !isUpdatingAfterChange && updateManager.lastUpdateResult != nil {
                showUpdateResultAlert = true
            }
        }
        // Алерт с результатами
        .alert("Обновление завершено", isPresented: $showUpdateResultAlert, presenting: updateManager.lastUpdateResult) { result in
            Button("OK") {}
        } message: { result in
            Text("Проверено: \(result.checkedCount)\nОбновлено: \(result.updatedCount)\nЗабанено: \(result.removedCount)\nВосстановлено: \(result.restoredCount)")
        }
    }
    
    
    private func filteredApps() -> Results<AppEntity> {
        var filtered = apps
        
        if let status = selectedStatusFilter {
            filtered = filtered.where { $0.status == status }
        }
        
        if let ownership = selectedOwnershipFilter {
            filtered = filtered.where { $0.ownership == ownership }
        }
        
        // --- ИСПРАВЛЕНИЕ ЗДЕСЬ ---
        if let tagName = selectedTagFilter {
            // Используем NSPredicate для фильтрации по связанным объектам.
            // "ANY tags.name == %@" означает "любой тег в списке tags должен иметь имя равное tagName"
            let predicate = NSPredicate(format: "ANY tags.name == %@", tagName)
            filtered = filtered.filter(predicate)
        }
        
        if !searchText.isEmpty {
            let predicate = NSPredicate(format: "name CONTAINS[c] %@ OR ANY tags.name CONTAINS[c] %@", searchText, searchText)
            filtered = filtered.filter(predicate)
        }
        
        return filtered
    }
    
    // View для случая, когда список пуст
    private var emptyStateView: some View {
        VStack {
            Image(systemName: "document.badge.plus.fill")
                .font(.largeTitle)
                .padding(.bottom, 8)
            Text("Нет отслеживаемых приложений")
                .font(.headline)
            Text("Нажмите '+' чтобы добавить первое приложение.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .multilineTextAlignment(.center)
    }
    
    // View для случая, когда по фильтрам ничего не найдено
    private var noResultsView: some View {
        VStack {
            Image(systemName: "magnifyingglass")
                .font(.largeTitle)
                .padding(.bottom, 8)
            Text("Ничего не найдено")
                .font(.headline)
            Text("Попробуйте изменить фильтр или поисковый запрос.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .multilineTextAlignment(.center)
    }
    
    
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
