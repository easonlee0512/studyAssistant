//
//  TodoEditView.swift
//  studyAssistant
//
//  Created by 李翊辰 on 2025/5/6.
//

import SwiftUI
import SwiftUICore
import FirebaseFirestore
import FirebaseAuth

struct TodoEditView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: TodoViewModel
    @Binding var isPresented: Bool
    
    // 需要編輯的任務
    let task: TodoTask
    
    // 額外的資料欄位
    @State private var title: String
    @State private var note: String
    @State private var color: Color
    @State private var category: String
    @State private var isAllDay: Bool
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var repeatOption: RepeatType
    @State private var repeatEndDate: Date?
    @State private var offset: CGFloat = UIScreen.main.bounds.height // 用於動畫
    @State private var isDismissing = false // 標記是否正在關閉
    @State private var isLoading = false // 是否正在保存
    @State private var errorMessage: String? = nil // 錯誤信息
    @State private var showDeleteConfirmation = false  // 用於顯示刪除確認對話框
    @State private var isDeletingTask = false  // 用於追蹤刪除狀態
    
    // 新增屬性以考慮底部 TabBar 的高度
    let tabBarHeight: CGFloat
    
    // 重複選項
    let repeatOptions: [RepeatType] = [
        .none,
        .daily,
        .weekly,
        .monthly
    ]
    
    // Figma 設計中的顏色
    let backgroundColor = Color(red: 254/255, green: 236/255, blue: 216/255) // #FEECD8
    let dividerColor = Color(red: 188/255, green: 175/255, blue: 160/255) // #BCAFA0
    let textColor = Color.black
    let placeholderColor = Color.black.opacity(0.2)
    let categoryColor = Color(red: 178/255, green: 41/255, blue: 34/255, opacity: 0.4)
    let mainBackgroundColor = Color(red: 243/255, green: 212/255, blue: 183/255) // #F3D4B7
    
    // 計算滾動視圖的最大高度，考慮 TabBar 和其他元素
    private var scrollViewMaxHeight: CGFloat {
        let screenHeight = UIScreen.main.bounds.height
        let formHeaderHeight: CGFloat = 120 // 頭部標題和拖動指示器的大致高度
        let bottomMargin: CGFloat = 20 // 底部安全距離
        
        // 計算兩種高度並取較小值：
        // 1. 屏幕高度的 75%
        // 2. 剩餘可用空間（屏幕高度 - 頭部 - TabBar - 底部邊距）
        let percentHeight = screenHeight * 0.75
        let availableHeight = screenHeight - formHeaderHeight - tabBarHeight - bottomMargin
        
        // 確保最小高度至少有足夠空間顯示幾個表單項
        return max(300, min(percentHeight, availableHeight))
    }
    
    init(viewModel: TodoViewModel, isPresented: Binding<Bool>, task: TodoTask, tabBarHeight: CGFloat = 50) {
        self.viewModel = viewModel
        self._isPresented = isPresented
        self.task = task
        self.tabBarHeight = tabBarHeight
        
        // 預填充任務數據
        self._title = State(initialValue: task.title)
        self._note = State(initialValue: task.note)
        self._color = State(initialValue: task.color)
        self._category = State(initialValue: task.category)
        self._isAllDay = State(initialValue: task.isAllDay)
        self._startDate = State(initialValue: task.startDate)
        self._endDate = State(initialValue: task.endDate)
        self._repeatOption = State(initialValue: task.repeatType)
        self._repeatEndDate = State(initialValue: task.repeatEndDate)
    }
    
    var body: some View {
        // 主要表單容器
        mainContentView
            .background(backgroundColor)
            .cornerRadius(25, corners: [.topLeft, .topRight])
            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: -5)
            .offset(y: offset)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: offset)
            .edgesIgnoringSafeArea(.bottom)
            .ignoresSafeArea(.keyboard) // 忽略鍵盤
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        let newOffset = max(0, gesture.translation.height)
                        offset = newOffset
                        // 當開始滑動時就關閉鍵盤
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                     to: nil, from: nil, for: nil)
                    }
                    .onEnded { gesture in
                        if gesture.translation.height > 100 {
                            dismissWithAnimation()
                        } else {
                            // 恢復到 TabBar 對齊的位置
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                offset = tabBarHeight
                            }
                        }
                    }
            )
            .transition(.move(edge: .bottom))
            .onAppear {
                // 動畫展示 - 考慮 TabBar 的高度
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    // 設置為 TabBar 的高度，保證位置與傳入的 tabBarHeight 一致
                    offset = tabBarHeight
                }
            }
    }
    
    // 表單容器
    private var mainContentView: some View {
        VStack(spacing: 0) {
            // 拖動指示器
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.gray.opacity(0.6))
                .frame(width: 40, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 15)
            
            // 頭部標題區域
            headerView
            
            // 錯誤訊息 (如果有的話)
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.system(size: 14))
                    .padding(.horizontal)
                    .padding(.bottom, 5)
            }
            
            // 滾動內容區域
            ScrollView {
                VStack(spacing: 15) {
                    // 標題和備註
                    titleAndNoteFields
                    
                    // 全天開關
                    allDayToggle
                    
                    // 時間設定
                    dateSelectionView
                    
                    // 顏色選擇
                    colorPickerView
                    
                    // 類別選擇
                    categoryPickerView
                    
                    // 重複選項
                    repeatOptionView
                    Divider()
                    .background(dividerColor)
                    .padding(.horizontal, 15)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .frame(maxHeight: scrollViewMaxHeight)
            
            // 正在保存的指示器
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding()
                    Spacer()
                }
            }
        }
    }
    
    // 標題區域
    private var headerView: some View {
        HStack {
            Button("刪除") {
                showDeleteConfirmation = true
            }
            .font(.system(size: 20, weight: .medium))
            .foregroundColor(.red)
            .disabled(isDeletingTask || isLoading)
            
            Spacer()
            
            Text("編輯任務")
                .font(.system(size: 20, weight: .bold))
            
            Spacer()
            
            Button("儲存") {
                saveTask()
            }
            .font(.system(size: 20, weight: .medium))
            .foregroundColor(isLoading || isDeletingTask ? Color.gray :
                             (title.isEmpty ? Color.blue.opacity(0.5) : Color.blue))
            .disabled(isLoading || isDeletingTask || title.isEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 15)
        .alert("確認刪除", isPresented: $showDeleteConfirmation) {
            Button("取消", role: .cancel) { }
            Button("刪除", role: .destructive) {
                deleteTask()
            }
        } message: {
            Text("確定要刪除這個任務嗎？此操作無法復原。")
        }
    }
    
    // 標題和備註欄位
    private var titleAndNoteFields: some View {
        VStack(spacing: 0) {
            TextField("標題", text: $title)
                .font(.system(size: 24, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 15)
            
            Divider()
                .background(dividerColor)
                .padding(.horizontal, 5)
            
            TextField("備註", text: $note)
                .font(.system(size: 18))
                .padding(.horizontal, 10)
                .padding(.vertical, 15)
            
            Divider()
                .background(dividerColor)
                .padding(.horizontal, 5)
        }
        .background(backgroundColor)
        .cornerRadius(10)
    }
    
    // 全天開關
    private var allDayToggle: some View {
        VStack(spacing: 0) {
            HStack {
                Text("整天")
                    .font(.system(size: 18, weight: .medium))
                
                Spacer()
                
                Toggle("", isOn: $isAllDay)
                    .labelsHidden()
                    .padding(.trailing, 8)  // 右移 8 點
                    .frame(width: 51, height: 31)  // 固定開關大小
                    .contentShape(Rectangle())  // 增加點擊區域但保持圖片大小
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 12)
            
            Divider()
                .background(dividerColor)
                .padding(.horizontal, 15)
        }
        .background(backgroundColor)
        .cornerRadius(10)
    }
    
    // 日期選擇視圖
    private var dateSelectionView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("開始")
                    .font(.system(size: 18, weight: .medium))
                
                Spacer()
                
                if isAllDay {
                    DatePicker("", selection: $startDate, displayedComponents: .date)
                        .labelsHidden()
                } else {
                    DatePicker("", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                }
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 12)
            
            Divider()
                .background(dividerColor)
                .padding(.horizontal, 15)
            
            HStack {
                Text("結束")
                    .font(.system(size: 18, weight: .medium))
                
                Spacer()
                
                if isAllDay {
                    DatePicker("", selection: $endDate, displayedComponents: .date)
                        .labelsHidden()
                } else {
                    DatePicker("", selection: $endDate, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                }
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 12)

            Divider()
                .background(dividerColor)
                .padding(.horizontal, 15)
        }
        .background(backgroundColor)
        .cornerRadius(10)
    }
    
    // 顏色選擇器
    private var colorPickerView: some View {
        ColorPickerView(selectedColor: $color, backgroundColor: backgroundColor)
    }
    
    // 類別選擇器
    private var categoryPickerView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("類別")
                    .font(.system(size: 18, weight: .medium))
                
                Spacer()
                
                TextField("類別", text: $category)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 150)
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 12)

            Divider()
                .background(dividerColor)
                .padding(.horizontal, 15)
        }
        .background(backgroundColor)
        .cornerRadius(10)
    }
    
    // 重複選項視圖
    private var repeatOptionView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("重複")
                    .font(.system(size: 18, weight: .medium))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(width: 50, alignment: .leading)
                    .padding(.horizontal, 15)
                
                Spacer()
                
                // 使用Menu替代Picker，以便更好地控制對齊
                Menu {
                    Button("不重複") { 
                        repeatOption = .none
                    }
                    Button("每天") { 
                        repeatOption = .daily
                    }
                    Button("每週") { 
                        repeatOption = .weekly
                    }
                    Button("每月") { 
                        repeatOption = .monthly
                    }
                } label: {
                    HStack {
                        Spacer()
                        Text(repeatOptionText)
                            .foregroundColor(.black)
                            .frame(width: 60, alignment: .trailing)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 13))
                            .foregroundColor(.black)
                    }
                    .frame(width: 90)
                }
                .padding(.trailing, 15)
            }
            .padding(.vertical, 12)


            // 新增重複結束日期選擇器
            if repeatOption != .none {
                Divider()
                    .background(dividerColor)
                    .padding(.horizontal, 15)
                
                HStack {
                    Text("重複結束")
                        .font(.system(size: 18, weight: .medium))
                    
                    Spacer()
                    
                    DatePicker("", selection: Binding(
                        get: { repeatEndDate ?? Date() },
                        set: { repeatEndDate = $0 }
                    ), displayedComponents: .date)
                        .labelsHidden()
                }
                .padding(.horizontal, 15)
                .padding(.vertical, 12)
            }
        }
        .background(backgroundColor)
        .cornerRadius(10)
    }
    
    // 根據選擇的重複選項返回對應的文字
    private var repeatOptionText: String {
        switch repeatOption {
        case .none:
            return "不重複"
        case .daily:
            return "每天"
        case .weekly:
            return "每週"
        case .monthly:
            return "每月"
        }
    }
    
    // 關閉視圖帶動畫
    private func dismissWithAnimation() {
        isDismissing = true
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            offset = UIScreen.main.bounds.height
        }
        
        // 觸發資料重新載入
        Task {
            do {
                try await viewModel.loadTasks()
            } catch {
                print("Error reloading tasks: \(error)")
            }
        }
        
        // 延遲關閉視窗
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeInOut(duration: 0.3)) {
                isPresented = false
            }
        }
    }
    
    // 驗證表單
    private func validateForm() -> Bool {
        // 重置錯誤訊息
        errorMessage = nil
        
        // 標題不能為空
        if title.isEmpty {
            errorMessage = "請輸入任務標題"
            return false
        }
        
        // 確保結束時間晚於開始時間
        if endDate < startDate && repeatOption == .none {
            errorMessage = "結束時間必須晚於開始時間"
            return false
        }
        
        // 確保已經登入
        if Auth.auth().currentUser == nil {
            errorMessage = "請先登入再編輯任務"
            return false
        }
        
        return true
    }
    
    // 儲存任務
    private func saveTask() {
        // 已經在保存中，避免重複觸發
        if isLoading {
            return
        }
        
        // 驗證表單
        if !validateForm() {
            return
        }
        
        // 確保離線操作時 UI 不會卡住
        isLoading = true
        
        Task {
            do {
                // 創建更新後的任務
                var updatedTask = task
                updatedTask.title = title
                updatedTask.note = note
                updatedTask.color = color
                updatedTask.category = category
                updatedTask.isAllDay = isAllDay
                updatedTask.repeatType = repeatOption
                updatedTask.startDate = startDate
                updatedTask.endDate = endDate
                updatedTask.repeatEndDate = repeatOption != .none ? repeatEndDate : nil
                
                // 使用 updateTask 方法更新任務
                try await viewModel.updateTask(updatedTask)
                
                // 任務保存成功後關閉視圖
                dismissWithAnimation()
            } catch {
                // 顯示錯誤訊息
                errorMessage = error.localizedDescription
                isLoading = false
                print("Error updating task: \(error.localizedDescription)")
            }
        }
    }
    
    // 新增刪除任務的方法
    private func deleteTask() {
        // 避免重複刪除
        if isDeletingTask {
            return
        }
        
        isDeletingTask = true
        errorMessage = nil
        
        Task {
            do {
                // 刪除任務
                try await viewModel.deleteTask(task)
                
                // 關閉編輯視窗
                dismissWithAnimation()
            } catch {
                // 顯示錯誤訊息
                errorMessage = "刪除任務失敗：\(error.localizedDescription)"
                isDeletingTask = false
                print("Error deleting task: \(error)")
            }
        }
    }
}

