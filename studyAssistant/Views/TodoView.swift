//
//  testtodoviews.swift
//  studyAssistant
//
//  Created by 李翊辰 on 2025/4/30.
//
import SwiftUI
import SwiftUICore
import FirebaseFirestore
import FirebaseAuth
import Foundation // 確保可以訪問 NotificationConstants
// 添加 Date 擴展的引用

// TodoView 是主要的待辦事項視圖，顯示倒數計時、今日日期、一週的日曆以及待辦事項列表。
struct TodoView: View {
    @EnvironmentObject var viewModel: TodoViewModel
    @EnvironmentObject var settingsViewModel: UserSettingsViewModel // 添加 UserSettingsViewModel
    @EnvironmentObject var staticViewModel: StaticViewModel // 添加 StaticViewModel
    @State private var selectedDate = Date()
    @State private var showingAddTask = false
    @State private var showingTodoDetail = false
    @State private var isLoading = true
    @State private var showError = false
    @State private var errorMessage = ""
    
    // 新增編輯相關狀態變量
    @State private var showingEditTask = false
    @State private var taskToEdit: TodoTask? = nil
    
    // TabBar的高度 - 根據 TabBarNew 計算：圖標(40) + 頂部間距(25) + 底部間距(10) + 垂直內邊距(8) + 安全區域(20)
    private let tabBarHeight: CGFloat = 83
    
    // 取得顯示 TodoAddView 的位置 - 確保它被放置在 TabBar 的上方
    private var todoAddViewPosition: CGFloat {
        // 使用 tabBarHeight 來設置視圖的位置，讓它顯示在 TabBar 上方
        return tabBarHeight - 20  // 減去一些偏移以產生好看的重疊效果
    }
    
    // Figma中使用的顏色
    let backgroundColor = Color.hex(hex: "F3D4B7")
    let bottomBarColor = Color.hex(hex: "FEECD8")
    
