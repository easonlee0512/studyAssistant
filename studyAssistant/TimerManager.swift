import SwiftUI
import Combine

class TimerManager: ObservableObject {
    // 計時器基本屬性
    @Published var timeRemaining: TimeInterval = 1800 // 默認為30分鐘
    @Published var isRunning = false
    @Published var isCountUp = false // 控制是否為正向計時
    @Published var elapsedTime: TimeInterval = 0 // 正向計時已經過的時間
    @Published var progress: Double = 0.167 // 進度值，0.0-1.0之間，默認30分鐘(30/180)
    @Published var subject = "線性代數"
    
    // 時間組件
    @Published var hours: Int = 0
    @Published var minutes: Int = 30
    @Published var seconds: Int = 0
    
    // 記住上一次設定時間的變數
    @Published var lastUsedHours: Int = 0
    @Published var lastUsedMinutes: Int = 30
    @Published var lastUsedSeconds: Int = 0
    @Published var hasUsedBefore: Bool = false // 標記是否已經使用過
    
    // 其他設定
    @Published var selectedTime: Int = 30 // 默認選中30分鐘
    let minTime: Int = 0 // 最少0分鐘
    let maxTime: Int = 180 // 最多3小時
    
    // 計時器
    private var timer: Timer?
    private var timerSubscription: AnyCancellable?
    
    init() {
        // 初始化時分秒
        updateTimeComponents()
    }
    
    // 更新時間組件
    func updateTimeComponents() {
        hours = Int(timeRemaining) / 3600
        minutes = (Int(timeRemaining) / 60) % 60
        seconds = Int(timeRemaining) % 60
    }
    
    // 根據時間組件更新計時器
    func updateTimer() {
        // 限制小時數最大為3，超過時重置分鐘和秒數為0
        if hours > 3 {
            hours = 3
            minutes = 0
            seconds = 0
        }
        // 當小時數為3時，分鐘和秒數也必須為0
        else if hours == 3 {
            minutes = 0
            seconds = 0
        }
        
        timeRemaining = TimeInterval(hours * 3600 + minutes * 60 + seconds)
        selectedTime = Int(timeRemaining / 60)
        
        // 更新進度條
        let totalSeconds = Double(maxTime - minTime) * 60
        progress = (timeRemaining - Double(minTime * 60)) / totalSeconds
        
        // 進度條範圍檢查
        if progress < 0 { progress = 0 }
        if progress > 1 { progress = 1 }
    }
    
    // 切換倒數/正數計時模式
    func toggleCountMode() {
        // 如果從正計時切換回倒數計時，且已經有初始設定過的時間，則使用初始設定的時間
        let shouldUseInitialTime = isCountUp && hasUsedBefore
        
        // 先停止現有計時器
        stopTimer()
        
        // 切換模式
        isCountUp.toggle()
        
        // 重置計時器並更新時間
        resetTimer()
        
        // 切換到正計時模式時
        if isCountUp {
            // 正計時模式下進度從0開始
            progress = 0.0
        } else {
            if shouldUseInitialTime {
                // 使用初始設定的時間
                hours = lastUsedHours
                minutes = lastUsedMinutes
                seconds = lastUsedSeconds
                updateTimer() // 更新timeRemaining和progress
            } else {
                // 未使用過，設置為預設30分鐘
                selectedTime = 30
                progress = Double(selectedTime - minTime) / Double(maxTime - minTime)
                timeRemaining = TimeInterval(selectedTime * 60)
                updateTimeComponents()
            }
        }
    }
    
    // Start or pause the timer
    func toggleTimer() {
        if isRunning {
            stopTimer()
            
            // 每次暫停時都更新最後使用的時間
            if !isCountUp {
                lastUsedHours = hours
                lastUsedMinutes = minutes
                lastUsedSeconds = seconds
                hasUsedBefore = true
            }
        } else {
            if isCountUp {
                // 正向計時
                startCountUpTimer()
            } else {
                // 倒數計時
                startCountDownTimer()
            }
        }
        
        isRunning.toggle()
    }
    
    // 啟動正向計時
    private func startCountUpTimer() {
        // 使用 Timer.publish 創建一個每秒觸發的發布者
        let timerPublisher = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
        
        timerSubscription = timerPublisher.sink { [weak self] _ in
            guard let self = self else { return }
            
            self.elapsedTime += 1
            // 更新正向計時的進度 (每小時為一個週期)
            let hourInSeconds: TimeInterval = 3600
            self.progress = (self.elapsedTime.truncatingRemainder(dividingBy: hourInSeconds)) / hourInSeconds
        }
    }
    
    // 啟動倒數計時
    private func startCountDownTimer() {
        // 如果是開始計時，記住當前設定的時間
        lastUsedHours = hours
        lastUsedMinutes = minutes
        lastUsedSeconds = seconds
        hasUsedBefore = true
        
        // 倒數計時 - 從當前設置的進度開始倒數
        let initialProgress = progress
        let totalTime = TimeInterval(selectedTime * 60)
        
        // 使用 Timer.publish 創建一個每秒觸發的發布者
        let timerPublisher = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
        
        timerSubscription = timerPublisher.sink { [weak self] _ in
            guard let self = self else { return }
            
            if self.timeRemaining > 0 {
                self.timeRemaining -= 1
                // 更新時間組件
                self.updateTimeComponents()
                // 更新倒數計時進度 - 從當前位置開始減少
                self.progress = self.timeRemaining / totalTime * initialProgress
            } else {
                self.stopTimer()
                self.isRunning = false
                self.progress = 0 // 倒數結束時進度歸零
                // 更新時間組件
                self.updateTimeComponents()
            }
        }
    }
    
    // 停止計時器
    private func stopTimer() {
        timerSubscription?.cancel()
        timerSubscription = nil
    }
    
    // Reset the timer to initial value
    func resetTimer() {
        stopTimer()
        isRunning = false
        
        if isCountUp {
            // 正向計時重置
            elapsedTime = 0
            progress = 0.0
        } else {
            // 倒數計時重置到第一次設定的時間（如果已經開始過）或當前設定的時間
            if hasUsedBefore {
                hours = lastUsedHours
                minutes = lastUsedMinutes
                seconds = lastUsedSeconds
                updateTimer() // 更新timeRemaining和progress
            } else {
                // 未開始過，保持當前設定
                timeRemaining = TimeInterval(selectedTime * 60)
                updateTimeComponents()
            }
        }
    }
    
    // 更新拖動進度
    func updateProgressFromDrag(progress: Double) {
        self.progress = progress
        
        // 根據進度計算時間（0分鐘到3小時）
        let timeRange = Double(maxTime - minTime)
        selectedTime = minTime + Int(timeRange * progress)
        
        // 更新倒數時間
        timeRemaining = TimeInterval(selectedTime * 60)
        
        // 更新時分秒
        updateTimeComponents()
    }
} 