//
//  ChatSettingView.swift
//  studyAssistant
//
//  Created by 李翊辰 on 2025/5/9.
//

import FirebaseFirestore
import SwiftUI

struct ChatSettingView: View {
    // 色票 - 與主畫面保持一致
    private let backgroundColor = Color.hex(hex: "F3D4B7")
    private let accentColor = Color.hex(hex: "E27844")
    private let cardColor = Color.hex(hex: "FEECD8")
    private let textColor = Color.black

    // UserDefaults keys
    private let studyTimePreferenceKey = "isStudyTimePreferenceEnabled"
    private let studyDatePreferenceKey = "isStudyDatePreferenceEnabled"

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

    @State private var studyDuration: Double = 60
    @State private var tone: String = ""

    // 本地偏好設定
    @AppStorage("isStudyTimePreferenceEnabled") private var isStudyTimePreferenceEnabled: Bool = true
    @AppStorage("isStudyDatePreferenceEnabled") private var isStudyDatePreferenceEnabled: Bool = true

    init() {
        // 不在這裡設置初始值，而是在 onAppear 時從 viewModel 讀取
    }

    var body: some View {
        NavigationView {
            ZStack {
                backgroundColor.ignoresSafeArea()

                if let error = viewModel.settingsError ?? errorMessage {
                    VStack {
                        Text("發生錯誤")
                            .font(.headline)
                            .foregroundColor(Color.black)
                        Text(error)
                            .font(.body)
                            .foregroundColor(Color.black)
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
                            // GPT 語氣設定
                            settingCard(title: "助手語氣設定") {
                                VStack(alignment: .leading, spacing: 10) {
                                    TextField("請輸入助手語氣...", text: Binding(
                                        get: { tone },
                                        set: { newValue in
                                            tone = newValue
                                            // 當語氣設定改變時自動儲存
                                            autoSaveSettings()
                                        }
                                    ))
                                        .font(.system(size: 18))
                                        .foregroundColor(Color.black)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(
                                            Color.hex(hex: "FEECD8")
                                        )
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.black.opacity(0.1), lineWidth: 1)
                                        )
                                        .padding(.top, 2)

                                    Text("提示：可以設定為「多拉A夢」、「女朋友」等")
                                        .font(.system(size: 16))
                                        .foregroundColor(Color.black)
                                        .padding(.horizontal, 4)
                                        .padding(.top, 2)
                                }
                            }
                            // 讀書時間設定
                            if let settings = tempSettings {
                                settingCard(title: "讀書時間偏好") {
                                    VStack(alignment: .leading, spacing: 15) {
                                        Toggle(isOn: Binding(
                                            get: { isStudyTimePreferenceEnabled },
                                            set: { newValue in
                                                isStudyTimePreferenceEnabled = newValue
                                                tempSettings?.isStudyTimePreferenceEnabled = newValue
                                                // 當開關狀態改變時自動儲存
                                                autoSaveSettings()
                                            }
                                        )) {
                                            Text("啟用讀書時間偏好")
                                                .font(.system(size: 18))
                                                .foregroundColor(Color.black)
                                        }
                                        .tint(accentColor)
                                        .padding(.bottom, 5)

                                        if isStudyTimePreferenceEnabled {
                                            Text("每次讀書時間：\(Int(settings.studyDuration)) 分鐘")
                                                .font(.system(size: 18))
                                                .foregroundColor(Color.black)

                                            Slider(
                                                value: Binding(
                                                    get: { settings.studyDuration },
                                                    set: { newValue in
                                                        tempSettings?.studyDuration = newValue
                                                        // 當讀書時間改變時自動儲存
                                                        autoSaveSettings()
                                                    }
                                                ), in: 15...240, step: 15
                                            )
                                            .accentColor(accentColor)
                                        }
                                    }
                                }

                                // 讀書日期設定
                                settingCard(title: "讀書日期偏好") {
                                    VStack(alignment: .leading, spacing: 10) {
                                        Toggle(isOn: Binding(
                                            get: { isStudyDatePreferenceEnabled },
                                            set: { newValue in
                                                isStudyDatePreferenceEnabled = newValue
                                                tempSettings?.isStudyDatePreferenceEnabled = newValue
                                                // 當開關狀態改變時自動儲存
                                                autoSaveSettings()
                                            }
                                        )) {
                                            Text("啟用讀書日期偏好")
                                                .font(.system(size: 18))
                                                .foregroundColor(Color.black)
                                        }
                                        .tint(accentColor)
                                        .padding(.bottom, 5)

                                        if isStudyDatePreferenceEnabled {
                                            Text("選擇習慣讀書的日子：")
                                                .font(.system(size: 18))
                                                .foregroundColor(Color.black)

                                            weekdaysSelector

                                            if !selectedDaysSet.isEmpty {
                                                Divider()
                                                    .padding(.vertical, 10)

                                                Text("選擇要設定時間的日子：")
                                                    .font(.system(size: 18))
                                                    .foregroundColor(Color.black)
                                                    .padding(.bottom, 5)

                                                // 選擇要設定時間的日子
                                                ScrollView(.horizontal, showsIndicators: false) {
                                                    HStack(spacing: 10) {
                                                        ForEach(
                                                            Array(selectedDaysSet).sorted(), id: \.self
                                                        ) { day in
                                                            Button(action: {
                                                                selectedDayForTimeSettings = day
                                                            }) {
                                                                Text(weekdaySymbol(for: day))
                                                                    .font(
                                                                        .system(size: 18, weight: .bold)
                                                                    )
                                                                    .frame(width: 40, height: 40)
                                                                    .background(
                                                                        selectedDayForTimeSettings
                                                                            == day
                                                                            ? accentColor : Color.white
                                                                    )
                                                                    .foregroundColor(
                                                                        selectedDayForTimeSettings
                                                                            == day ? .white : Color.black
                                                                    )
                                                                    .cornerRadius(20)
                                                                    .overlay(
                                                                        Circle()
                                                                            .stroke(
                                                                                accentColor,
                                                                                lineWidth: 2)
                                                                    )
                                                            }
                                                        }
                                                    }
                                                }
                                                .padding(.bottom, 10)

                                                // 顯示當前選擇日的設定
                                                if selectedDaysSet.contains(selectedDayForTimeSettings)
                                                {
                                                    VStack(alignment: .leading, spacing: 15) {
                                                        Text(
                                                            "星期\(weekdaySymbol(for: selectedDayForTimeSettings))偏好時間："
                                                        )
                                                        .font(.system(size: 18, weight: .bold))
                                                        .foregroundColor(Color.black)

                                                        Text("偏好開始時間：")
                                                            .font(.system(size: 18))
                                                            .foregroundColor(Color.black)

                                                        DatePicker(
                                                            "",
                                                            selection: Binding(
                                                                get: {
                                                                    dailyStartTimes[
                                                                        selectedDayForTimeSettings]
                                                                        ?? Date()
                                                                },
                                                                set: {
                                                                    dailyStartTimes[
                                                                        selectedDayForTimeSettings] = $0
                                                                    updateTempSettingsTime()
                                                                }
                                                            ), displayedComponents: .hourAndMinute
                                                        )
                                                        .datePickerStyle(.wheel)
                                                        .labelsHidden()
                                                        .frame(maxHeight: 150)
                                                        .colorScheme(.light)
                                                        .accentColor(Color.black)

                                                        Text("偏好結束時間：")
                                                            .font(.system(size: 18))
                                                            .foregroundColor(Color.black)

                                                        DatePicker(
                                                            "",
                                                            selection: Binding(
                                                                get: {
                                                                    dailyEndTimes[
                                                                        selectedDayForTimeSettings]
                                                                        ?? Date()
                                                                },
                                                                set: {
                                                                    dailyEndTimes[
                                                                        selectedDayForTimeSettings] = $0
                                                                    updateTempSettingsTime()
                                                                }
                                                            ), displayedComponents: .hourAndMinute
                                                        )
                                                        .datePickerStyle(.wheel)
                                                        .labelsHidden()
                                                        .frame(maxHeight: 150)
                                                        .colorScheme(.light)
                                                        .accentColor(Color.black)
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

                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("讀書習慣設定")
            .navigationBarTitleDisplayMode(.inline)
            .foregroundColor(Color.black)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("返回") {
                        dismiss()
                    }
                    .foregroundColor(Color.black)
                }
                
                ToolbarItem(placement: .principal) {
                    Text("讀書習慣設定")
                        .font(.headline)
                        .foregroundColor(Color.black)
                }
            }
            .toolbarBackground(backgroundColor, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .onAppear {
                loadSettingsFromViewModel()
            }
            .alert(isPresented: $showErrorAlert) {
                Alert(
                    title: Text("儲存失敗")
                        .foregroundColor(Color.black),
                    message: Text(errorMessage ?? "未知錯誤")
                        .foregroundColor(Color.black),
                    dismissButton: .default(Text("確定")
                        .foregroundColor(Color.black))
                )
            }
        }
    }

    // 自定義卡片視圖
    private func settingCard<Content: View>(title: String, @ViewBuilder content: () -> Content)
        -> some View
    {
        VStack(alignment: .leading, spacing: 15) {
            Text(title)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Color.black)

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
                        if selectedDayForTimeSettings == day {
                            selectedDayForTimeSettings = selectedDaysSet.min() ?? 1
                        }
                    } else {
                        selectedDaysSet.insert(day)
                        if selectedDaysSet.count == 1 {
                            selectedDayForTimeSettings = day
                        }
                    }
                    tempSettings?.selectedDays = Array(selectedDaysSet)
                    // 當選擇的日子改變時自動儲存
                    autoSaveSettings()
                }) {
                    Text(weekdaySymbol(for: day))
                        .font(.system(size: 18, weight: .bold))
                        .frame(width: 40, height: 40)
                        .background(selectedDaysSet.contains(day) ? accentColor : Color.white)
                        .foregroundColor(selectedDaysSet.contains(day) ? .white : Color.black)
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
        return day <= symbols.count ? symbols[day - 1] : ""
    }

    // 從ViewModel載入設定
    private func loadSettingsFromViewModel() {
        if let settings = viewModel.studySettings {
            // 複製設定，創建可變副本
            self.tempSettings = settings
            
            // 從設定中讀取偏好設定的狀態，而不是從本地
            isStudyTimePreferenceEnabled = settings.isStudyTimePreferenceEnabled
            isStudyDatePreferenceEnabled = settings.isStudyDatePreferenceEnabled
            
            self.selectedDaysSet = Set(settings.selectedDays)
            self.studyDuration = settings.studyDuration
            self.tone = settings.tone

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
                    self.studyDuration = settings.studyDuration
                    self.tone = settings.tone
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
        
        // 自動儲存更新後的設定
        autoSaveSettings()
    }

    // 修改自動儲存方法，移除載入狀態
    private func autoSaveSettings() {
        guard var settingsToSave = tempSettings else { return }
        
        // 更新語氣設定
        settingsToSave.tone = tone
        
        // 確保選擇的日子已更新
        settingsToSave.selectedDays = Array(selectedDaysSet)
        
        // 使用本地儲存的偏好設定
        settingsToSave.isStudyTimePreferenceEnabled = isStudyTimePreferenceEnabled
        settingsToSave.isStudyDatePreferenceEnabled = isStudyDatePreferenceEnabled
        
        // 在背景執行儲存
        Task {
            do {
                await viewModel.updateStudySettings(settingsToSave)
                
                // 只在發生錯誤時顯示提示
                if let error = viewModel.settingsError {
                    await MainActor.run {
                        errorMessage = error
                        showErrorAlert = true
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showErrorAlert = true
                }
            }
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
