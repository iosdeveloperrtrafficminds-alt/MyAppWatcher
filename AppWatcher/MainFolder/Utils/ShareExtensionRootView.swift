import SwiftUI

struct ShareExtensionRootView: View {
    // Состояние, которое будет передаваться из ViewController
    @Binding var ownership: AppOwnership
    
    // Callback для кнопки "Сохранить"
    var onSave: () -> Void
    // Callback для кнопки "Отмена"
    var onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Добавить в AppWatcher")
                .font(.title2.bold())
            
            // Здесь можно будет позже добавить превью приложения
            
            Picker("Тип приложения", selection: $ownership) {
                Text(AppOwnership.mine.rawValue).tag(AppOwnership.mine)
                Text(AppOwnership.competitor.rawValue).tag(AppOwnership.competitor)
            }
            .pickerStyle(.segmented)
            
            HStack(spacing: 12) {
                Button(action: onCancel) {
                    Text("Отмена")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                
                Button(action: onSave) {
                    Text("Сохранить")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(.thinMaterial)
        .cornerRadius(12)
        .padding()
    }
}
