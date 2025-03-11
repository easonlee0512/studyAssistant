import SwiftUICore
import SwiftUI
struct TimerView: View {
    @State private var timeRemaining = 25 * 60 // 25分鐘
    @State private var isRunning = false
    
    var body: some View {
        NavigationStack {
            VStack {
                Text(timeString(from: timeRemaining))
                    .font(.system(size: 70, weight: .bold))
                    .padding()
                
                HStack(spacing: 30) {
                    Button(action: {
                        isRunning.toggle()
                    }) {
                        Text(isRunning ? "暫停" : "開始")
                            .font(.title)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                    
                    Button(action: {
                        timeRemaining = 25 * 60
                        isRunning = false
                    }) {
                        Text("重置")
                            .font(.title)
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                }
            }
            .navigationTitle("專注計時")
        }
    }
    
    private func timeString(from seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}
