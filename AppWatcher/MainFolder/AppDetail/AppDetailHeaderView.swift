import SwiftUI
import Kingfisher

struct AppDetailHeaderView: View {
    let app: AppEntity
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            KFImage(URL(string: app.iconUrl ?? ""))
                .placeholder {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.gray.opacity(0.2))
                }
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)
                .cornerRadius(16)

            VStack(alignment: .leading, spacing: 6) {
                Text(app.name)
                    .font(.title2)
                    .fontWeight(.bold)
                
                if let sellerName = app.sellerName {
                    Text(sellerName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if let genre = app.primaryGenreName {
                    Text(genre)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                statusBadge
            }
        }
        .frame(height: 100)
    }
    
    @ViewBuilder
    private var statusBadge: some View {
        Text(app.status.rawValue.capitalized)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundColor(.white)
            .background(statusColor)
            .cornerRadius(8)
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
