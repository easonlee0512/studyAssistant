import SwiftUICore
import SwiftUI

struct TimerView: View {
    @State private var timeRemaining = 25 * 60 // 25分鐘
    @State private var isRunning = false
    @State private var isCountdown = true
    @State private var timer: Timer?
    @State private var selectedMinutes = 25
    
    let availableMinutes = [5, 15, 25, 30, 45, 60]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Spacer()
                    .frame(height: 50) // 增加上方間距
                
                // 時間顯示
                Text(timeString(from: timeRemaining))
                    .font(.system(size: 70, weight: .bold))
                    .padding()
                    .foregroundColor(isRunning ? .green : .primary)
                
                // 時間選擇器
                if !isRunning {
                    Picker("選擇時間", selection: $selectedMinutes) {
                        ForEach(availableMinutes, id: \.self) { minute in
                            Text("\(minute) 分鐘")
                        }
                    }
                    .pickerStyle(.wheel)
                    .onChange(of: selectedMinutes) { newValue in
                        if isCountdown {
                            timeRemaining = newValue * 60
                        }
                    }
                }
                
                // 控制按鈕
                HStack(spacing: 30) {
                    Button(action: toggleTimer) {
                        Text(isRunning ? "暫停" : "開始")
                            .font(.title)
                            .padding()
                            .frame(width: 120)
                            .background(isRunning ? Color.orange : Color.green)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                    
                    Button(action: resetTimer) {
                        Text("重置")
                            .font(.title)
                            .padding()
                            .frame(width: 120)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                }
                
                // 計時模式切換
                Button {
                    toggleCountdownMode()
                } label: {
                    Text(isCountdown ? "倒計時模式" : "正計時模式")
                        .font(.title)
                        .padding()
                        .frame(width: 270)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
                
                Spacer()
            }
            .navigationTitle("專注計時")
            .onDisappear {
                timer?.invalidate()
            }
        }
    }
    
    // 切換計時器
    private func toggleTimer() {
        if isRunning {
            timer?.invalidate()
            timer = nil
        } else {
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                if isCountdown {
                    if timeRemaining > 0 {
                        timeRemaining -= 1
                    } else {
                        timer?.invalidate()
                        isRunning = false
                    }
                } else {
                    timeRemaining += 1
                }
            }
        }
        isRunning.toggle()
    }
    
    // 重置計時器
    private func resetTimer() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        timeRemaining = isCountdown ? selectedMinutes * 60 : 0 // 正計時從 0 開始
    }
    
    // 切換倒計時/正計時模式
    private func toggleCountdownMode() {
        isCountdown.toggle()
        timeRemaining = isCountdown ? selectedMinutes * 60 : 0 // 切換模式時重置時間
        resetTimer()
    }
    
    // 時間格式化
    private func timeString(from seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainingSeconds = seconds % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, remainingSeconds)
        } else {
            return String(format: "%02d:%02d", minutes, remainingSeconds)
        }
    }
}

#Preview {
    TimerView()
}