    // 計算距離目標日期剩餘天數
    var daysRemaining: Int {
        // 使用用戶設定中的目標日期，而不是固定的 180 天
        let targetDate = settingsViewModel.userProfile.targetDate
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: targetDate)
        return components.day ?? 0
    }
    
    // 使用 UserDefaults 來存儲用戶標語
    private let userDefaults = UserDefaults.standard
    private let userGoalKey = "cached_user_goal"
    
    @State private var isInitialized = false
    @State private var lastLoadTime: Date? = nil
    @State private var lastUserProfileLoadTime: Date? = nil
    @State private var cachedUserGoal: String = ""
    
    init() {
        // 從 UserDefaults 加載緩存的標語
        _cachedUserGoal = State(initialValue: UserDefaults.standard.string(forKey: userGoalKey) ?? "")
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景色永遠存在
                backgroundColor
                    .ignoresSafeArea()
                
                // 載入指示器
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)  // 放大載入圈圈
                        .progressViewStyle(CircularProgressViewStyle())  // 使用圓形進度樣式
                }
                
                // 主要內容
                VStack(spacing: 0) {
                    VStack(spacing: 16) {
                        // 顯示用戶目標或默認倒數天數
                        VStack(alignment: .leading, spacing: 5) {
                            if !cachedUserGoal.isEmpty {
                                Text(cachedUserGoal)
                                    .font(.system(size: 30, weight: .bold))
                            } else {
                                // 顯示距離目標日期的倒數，使用 targetDate 的日期名稱
                                if daysRemaining >= 0 {
                                    Text("考試倒數 \(daysRemaining) 天")
                                        .font(.system(size: 30, weight: .bold))
                                } else {
                                    Text("\(formattedTargetDate) 已過期 \(abs(daysRemaining)) 天")
                                        .font(.system(size: 30, weight: .bold))
                                        .foregroundColor(.red)
                                }
                            }
                            
                            // 顯示當前日期
                            Text(formattedDate)
                                .font(.system(size: 24, weight: .bold))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top, 12)
                        
                        // 週曆視圖 - 使用新的WeekPagerView替換舊的WeekViewNew
                        WeekPagerView(selectedDate: $selectedDate)
                            .padding(.horizontal)
                        
                        // 待辦事項標題
                        HStack {
                            Text("To Do List")
                                .font(.system(size: 24, weight: .bold))
                            Spacer()
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    showingAddTask = true
                                }
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(Color.hex(hex: "E28A5F"))
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // 任務列表
                    ScrollView {
                        VStack(spacing: 15) {
                            ForEach(filteredTasks(for: selectedDate)) { task in
                                TodoItemView(task: task, isExample: false, onUpdate: { updatedTask in
                                    Task {
                                        do {
                                            // 不需要等待更新完成，直接返回讓 UI 保持響應
                                            Task {
                                                try await viewModel.toggleTaskCompletion(updatedTask)
                                            }
                                        } catch {
                                            showError = true
                                            errorMessage = error.localizedDescription
                                        }
                                    }
                                }, onTaskSelected: { selectedTask in
                                    taskToEdit = selectedTask
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        showingEditTask = true
                                    }
                                })
                            }
                            
                            if filteredTasks(for: selectedDate).isEmpty {
                                Text("目前沒有任務")
                                    .foregroundColor(.gray)
                                    .padding()
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 15)
                    }
                    .padding(.bottom, 0)
                }
                .opacity(isLoading ? 0.3 : 1) // 載入時降低透明度
                
                // 添加任務視圖
                if showingAddTask {
                    ZStack {
                        // 遮罩層
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                            .transition(.opacity)
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    showingAddTask = false
                                }
                            }
                        
                        // 新增任務視圖 - 傳遞正確的 TabBar 高度
                        TodoAddView(
                            viewModel: viewModel, 
                            isPresented: $showingAddTask, 
                            selectedDate: selectedDate,
                            tabBarHeight: todoAddViewPosition
                        )
                            .environmentObject(staticViewModel)
                            .transition(.move(edge: .bottom))
                    }
                    .zIndex(1)
                }
                
                // 任務詳情視圖
                Group {
                    if showingTodoDetail {
                        TodoDetailView(
                            viewModel: viewModel,
                            date: selectedDate,
                            isPresented: $showingTodoDetail
                        )
                        .transition(.scale)
                        .zIndex(1)
                    }
                }
                
                // 編輯任務視圖
                Group {
                    if showingEditTask && taskToEdit != nil {
                        ZStack {
                            // 遮罩層
                            Color.black.opacity(0.3)
                                .ignoresSafeArea()
                                .transition(.opacity)
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        showingEditTask = false
                                    }
                                }
                            
                            // 編輯任務視圖
                            TodoEditView(
                                viewModel: viewModel,
                                isPresented: $showingEditTask,
                                task: taskToEdit!,
                                tabBarHeight: todoAddViewPosition
                            )
                            .transition(.move(edge: .bottom))
                        }
                        .zIndex(1)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            // 每次視圖出現時檢查並更新標語
            let currentQuote = settingsViewModel.userProfile.motivationalQuote
            if !currentQuote.isEmpty {
                cachedUserGoal = currentQuote
                // 保存到 UserDefaults
                userDefaults.set(currentQuote, forKey: userGoalKey)
            } else if !cachedUserGoal.isEmpty {
                // 如果當前設定為空但有緩存，使用緩存的值
                settingsViewModel.userProfile.motivationalQuote = cachedUserGoal
            }
            
            if !isInitialized {
                isInitialized = true
            }
        }
        .task {
            // 監聽用戶設定變化
            NotificationCenter.default.addObserver(
                forName: .userProfileDidChange,
                object: nil,
                queue: .main
            ) { [self] _ in
                let newQuote = settingsViewModel.userProfile.motivationalQuote
                if !newQuote.isEmpty {
                    cachedUserGoal = newQuote
                    // 保存到 UserDefaults
                    userDefaults.set(newQuote, forKey: userGoalKey)
                }
            }
            
            // 只在必要時載入任務數據
            let currentTime = Date()
            let needsReload = lastLoadTime == nil || 
                             currentTime.timeIntervalSince(lastLoadTime!) > 300 // 5分鐘刷新一次
            
            if needsReload {
                await loadTasks(showLoadingIndicator: lastLoadTime == nil)
                lastLoadTime = Date()
            }
            
            // 設置通知監聽器
            NotificationCenter.default.addObserver(
                forName: .todoDataDidChange,
                object: nil,
                queue: .main
            ) { _ in
                Task {
                    await loadTasks(showLoadingIndicator: false)
                    lastLoadTime = Date()
                }
            }
        }
        .onChange(of: selectedDate) { newDate in
            // 當選擇的日期改變時，重新載入任務
            Task {
                await loadTasks(showLoadingIndicator: false)
            }
        }
        .onDisappear {
            NotificationCenter.default.removeObserver(self, name: .todoDataDidChange, object: nil)
            NotificationCenter.default.removeObserver(self, name: .userProfileDidChange, object: nil)
        }
        .alert("錯誤", isPresented: $showError) {
            Button("確定", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日"
        return formatter.string(from: selectedDate)
    }
    
    private var formattedTargetDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM月dd日"
        return formatter.string(from: settingsViewModel.userProfile.targetDate)
    }
    
    private func filteredTasks(for date: Date) -> [TodoTask] {
        viewModel.sortedTasks(by: date)
    }
    
    private func loadTasks(showLoadingIndicator: Bool = true) async {
        if showLoadingIndicator {
            withAnimation(.easeInOut(duration: 0.2)) {
                isLoading = true
            }
        }
        
        do {
            try await viewModel.loadTasks()
            loadUserProfile()
        } catch {
            print("Error loading tasks: \(error)")
        }
        
        if showLoadingIndicator {
            withAnimation(.easeInOut(duration: 0.2)) {
                isLoading = false
            }
        } else {
            isLoading = false
        }
    }
    
    // 修改 loadUserProfile 方法
    private func loadUserProfile(force: Bool = false) {
        // 檢查是否需要重新載入
        let currentTime = Date()
        let needsReload = force || 
                         lastUserProfileLoadTime == nil || 
                         currentTime.timeIntervalSince(lastUserProfileLoadTime!) > 300 // 5分鐘刷新一次
        
        guard needsReload else {
            return
        }
        

        print("載入使用者資料：\(settingsViewModel.userProfile.motivationalQuote)")
        
        // 強制從資料庫重新載入最新設定
        Task {
            do {
                await settingsViewModel.loadData()
                
                // 在主線程更新 UI
                DispatchQueue.main.async {
                    if !self.settingsViewModel.userProfile.motivationalQuote.isEmpty {
                        self.cachedUserGoal = self.settingsViewModel.userProfile.motivationalQuote
                        print("成功更新鼓勵語句：\(self.cachedUserGoal)")
                    } else {
                        // 如果鼓勵語句為空，則清空 cachedUserGoal，使其顯示倒數天數
                        self.cachedUserGoal = ""
                        print("鼓勵語句為空，將顯示距離目標日期剩餘 \(self.daysRemaining) 天")
                    }
                    
                    // 更新最後載入時間
                    self.lastUserProfileLoadTime = currentTime
                }
            } catch {
                print("載入使用者設定失敗：\(error)")
            }
        }
    }
}

