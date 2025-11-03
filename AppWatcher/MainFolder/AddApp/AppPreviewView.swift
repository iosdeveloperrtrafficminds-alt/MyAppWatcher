import SwiftUI
import Kingfisher

struct AppPreviewView: View {
    // Получаем детали найденного приложения
    let appDetails: iTunesLookupResult.AppDetails

    var body: some View {
        HStack(spacing: 15) {
            // Иконка с кэшированием от Kingfisher
            KFImage(URL(string: appDetails.artworkUrl512 ?? ""))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 5) {
                Text(appDetails.trackName ?? "Без имени")
                    .font(.headline)
                    .lineLimit(2)
                
                Text(appDetails.sellerName ?? "Неизвестный разработчик")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if let version = appDetails.version {
                    Text("Версия: \(version)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            Spacer()
        }
    }
}
