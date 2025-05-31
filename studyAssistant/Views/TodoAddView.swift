//
//  testtodoaddview.swift
//  studyAssistant
//
//  Created by 李翊辰 on 2025/4/30.
//
//
//  testTodoaddView.swift
//  studyAssistant
//
//  Created by 李翊辰 on 2025/4/21.
//
import SwiftUI
import SwiftUICore
import FirebaseFirestore
import FirebaseAuth


struct TodoAddView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: TodoViewModel
    @EnvironmentObject var staticViewModel: StaticViewModel
    @Binding var isPresented: Bool
    
    // 額外的資料欄位
    @State private var selectedCategory: String = "未分類"
    @State private var repeatOption: RepeatType = .none
    @State private var offset: CGFloat = UIScreen.main.bounds.height // 用於動畫
    @State private var isDismissing = false // 標記是否正在關閉
    
    // 新增屬性以考慮底部 TabBar 的高度
    let tabBarHeight: CGFloat
    
    // 重複選項 - 在初始化時將 viewModel 的值同步到 repeatOption
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
    
    // 添加一個狀態變量保存 selectedDate
    @State private var selectedDate: Date
    
    /// 初始化方法，支援傳入 TabBar 高度
    /// - Parameters:
    ///   - viewModel: Todo 視圖模型，用於資料處理
    ///   - isPresented: 控制視圖顯示的綁定值
    ///   - selectedDate: 選中的日期
    ///   - tabBarHeight: TabBar 的高度，默認為 50，但在 TodoView 和 CalendarView 中會傳入實際計算的高度
    init(viewModel: TodoViewModel, isPresented: Binding<Bool>, selectedDate: Date, tabBarHeight: CGFloat = 50) {
        self.viewModel = viewModel
        self._isPresented = isPresented
        self.tabBarHeight = tabBarHeight
        // 暫時保存 selectedDate，稍後在 onAppear 中使用
        self._selectedDate = State(initialValue: selectedDate)
        self._repeatOption = State(initialValue: .none)
    }
    
    // 計算滾動視圖的最大高度，考慮 TabBar 和其他元素
    private var scrollViewMaxHeight: CGFloat {
        let screenHeight = UIScreen.main.bounds.height
        let formHeaderHeight: CGFloat = 120 // 頭部標題和拖動指示器的大致高度
        let bottomMargin: CGFloat = 20 // 底部安全距離
        
        // 計算兩種高度並取較小值：
        // 1. 屏幕高度的 75%
        // 2. 剩餘可用空間（屏幕高度 - 頭部 - TabBar - 底部邊距）
        // 注意：tabBarHeight 可能在不同視圖中有不同的值
        let percentHeight = screenHeight * 0.75
        let availableHeight = screenHeight - formHeaderHeight - tabBarHeight - bottomMargin
        
        // 確保最小高度至少有足夠空間顯示幾個表單項
        return max(300, min(percentHeight, availableHeight))
    }
    
    var body: some View {
        // 主要表單容器
        mainContentView
            .background(backgroundColor)
            .cornerRadius(25, corners: [.topLeft, .topRight])
            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: -5)
            .offset(y: offset) // 這行是為了讓視圖在底部顯示
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
                // 在視圖出現時初始化表單
                viewModel.initNewTaskForm(selectedDate: selectedDate)
                repeatOption = viewModel.newTaskRepeatType
                viewModel.errorMessage = nil
                viewModel.isLoading = false
                
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
            if let errorMessage = viewModel.errorMessage {
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
                    
                    // 增加底部間距，確保所有內容都可見
                    Spacer().frame(height: max(20, tabBarHeight))
                }
                .padding(.horizontal)
            }
            .frame(maxHeight: scrollViewMaxHeight) // 使用計算得到的最大高度
            
            // 正在保存的指示器
            if viewModel.isLoading {
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
            Button("取消") {
                dismissWithAnimation()
            }
            .font(.system(size: 20, weight: .medium))
            .foregroundColor(Color.black)
            
            Spacer()
            
            Text("新增任務")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color.black)
            
            Spacer()
            
            Button("儲存") {
                saveTask()
            }
            .font(.system(size: 20, weight: .medium))
            .foregroundColor(viewModel.isLoading ? Color.gray :
                             (viewModel.newTaskTitle.isEmpty ? Color.blue.opacity(0.5) : Color.blue))
            .disabled(viewModel.isLoading || viewModel.newTaskTitle.isEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 15)
    }
    
    // 標題和備註欄位
    private var titleAndNoteFields: some View {
        VStack(spacing: 0) {
            TextField("標題", text: $viewModel.newTaskTitle)
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(Color.black)
                .padding(.horizontal, 10)
                .padding(.vertical, 15)
                .environment(\.colorScheme, .light)  
            
            Divider()
                .background(dividerColor)
                .padding(.horizontal, 5)
            
            TextField("備註", text: $viewModel.newTaskNote)
                .font(.system(size: 18))
                .foregroundColor(Color.black)
                .padding(.horizontal, 10)
                .padding(.vertical, 15)
                .environment(\.colorScheme, .light)  
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
                    .foregroundColor(Color.black)
                
                Spacer()
                
                Toggle("", isOn: $viewModel.newTaskIsAllDay)
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
                    .foregroundColor(Color.black)
                
                Spacer()
                
                if viewModel.newTaskIsAllDay {
                    DatePicker("", selection: $viewModel.newTaskStartDate, displayedComponents: .date)
                        .labelsHidden()
                        .accentColor(Color.black)
                        .colorScheme(.light)  // 強制使用淺色模式顯示
                } else {
                    DatePicker("", selection: $viewModel.newTaskStartDate, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                        .accentColor(Color.black)
                        .colorScheme(.light)  // 強制使用淺色模式顯示
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
                    .foregroundColor(Color.black)
                
                Spacer()
                
                if viewModel.newTaskIsAllDay {
                    DatePicker("", selection: $viewModel.newTaskEndDate, displayedComponents: .date)
                        .labelsHidden()
                        .accentColor(Color.black)
                        .colorScheme(.light)  // 強制使用淺色模式顯示
                } else {
                    DatePicker("", selection: $viewModel.newTaskEndDate, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                        .accentColor(Color.black)
                        .colorScheme(.light)  // 強制使用淺色模式顯示
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
        ColorPickerView(selectedColor: $viewModel.newTaskColor, backgroundColor: backgroundColor)
    }
    
    // 類別選擇器
    private var categoryPickerView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("類別")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color.black)
                
                Spacer()
                
                TextField("類別", text: $viewModel.newTaskCategory)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(Color.black)
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
                    .foregroundColor(Color.black)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(width: 50, alignment: .leading)
                    .padding(.horizontal, 15)
                
                Spacer()
                
                // 使用Menu替代Picker，以便更好地控制對齊
                Menu {
                    Button("不重複") { 
                        repeatOption = .none
                        viewModel.newTaskRepeatType = .none
                    }
                    Button("每天") { 
                        repeatOption = .daily
                        viewModel.newTaskRepeatType = .daily
                    }
                    Button("每週") { 
                        repeatOption = .weekly
                        viewModel.newTaskRepeatType = .weekly
                    }
                    Button("每月") { 
                        repeatOption = .monthly
                        viewModel.newTaskRepeatType = .monthly
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
                        .foregroundColor(Color.black)
                    
                    Spacer()
                    
                    DatePicker("", selection: Binding(
                        get: { viewModel.newTaskRepeatEndDate ?? Date() },
                        set: { viewModel.newTaskRepeatEndDate = $0 }
                    ), displayedComponents: .date)
                        .labelsHidden()
                        .accentColor(Color.black)
                        .colorScheme(.light)  // 強制使用淺色模式顯示
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
    
    // 格式化日期
    private func formatDate(_ date: Date, isDateOnly: Bool) -> String {
        let formatter = DateFormatter()
        if isDateOnly {
            formatter.dateFormat = "M月 d日 EEE"
        } else {
            formatter.dateFormat = "M月 d日 EEE HH:mm"
        }
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
    
    // 關閉視圖帶動畫
    private func dismissWithAnimation() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isDismissing = true
            offset = UIScreen.main.bounds.height
        }
        
        // 延遲關閉以等待動畫完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isPresented = false
        }
    }
    
    // 驗證表單
    private func validateForm() -> Bool {
        // 重置錯誤訊息
        viewModel.errorMessage = nil
        
        // 標題不能為空
        if viewModel.newTaskTitle.isEmpty {
            viewModel.errorMessage = "請輸入任務標題"
            return false
        }
        
        // 確保結束時間晚於開始時間
        if viewModel.newTaskEndDate < viewModel.newTaskStartDate && repeatOption == .none {
            viewModel.errorMessage = "結束時間必須晚於開始時間"
            return false
        }
        
        // 確保已經登入
        if Auth.auth().currentUser == nil {
            viewModel.errorMessage = "請先登入再新增任務"
            return false
        }
        
        return true
    }
    
    // 儲存任務
    private func saveTask() {
        // 已經在保存中，避免重複觸發
        if viewModel.isLoading {
            return
        }
        
        // 驗證表單
        if !validateForm() {
            return
        }
        
        // 開始關閉動畫
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isDismissing = true
            offset = UIScreen.main.bounds.height
        }
        
        // 延遲執行保存操作，等待關閉動畫完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            // 確保離線操作時 UI 不會卡住
            viewModel.isLoading = true
            
            Task {
                do {
                    // 將重複選項資料傳遞給 viewModel
                    viewModel.newTaskRepeatType = repeatOption
                    
                    // 獲取當前使用者 ID
                    let userId = Auth.auth().currentUser?.uid ?? "default"
                    
                    // 創建任務，確保包含用戶 ID
                    let task = TodoTask(
                        title: viewModel.newTaskTitle,
                        note: viewModel.newTaskNote,
                        color: viewModel.newTaskColor,
                        focusTime: viewModel.newTaskFocusTime,
                        category: viewModel.newTaskCategory,
                        isAllDay: viewModel.newTaskIsAllDay,
                        isCompleted: false,
                        repeatType: viewModel.newTaskRepeatType,
                        startDate: viewModel.newTaskStartDate,
                        endDate: viewModel.newTaskEndDate,
                        userId: userId
                    )
                    
                    // 使用 addTask 而非 saveNewTask 以確保處理好 userId
                    await viewModel.addTask(task)
                    
                    // 檢查並為新類別創建統計記錄
                    await checkAndCreateStatisticsForCategory(viewModel.newTaskCategory)
                    
                    // 延遲關閉視圖
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isPresented = false
                    }
                } catch {
                    // 顯示錯誤訊息
                    viewModel.errorMessage = error.localizedDescription
                    viewModel.isLoading = false
                    print("Error saving task: \(error.localizedDescription)")
                    
                    // 如果保存失敗，恢復視圖
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isDismissing = false
                        offset = 0
                    }
                }
            }
        }
    }
    
    // 檢查並創建類別統計記錄
    private func checkAndCreateStatisticsForCategory(_ category: String) async {
        // 如果類別為空或為「未分類」，則不創建統計
        guard !category.isEmpty && category != "未分類" else {
            return
        }
        
        // 檢查此類別是否已存在於統計中
        let existingCategories = staticViewModel.statistics.map { $0.category }
        
        // 如果此類別不存在，建立新的統計記錄
        if !existingCategories.contains(category) {
            print("正在為新類別 \(category) 創建統計記錄")
            
            let newStatistic = LearningStatistic(
                userId: Auth.auth().currentUser?.uid ?? "default",
                category: category,
                progress: 0.0,
                taskcount: 1,
                taskcompletecount: 0,
                totalFocusTime: 0,
                date: Date(),
                updatedAt: Date(),
                version: 1
            )
            
            let result = await staticViewModel.saveStatistic(newStatistic)
            if result {
                print("已成功為新類別 \(category) 創建統計記錄")
            } else {
                print("創建統計記錄失敗：\(staticViewModel.errorMessage ?? "未知錯誤")")
            }
        }
    }
}

// 為了預覽提供空的任務列表
struct TodoAddView_Previews: PreviewProvider {
    @State static var isShown = true
    static var viewModel = TodoViewModel()
    
    static var previews: some View {
        TodoAddView(viewModel: viewModel, isPresented: $isShown, selectedDate: Date())
            .environmentObject(viewModel)
    }
}

// 擴展 View 以支援部分圓角
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

// 自定義形狀以實現部分圓角
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

// 顏色選擇器視圖
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
                    .foregroundColor(Color.black)
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

