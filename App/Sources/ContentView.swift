import SwiftUI

// Màn tạm cho P0, thay bằng màn Hôm nay ở P5.
struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "pills.fill")
                .font(.system(size: 48))
                .foregroundStyle(.pink)
            Text("Ner's Daily")
                .font(.largeTitle.bold())
        }
    }
}

#Preview {
    ContentView()
}
