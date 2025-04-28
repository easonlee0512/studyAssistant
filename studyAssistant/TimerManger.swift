//
//  TimerManger.swift
//  studyAssistant
//
//  Created by 李翊辰 on 2025/4/23.
//
// TimerManager 類別定義 - 使用時間差計算法
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
    
    // 記住按下開始時的初始時間設定(用於重置)
    private var initialHours: Int = 0
    private var initialMinutes: Int = 30
    private var initialSeconds: Int = 0
    
    // 其他設定
    @Published var selectedTime: Int = 30 // 默認選中30分鐘
    let minTime: Int = 0 // 最少0分鐘
    let maxTime: Int = 180 // 最多3小時
    
    // 時間差計算所需變數
    private var startTime: Date? = nil        // 開始計時的時間點
    private var pauseTime: Date? = nil        // 暫停時的時間點
    private var totalPausedTime: TimeInterval = 0  // 累計暫停時間
    private var initialTimeRemaining: TimeInterval = 0 // 開始倒數時的初始剩餘時間
    
    // UI 更新計時器
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
            // 暫停計時器
            pauseTimer()
            isRunning = false
        } else {
            // 啟動計時器
            startTimer()
            isRunning = true
        }
    }
    
    // 啟動計時器（正向或倒數）
    private func startTimer() {
        if startTime == nil {
            // 首次啟動計時器 - 記住當前設定的時間(用於重置)
            initialHours = hours
            initialMinutes = minutes
            initialSeconds = seconds
            
            // 記錄開始時間點
            startTime = Date()
            
            // 只在第一次開始計時時記住設定的時間（倒數計時模式）- 用於切換回倒數模式
            if !isCountUp && !hasUsedBefore {
                lastUsedHours = hours
                lastUsedMinutes = minutes
                lastUsedSeconds = seconds
                hasUsedBefore = true
            }
            
            // 倒數計時模式：記錄初始剩餘時間
            if !isCountUp {
                initialTimeRemaining = timeRemaining
                // 直接設置進度為1.0，避免從0開始的動畫
                //progress = 1.0
            }
        } else if pauseTime != nil {
            // 從暫停中恢復
            totalPausedTime += Date().timeIntervalSince(pauseTime!)
            pauseTime = nil
        }
        
        // 啟動UI更新計時器
        startDisplayTimer()
    }
    
    // 暫停計時器
    private func pauseTimer() {
        pauseTime = Date()
        stopDisplayTimer()
    }
    
    // 啟動UI顯示更新計時器
    private func startDisplayTimer() {
        stopDisplayTimer() // 確保之前的計時器已停止
        
        // 改為每秒更新一次，避免進度圓點頻繁跳動
        let timerPublisher = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
        
        timerSubscription = timerPublisher.sink { [weak self] _ in
            guard let self = self else { return }
            self.updateTimerDisplay()
        }
        
        // 立即更新一次顯示，確保不用等到下一個計時器觸發
        //updateTimerDisplay()
    }
    
    // 更新計時顯示
    private func updateTimerDisplay() {
        guard let startTime = startTime else { return }
        
        let now = Date()
        let pauseAdjustment = pauseTime != nil ? now.timeIntervalSince(pauseTime!) : 0
        let effectiveElapsedTime = now.timeIntervalSince(startTime) - totalPausedTime - pauseAdjustment
        
        if isCountUp {
            // 正向計時：直接顯示經過的時間
            elapsedTime = effectiveElapsedTime
            
            // 更新正向計時的進度 (每小時為一個週期)
            let hourInSeconds: TimeInterval = 3600
            progress = (elapsedTime.truncatingRemainder(dividingBy: hourInSeconds)) / hourInSeconds
        } else {
            // 倒數計時：計算剩餘時間
            timeRemaining = max(0, initialTimeRemaining - effectiveElapsedTime)
            
            // 更新時間組件
            updateTimeComponents()
            
            // 更新倒數計時進度 - 使用線性比例計算，避免跳動
            if initialTimeRemaining > 0 {
                progress = max(0, min(1, timeRemaining / initialTimeRemaining))
            } else {
                progress = 0
            }
            
            // 檢查計時器是否應該停止
            if timeRemaining <= 0 {
                stopTimer()
                isRunning = false
                progress = 0 // 倒數結束時進度歸零
            }
        }
    }
    
    // 停止UI更新計時器
    private func stopDisplayTimer() {
        timerSubscription?.cancel()
        timerSubscription = nil
    }
    
    // 停止所有計時器
    private func stopTimer() {
        stopDisplayTimer()
        pauseTime = nil
    }
    
    // Reset the timer to initial value
    func resetTimer() {
        stopTimer()
        isRunning = false
        startTime = nil
        pauseTime = nil
        totalPausedTime = 0
        
        if isCountUp {
            // 正向計時重置
            elapsedTime = 0
            progress = 0.0
        } else {
            // 重置到初始時間 - 使用開始計時時記錄的初始值
            if initialHours > 0 || initialMinutes > 0 || initialSeconds > 0 {
                // 使用開始時記錄的時間
                hours = initialHours
                minutes = initialMinutes
                seconds = initialSeconds
            } else if hasUsedBefore {
                // 如果沒有開始過，但有初始設定，使用上次記錄的時間
                hours = lastUsedHours
                minutes = lastUsedMinutes
                seconds = lastUsedSeconds
            } else {
                // 都沒有，使用默認值 30 分鐘
                hours = 0
                minutes = 30
                seconds = 0
            }
            
            // 更新計時器時間和進度
            updateTimer()
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
    
    // 從背景返回前景時調用
    func appWillEnterForeground() {
        if isRunning {
            // 返回前景時更新計時顯示，確保時間正確
            updateTimerDisplay()
            
            // 重新啟動UI更新計時器
            startDisplayTimer()
        }
    }
    
    // 進入背景時調用
    func appDidEnterBackground() {
        // 進入背景時，停止UI更新計時器，但保持計時狀態
        if isRunning {
            stopDisplayTimer()
        }
    }
}
