import SwiftUI
import Kingfisher
import RealmSwift // Добавляем импорт RealmSwift, чтобы указать тип

struct AppDetailScreenshotsView: View {
    // Явно указываем, что это List из RealmSwift
    let screenshots: RealmSwift.List<String>
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(screenshots, id: \.self) { urlString in
                    KFImage(URL(string: urlString))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal)
        }
        .frame(height: 250)
    }
}
