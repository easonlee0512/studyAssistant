import SwiftUI
import AudioToolbox

class SoundManager {
    func playSystemSound() {
        AudioServicesPlaySystemSound(1002)
    }
}

struct TimerView: View {
    @State private var countdownTime = 25 * 60
    @State private var countupTime = 0
    @State private var isRunning = false
    @State private var isCountdown = true
    @State private var selectedMinutes = 25
    @State private var customMinutes = ""
    @State private var timer: Timer?

    private let soundManager = SoundManager()
    
    // 預設時間選項
    private let timeOptions = [1, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60]

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // 模式切換按鈕
                HStack {
                    Button(action: {
                        isCountdown = true
                        updateTimer()
                    }) {
                        Text("倒計時")
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(isCountdown ? Color.black : Color.gray.opacity(0.2))
                            .foregroundColor(isCountdown ? .white : .black)
                            .clipShape(Capsule())
                    }

                    Button(action: {
                        isCountdown = false
                        updateTimer()
                    }) {
                        Text("正計時")
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(!isCountdown ? Color.black : Color.gray.opacity(0.2))
                            .foregroundColor(!isCountdown ? .white : .black)
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal)
                
                // 時間顯示
                Text(timeString(from: isCountdown ? countdownTime : countupTime))
                    .font(.system(size: 80, weight: .bold))
                    .monospacedDigit()
                    .padding(.vertical, 30)
                
                // 控制按鈕
              
                .padding(.bottom, 20)
                
                // 時間選擇器（僅適用於倒計時模式）
                if isCountdown {
                    Picker("選擇時間", selection: $selectedMinutes) {
                        ForEach(timeOptions, id: \.self) { minutes in
                            Text("\(minutes) 分鐘").tag(minutes)
                        }
                    }
                    .pickerStyle(.wheel)
                    .onChange(of: selectedMinutes) { _ in
                        updateTimer()
                    }
                }
                HStack(spacing: 30) {
                    Button(action: toggleTimer) {
                        Text(isRunning ? "暫停" : "開始")
                            .font(.title3)
                            .padding(.horizontal, 30)
                            .padding(.vertical, 15)
                            .background(isRunning ? Color.orange : Color.green)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                    
                    Button(action: updateTimer) {
                        Text("重置")
                            .font(.title3)
                            .padding(.horizontal, 30)
                            .padding(.vertical, 15)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                    .disabled(isRunning)
                    .opacity(isRunning ? 0.6 : 1)
                }
                
            }
            .padding(.top)
            .navigationTitle("專注計時")
        }
    }
    
    private func timeString(from seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
    
    private func toggleTimer() {
        if isRunning {
            stopTimer()
        } else {
            startTimer()
        }
        isRunning.toggle()
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if isCountdown {
                if countdownTime > 0 {
                    countdownTime -= 1
                } else {
                    stopTimer()
                    soundManager.playSystemSound()
                }
            } else {
                countupTime += 1
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateTimer() {
        stopTimer()
        isRunning = false

        if isCountdown {
            countdownTime = selectedMinutes * 60
        } else {
            countupTime = 0
        }
    }
}

#Preview {
    TimerView()
}