// ColorPickerView 與 TodoAddView 中的相同
private struct ColorPickerView: View {
    @Binding var selectedColor: Color
    let backgroundColor: Color
    let dividerColor = Color(red: 188/255, green: 175/255, blue: 160/255)
    let colorOptions: [Color] = [
        Color(red: 0.7, green: 0.16, blue: 0.13).opacity(0.4),
        Color(red: 0.7, green: 0.56, blue: 0).opacity(0.4),
        Color(red: 0.18, green: 0.7, blue: 0.31).opacity(0.4),
        Color(red: 0.29, green: 0.28, blue: 0.7).opacity(0.4)
    ]
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 20) {
                Text("顏色")
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 48, alignment: .leading)
                Spacer()
                HStack(spacing: 20) {
                    ForEach(colorOptions, id: \.self) { color in
                        Circle()
                            .fill(color)
                            .frame(width: 30, height: 30)
                            .overlay(
                                Circle()
                                    .stroke(selectedColor == color ? Color.black : Color.clear, lineWidth: 2)
                            )
                            .onTapGesture {
                                selectedColor = color
                            }
                    }
                }
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 15)
            Divider()
                .background(dividerColor)
                .padding(.horizontal, 15)
        }
        .background(backgroundColor)
        .cornerRadius(10)
    }
}

#Preview {
    // 提供一個示例任務以供預覽
    let exampleTask = TodoTask(
        title: "示例任務",
        note: "這是一個示例任務",
        color: Color(red: 0.7, green: 0.16, blue: 0.13).opacity(0.4),
        focusTime: 0,
        category: "未分類",
        isAllDay: false,
        isCompleted: false,
        repeatType: .none,
        startDate: Date(),
        endDate: Date().addingTimeInterval(3600),
        userId: "preview"
    )
    
    return TodoEditView(
        viewModel: TodoViewModel(),
        isPresented: .constant(true),
        task: exampleTask
    )
}

