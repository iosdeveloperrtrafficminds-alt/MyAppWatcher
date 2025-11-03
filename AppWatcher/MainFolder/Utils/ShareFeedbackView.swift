import SwiftUI

struct ShareFeedbackView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(.green)
            
            Text("Добавлено в AppWatcher")
                .font(.headline)
                .foregroundColor(.primary)
        }
        .padding(30)
        .background(.ultraThinMaterial) // Эффект "матового стекла"
        .cornerRadius(20)
        .shadow(radius: 10)
    }
}

#Preview {
    ShareFeedbackView()
        .preferredColorScheme(.dark)
}
