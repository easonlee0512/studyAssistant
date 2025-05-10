//
//  ChatSettingView.swift
//  studyAssistant
//
//  Created by 李翊辰 on 2025/5/9.
//

import SwiftUI
import FirebaseFirestore

struct ChatSettingView: View {
    // 色票 - 與主畫面保持一致
    private let backgroundColor = Color.hex(hex: "F3D4B7")
    private let accentColor = Color.hex(hex: "E27844")
    private let cardColor = Color.hex(hex: "FEECD8")
    private let textColor = Color.black.opacity(0.8)
    
    // ViewModel 引用
    @EnvironmentObject private var viewModel: ChatViewModel
    
    // 臨時存儲設定變更
    @State private var tempSettings: StudySettings?
    @State private var selectedDayForTimeSettings: Int = 1
    @State private var selectedDaysSet: Set<Int> = []
    
    // 每天的開始和結束時間（臨時用於UI顯示）
    @State private var dailyStartTimes: [Int: Date] = [:]
    @State private var dailyEndTimes: [Int: Date] = [:]
    
    // 狀態控制
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var showErrorAlert: Bool = false
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                backgroundColor.ignoresSafeArea()
                
                if viewModel.isLoadingSettings || isLoading {
                    ProgressView("載入中...")
                        .progressViewStyle(CircularProgressViewStyle())
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
                } else if let error = viewModel.settingsError ?? errorMessage {
                    VStack {
                        Text("發生錯誤")
                            .font(.headline)
                        Text(error)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .padding()
                        Button("重試") {
                            Task {
                                await viewModel.loadStudySettingsFromFirestore()
                            }
                        }
                        .padding()
                        .background(accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            // 讀書時間設定
                            if let settings = tempSettings {
                                settingCard(title: "讀書時間偏好") {
                                    VStack(alignment: .leading, spacing: 15) {
                                        Text("每次讀書時間：\(Int(settings.studyDuration)) 分鐘")
                                            .font(.system(size: 18))
                                        
                                        Slider(value: Binding(
                                            get: { settings.studyDuration },
                                            set: { tempSettings?.studyDuration = $0 }
                                        ), in: 15...240, step: 15)
                                            .accentColor(accentColor)
                                    }
                                }
                                
                                // 讀書日期設定
                                settingCard(title: "讀書日期偏好") {
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text("選擇習慣讀書的日子：")
                                            .font(.system(size: 18))
                                        
                                        weekdaysSelector
                                        
                                        if !selectedDaysSet.isEmpty {
                                            Divider()
                                                .padding(.vertical, 10)
                                            
                                            Text("選擇要設定時間的日子：")
                                                .font(.system(size: 18))
                                                .padding(.bottom, 5)
                                            
                                            // 選擇要設定時間的日子
                                            ScrollView(.horizontal, showsIndicators: false) {
                                                HStack(spacing: 10) {
                                                    ForEach(Array(selectedDaysSet).sorted(), id: \.self) { day in
                                                        Button(action: {
                                                            selectedDayForTimeSettings = day
                                                        }) {
                                                            Text(weekdaySymbol(for: day))
                                                                .font(.system(size: 18, weight: .bold))
                                                                .frame(width: 40, height: 40)
                                                                .background(selectedDayForTimeSettings == day ? accentColor : Color.white)
                                                                .foregroundColor(selectedDayForTimeSettings == day ? .white : textColor)
                                                                .cornerRadius(20)
                                                                .overlay(
                                                                    Circle()
                                                                        .stroke(accentColor, lineWidth: 2)
                                                                )
                                                        }
                                                    }
                                                }
                                            }
                                            .padding(.bottom, 10)
                                            
                                            // 顯示當前選擇日的設定
                                            if selectedDaysSet.contains(selectedDayForTimeSettings) {
                                                VStack(alignment: .leading, spacing: 15) {
                                                    Text("星期\(weekdaySymbol(for: selectedDayForTimeSettings))偏好時間：")
                                                        .font(.system(size: 18, weight: .bold))
                                                        .foregroundColor(accentColor)
                                                    
                                                    Text("偏好開始時間：")
                                                        .font(.system(size: 18))
                                                    
                                                    DatePicker("", selection: Binding(
                                                        get: { dailyStartTimes[selectedDayForTimeSettings] ?? Date() },
                                                        set: { 
                                                            dailyStartTimes[selectedDayForTimeSettings] = $0
                                                            updateTempSettingsTime()
                                                        }
                                                    ), displayedComponents: .hourAndMinute)
                                                        .datePickerStyle(.wheel)
                                                        .labelsHidden()
                                                        .frame(maxHeight: 150)
                                                    
                                                    Text("偏好結束時間：")
                                                        .font(.system(size: 18))
                                                    
                                                    DatePicker("", selection: Binding(
                                                        get: { dailyEndTimes[selectedDayForTimeSettings] ?? Date() },
                                                        set: { 
                                                            dailyEndTimes[selectedDayForTimeSettings] = $0
                                                            updateTempSettingsTime()
                                                        }
                                                    ), displayedComponents: .hourAndMinute)
                                                        .datePickerStyle(.wheel)
                                                        .labelsHidden()
                                                        .frame(maxHeight: 150)
                                                }
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 10)
                                                .background(Color.white.opacity(0.1))
                                                .cornerRadius(10)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("讀書習慣設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(accentColor)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("儲存") {
                        saveSettings()
                    }
                    .foregroundColor(accentColor)
                    .fontWeight(.bold)
                    .disabled(viewModel.isLoadingSettings || isLoading)
                }
            }
            .onAppear {
                loadSettingsFromViewModel()
            }
            .alert(isPresented: $showErrorAlert) {
                Alert(
                    title: Text("儲存失敗"),
                    message: Text(errorMessage ?? "未知錯誤"),
                    dismissButton: .default(Text("確定"))
                )
            }
        }
    }
    
    // 自定義卡片視圖
    private func settingCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(title)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(accentColor)
            
            content()
        }
        .padding()
        .background(cardColor)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.15), radius: 4, x: 2, y: 2)
    }
    
    // 星期選擇器
    private var weekdaysSelector: some View {
        HStack(spacing: 10) {
            ForEach(1...7, id: \.self) { day in
                Button(action: {
                    if selectedDaysSet.contains(day) {
                        selectedDaysSet.remove(day)
                        // 如果移除了當前選擇的日子，選擇另一個
                        if selectedDayForTimeSettings == day {
                            selectedDayForTimeSettings = selectedDaysSet.min() ?? 1
                        }
                    } else {
                        selectedDaysSet.insert(day)
                        // 如果是第一個選擇的日子，設為當前
                        if selectedDaysSet.count == 1 {
                            selectedDayForTimeSettings = day
                        }
                    }
                    // 更新臨時設定
                    tempSettings?.selectedDays = Array(selectedDaysSet)
                }) {
                    Text(weekdaySymbol(for: day))
                        .font(.system(size: 18, weight: .bold))
                        .frame(width: 40, height: 40)
                        .background(selectedDaysSet.contains(day) ? accentColor : Color.white)
                        .foregroundColor(selectedDaysSet.contains(day) ? .white : textColor)
                        .cornerRadius(20)
                        .overlay(
                            Circle()
                                .stroke(accentColor, lineWidth: 2)
                        )
                }
            }
        }
        .padding(.vertical, 5)
    }
    
    // 取得星期幾的符號
    private func weekdaySymbol(for day: Int) -> String {
        let symbols = ["一", "二", "三", "四", "五", "六", "日"]
        return day <= symbols.count ? symbols[day-1] : ""
    }
    
    // 從ViewModel載入設定
    private func loadSettingsFromViewModel() {
        if let settings = viewModel.studySettings {
            // 複製設定，創建可變副本
            self.tempSettings = settings
            self.selectedDaysSet = Set(settings.selectedDays)
            
            // 如果有選擇的日子，設定第一個為當前編輯的日子
            if let firstDay = settings.selectedDays.first {
                self.selectedDayForTimeSettings = firstDay
            }
            
            // 建立每日開始/結束時間的Date物件用於UI
            for day in 1...7 {
                dailyStartTimes[day] = settings.getStartTimeForDay(day)
                dailyEndTimes[day] = settings.getEndTimeForDay(day)
            }
        } else {
            // 如果ViewModel中還沒有設定，可能還在載入中
            Task {
                await viewModel.loadStudySettingsFromFirestore()
                // 重試載入
                if let settings = viewModel.studySettings {
                    self.tempSettings = settings
                    self.selectedDaysSet = Set(settings.selectedDays)
                    if let firstDay = settings.selectedDays.first {
                        self.selectedDayForTimeSettings = firstDay
                    }
                    for day in 1...7 {
                        dailyStartTimes[day] = settings.getStartTimeForDay(day)
                        dailyEndTimes[day] = settings.getEndTimeForDay(day)
                    }
                }
            }
        }
    }
    
    // 更新臨時設定中的時間
    private func updateTempSettingsTime() {
        guard var settings = tempSettings else { return }
        
        // 更新所有日子的時間設定
        for day in 1...7 {
            if let startTime = dailyStartTimes[day] {
                settings.setStartTimeForDay(day, date: startTime)
            }
            if let endTime = dailyEndTimes[day] {
                settings.setEndTimeForDay(day, date: endTime)
            }
        }
        
        self.tempSettings = settings
    }
    
    // 儲存設定
    private func saveSettings() {
        guard var settingsToSave = tempSettings else {
            errorMessage = "無法儲存設定，設定資料不完整"
            showErrorAlert = true
            return
        }
        
        // 確保選擇的日子已更新
        settingsToSave.selectedDays = Array(selectedDaysSet)
        
        // 顯示載入狀態
        isLoading = true
        
        // 同步到Firestore
        Task {
            do {
                await viewModel.updateStudySettings(settingsToSave)
                
                // 如果成功，關閉設定畫面
                if viewModel.settingsError == nil {
                    dismiss()
                } else {
                    // 顯示錯誤
                    errorMessage = viewModel.settingsError
                    showErrorAlert = true
                }
            } catch {
                // 處理錯誤
                errorMessage = error.localizedDescription
                showErrorAlert = true
            }
            
            isLoading = false
        }
    }
}

// 預覽
struct ChatSettingView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = ChatViewModel()
        ChatSettingView()
            .environmentObject(viewModel)
    }
}