// 新的任務行視圖 - 使用新的样式
struct TodoItemView: View {
    let task: TodoTask
    let isExample: Bool
    let onUpdate: ((TodoTask) -> Void)?
    let onTaskSelected: ((TodoTask) -> Void)?
    @State private var localIsCompleted: Bool
    @State private var showError = false
    @State private var errorMessage = ""
    
    init(task: TodoTask, isExample: Bool, onUpdate: ((TodoTask) -> Void)? = nil, onTaskSelected: ((TodoTask) -> Void)? = nil) {
        self.task = task
        self.isExample = isExample
        self.onUpdate = onUpdate
        self.onTaskSelected = onTaskSelected
        self._localIsCompleted = State(initialValue: task.isCompleted)
    }
    
    var body: some View {
        HStack(spacing: 14) {
            // 左側彩色標識 - 改為自適應高度
            Rectangle()
                .fill(task.color)
                .frame(width: 9)
                .frame(maxHeight: .infinity)
                .cornerRadius(9)
            
            // 中間任務內容區域
            VStack(alignment: .leading, spacing: 5) {
                // 任務標題
                Text(task.title)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(localIsCompleted ? .gray : .black)
                    .strikethrough(localIsCompleted)
                
                // 備註文字
                Text(task.note)
                    .font(.system(size: 15))
                    .foregroundColor(localIsCompleted ? .gray.opacity(0.6) : .black.opacity(0.6))
                    .strikethrough(localIsCompleted)
                    .lineLimit(1)
                
                // 時間顯示
                Text(task.formattedTime)
                    .font(.system(size: 14))
                    .foregroundColor(localIsCompleted ? .gray.opacity(0.7) : .black.opacity(0.7))
            }
            
            Spacer()
            
            // 右側完成按鈕
            if !isExample {
                Button(action: {
                    // 立即更新本地狀態
                    localIsCompleted.toggle()
                    
                    // 觸發更新
                    if let onUpdate = onUpdate {
                        onUpdate(task)
                    }
                }) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.hex(hex: "FEECD8"))
                        .frame(width: 30, height: 30)
                        .overlay(
                            Group {
                                if localIsCompleted {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 22, weight: .black))
                                        .foregroundColor(Color.black.opacity(0.8))
                                }
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.black.opacity(0.7), lineWidth: 2.5)
                        )
                }
            } else {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.hex(hex: "FEECD8"))
                    .frame(width: 30, height: 30)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color.black.opacity(0.7), lineWidth: 2.5)
                    )
            }
        }
        .padding(.vertical, 7)
        .frame(height: 96)
        .padding(.horizontal, 14)
        .background(Color.hex(hex: "FEECD8"))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.09), radius: 10, x: 3, y: 3)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isExample && onTaskSelected != nil {
                onTaskSelected?(task)
            }
        }
        .alert("更新失敗", isPresented: $showError) {
            Button("確定", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
}

// 新的週曆分頁視圖 - 使用TabView實現水平滑動，但背景框固定
struct WeekPagerView: View {
    @Binding var selectedDate: Date
    @State private var pageIndex = 50  // 中間那頁 = 本週
    private let calendar = Calendar.current
    let days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    
    // 預先準備 101 週（-50 ~ +50）
    private var weekStarts: [Date] {
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let thisWeekStart = calendar.date(byAdding: .day, value: -(weekday-1), to: today)!
        return (-50...50).map {
            calendar.date(byAdding: .weekOfYear, value: $0, to: thisWeekStart)!
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            let cellWidth = (geometry.size.width - 24) / 7 // 每個日期單元格的寬度
            
            ZStack(alignment: .center) {
                // 背景框層 - 固定不動
                HStack(alignment: .center, spacing: 4) {
                    ForEach(0..<7) { index in
                        // 使用selectedDate計算當前是否選中
                        let isSelected = calendar.component(.weekday, from: selectedDate) - 1 == index
                        
                        RoundedRectangle(cornerRadius: 16)
                            .fill(isSelected ? Color(red: 0.86, green: 0.55, blue: 0.38, opacity: 0.9) : Color.hex(hex: "FEECD8"))
                            .frame(width: cellWidth, height: 78)
                    }
                }
                .padding(.horizontal, 4)
                
                // 日期內容層 - 可滑動
                TabView(selection: $pageIndex) {
                    ForEach(weekStarts.indices, id: \.self) { idx in
                        WeekContent(
                            weekStart: weekStarts[idx],
                            selectedDate: $selectedDate,
                            days: days,
                            cellWidth: cellWidth
                        )
                        .tag(idx)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .background(Color.hex(hex: "FEECD8"))
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.04), radius: 6, x: 1, y: 1)
        }
        .frame(height: 90)
        // 當分頁變動時，更新選中日期
        .onChange(of: pageIndex) { newIdx in
            // 保持當前選中日期在新週的相同星期幾
            let currentWeekday = calendar.component(.weekday, from: selectedDate) - 1
            if let newDate = calendar.date(byAdding: .day, value: currentWeekday, to: weekStarts[newIdx]) {
                selectedDate = newDate
            }
        }
    }
}

// 只包含週內容（數字部分）的視圖
struct WeekContent: View {
    let weekStart: Date
    @Binding var selectedDate: Date
    let days: [String]
    let cellWidth: CGFloat
    private let calendar = Calendar.current
    
    // 計算該週的所有日期
    private var weekDates: [Date] {
        return (0..<7).map { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset, to: weekStart)!
        }
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            ForEach(0..<7) { index in
                let date = weekDates[index]
                let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                
                VStack(spacing: 5) {
                    Text(days[index]) // 星期幾
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isSelected ? .black : Color.hex(hex: "222222"))
                        .padding(.top, 0)
                    
                    // 日期數字
                    Text("\(calendar.component(.day, from: date))")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)
                }
                .frame(width: cellWidth, height: 78)
                .contentShape(Rectangle()) // 確保整個區域可點擊
                .onTapGesture {
                    selectedDate = date
                }
            }
        }
        .padding(.horizontal, 4)
    }
}

#Preview {
    TodoView()
        .environmentObject(TodoViewModel())
        .environmentObject(UserSettingsViewModel()) // 添加 UserSettingsViewModel
}
