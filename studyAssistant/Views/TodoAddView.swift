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
    
    init(viewModel: TodoViewModel, isPresented: Binding<Bool>, selectedDate: Date) {
        self.viewModel = viewModel
        self._isPresented = isPresented
        // 暫時保存 selectedDate，稍後在 onAppear 中使用
        self._selectedDate = State(initialValue: selectedDate)
        self._repeatOption = State(initialValue: .none)
    }
    
    var body: some View {
        ZStack {
            // 半透明背景
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissWithAnimation()
                }
                .opacity(isDismissing ? 0 : 1)
            
            // 主要表單容器
            mainContentView
        }
        .onAppear {
            // 在視圖出現時初始化表單
            viewModel.initNewTaskForm(selectedDate: selectedDate)
            repeatOption = viewModel.newTaskRepeatType
            viewModel.errorMessage = nil
            viewModel.isLoading = false
            
            // 動畫展示
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                offset = 0
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
                    Divider()
                        .background(dividerColor)
                        .padding(.horizontal, 5)
                    
                    // 顏色選擇
                    colorPickerView
                    
                    // 類別選擇
                    categoryPickerView
                    
                    // 重複選項
                    repeatOptionView
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .frame(maxHeight: UIScreen.main.bounds.height * 0.7)
            
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
        .background(backgroundColor)
        .cornerRadius(25, corners: [.topLeft, .topRight])
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: -5)
        .offset(y: offset)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: offset)
        .edgesIgnoringSafeArea(.bottom)
        .gesture(
            DragGesture()
                .onChanged { gesture in
                    let newOffset = max(0, gesture.translation.height)
                    offset = newOffset
                }
                .onEnded { gesture in
                    if gesture.translation.height > 100 {
                        dismissWithAnimation()
                    } else {
                        offset = 0
                    }
                }
        )
        .transition(.move(edge: .bottom))
    }
    
    // 標題區域
    private var headerView: some View {
        HStack {
            Button("取消") {
                dismissWithAnimation()
            }
            .font(.system(size: 20, weight: .medium))
            .foregroundColor(.blue)
            
            Spacer()
            
            Text("新增任務")
                .font(.system(size: 20, weight: .bold))
            
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
                .padding(.horizontal, 10)
                .padding(.vertical, 15)
            
            Divider()
                .background(dividerColor)
                .padding(.horizontal, 5)
            
            TextField("備註", text: $viewModel.newTaskNote)
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
                
                Toggle("", isOn: $viewModel.newTaskIsAllDay)
                    .labelsHidden()
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
                
                if viewModel.newTaskIsAllDay {
                    DatePicker("", selection: $viewModel.newTaskStartDate, displayedComponents: .date)
                        .labelsHidden()
                } else {
                    DatePicker("", selection: $viewModel.newTaskStartDate, displayedComponents: [.date, .hourAndMinute])
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
                
                if repeatOption == .daily {
                    Text("無限期重複")
                        .font(.system(size: 18))
                        .foregroundColor(.gray)
                } else {
                    if viewModel.newTaskIsAllDay {
                        DatePicker("", selection: $viewModel.newTaskEndDate, displayedComponents: .date)
                            .labelsHidden()
                    } else {
                        DatePicker("", selection: $viewModel.newTaskEndDate, displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                    }
                }
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 12)
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
                
                Spacer()
                
                TextField("類別", text: $viewModel.newTaskCategory)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 150)
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 12)
        }
        .background(backgroundColor)
        .cornerRadius(10)
    }
    
    // 重複選項視圖
    private var repeatOptionView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("重複")
                    .font(.system(size: 18, weight: .medium))
                
                Spacer()
                
                Picker("", selection: $repeatOption) {
                    Text("不重複").tag(RepeatType.none)
                    Text("每天").tag(RepeatType.daily)
                    Text("每週").tag(RepeatType.weekly)
                    Text("每月").tag(RepeatType.monthly)
                }
                .pickerStyle(.menu)
                .accentColor(.black)
                .onChange(of: repeatOption) { newValue in
                    updateEndDateBasedOnRepeatOption(newValue)
                    viewModel.newTaskRepeatType = newValue
                }
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 12)
        }
        .background(backgroundColor)
        .cornerRadius(10)
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
        isDismissing = true
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            offset = UIScreen.main.bounds.height
        }
        
        // 觸發資料重新載入，確保其他視圖能看到新增的任務
        Task {
            do {
                try await viewModel.loadTasks()
            } catch {
                print("Error reloading tasks: \(error)")
            }
        }
        
        // 延遲關閉以等待動畫完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeInOut(duration: 0.3)) {
                isPresented = false
            }
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
                
                // 任務保存成功後關閉視圖
                dismissWithAnimation()
            } catch {
                // 顯示錯誤訊息
                viewModel.errorMessage = error.localizedDescription
                viewModel.isLoading = false
                print("Error saving task: \(error.localizedDescription)")
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
    
    // 更新結束日期基於重複選項
    private func updateEndDateBasedOnRepeatOption(_ option: RepeatType) {
        let calendar = Calendar.current
        
        switch option {
        case .daily:
            // 每天重複，是無限期的，使用與startDate相同的日期
            viewModel.newTaskEndDate = viewModel.newTaskStartDate
        case .weekly:
            // 每週重複，將結束日期設為startDate後一週
            if let oneWeekLater = calendar.date(byAdding: .day, value: 7, to: viewModel.newTaskStartDate) {
                viewModel.newTaskEndDate = oneWeekLater
            }
        case .monthly:
            // 每月重複，將結束日期設為startDate後一個月
            if let oneMonthLater = calendar.date(byAdding: .month, value: 1, to: viewModel.newTaskStartDate) {
                viewModel.newTaskEndDate = oneMonthLater
            }
        default:
            // 不重複，若endDate在startDate之前，則設為startDate
            if viewModel.newTaskEndDate < viewModel.newTaskStartDate {
                viewModel.newTaskEndDate = viewModel.newTaskStartDate
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

