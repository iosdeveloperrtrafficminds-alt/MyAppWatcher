import SwiftUI
import Kingfisher
import RealmSwift

struct AppRowView: View {
    // Используем @ObservedRealmObject, чтобы ячейка сама обновлялась,
    // если данные приложения изменятся в фоне.
    @ObservedRealmObject var app: AppEntity
    
    var body: some View {
        HStack(spacing: 12) {
            // Иконка
            KFImage(URL(string: app.iconUrl ?? ""))
                .placeholder {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 60, height: 60)
                }
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 60, height: 60)
                .cornerRadius(12)
            
            // Информация
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    // НОВАЯ ИКОНКА
                    if app.ownership == .mine {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.accentColor)
                            .font(.caption)
                    }
                    Text(app.name)
                        .font(.headline)
                        .lineLimit(1)
                }
                
                Text("v\(app.version)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if let checkedDate = app.lastCheckedAt {
                    Text("Проверено: \(checkedDate, style: .date) | \(checkedDate, style: .time) ")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            // Статус
            statusIndicator
        }
        .padding(.vertical, 8)
    }
    
    // View для индикатора статуса
    private var statusIndicator: some View {
        Circle()
            .frame(width: 12, height: 12)
            .foregroundColor(statusColor)
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 2)
            )
            .shadow(color: statusColor.opacity(0.5), radius: 3, x: 0, y: 1)
    }
    
    private var statusColor: Color {
        switch app.status {
        case .live:
            return .green
        case .removed:
            return .red
        case .unavailable:
            return .orange
        }
    }
}
