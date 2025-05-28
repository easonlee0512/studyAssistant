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
        return tabBarHeight + 5  // 減去一些偏移以產生好看的重疊效果
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
    
    // 新增：用於追蹤應用程式狀態
    @Environment(\.scenePhase) private var scenePhase
    
    // 新增：重新載入間隔（5分鐘）
    private let reloadInterval: TimeInterval = 300
    
    init() {
        // 從 UserDefaults 加載緩存的標語
        _cachedUserGoal = State(initialValue: "")  // 改為空字串
    }
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack(alignment: .top) {
                // 背景色永遠存在
                backgroundColor
                    .ignoresSafeArea()
                
                    // 主要內容 - 固定頂部，滾動底部
                VStack(spacing: 0) {
                        // 頂部固定區域
                        VStack(spacing: 10) {
                            // 頂部空間 - 確保固定間距
                            Color.clear.frame(height: 8)
                            
                        // 顯示用戶目標或默認倒數天數
                            VStack(alignment: .leading, spacing: 3) {
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
                            
                                // 顯示當前日期與返回今日按鈕
                                HStack {
                            Text(formattedDate)
                                .font(.system(size: 24, weight: .bold))
                                    
                                    Spacer()
                                    
                                    // 返回今日按鈕（只在不是今天時顯示）
                                    if !Calendar.current.isDateInToday(selectedDate) {
                                        Button(action: {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                                selectedDate = Date()
                                            }
                                        }) {
                                            Image(systemName: "arrow.uturn.backward.circle.fill")
                                                .font(.system(size: 24))
                                                .foregroundColor(Color.hex(hex: "E09772"))
                                        }
                                    }
                                }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        
                        // 週曆視圖 - 使用新的WeekPagerView替換舊的WeekViewNew
                        WeekPagerView(selectedDate: $selectedDate)
                            .padding(.horizontal)
                                .padding(.top, 4)
                        
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
                            .padding(.top, 5)
                            .padding(.bottom, 0)
                        }
                        .opacity(isLoading ? 0.3 : 1) // 載入時降低透明度
                        
                        // 使用新的 DayPagerView 實現左右滑動
                        DayPagerView(
                            selectedDate: $selectedDate,
                            viewModel: viewModel,
                            onTaskSelected: { task in
                                taskToEdit = task
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        showingEditTask = true
                                    }
                            },
                            onError: { error in
                                showError = true
                                errorMessage = error.localizedDescription
                            },
                            isLoading: isLoading
                        )
                        .opacity(isLoading ? 0.3 : 1) // 載入時降低透明度
                    }
                    
                    // 載入指示器 - 放在 TodoList 下方
                    if viewModel.isLoading {
                        ProgressView()
                            .scaleEffect(1.5)
                            .progressViewStyle(CircularProgressViewStyle(tint: Color.gray.opacity(0.8)))
                            .position(x: geometry.size.width / 2, y: geometry.size.height / 2.15)  // 微調往下
                    }
                }
                
                // 添加任務視圖
                if showingAddTask {
                    ZStack {
                        // 遮罩層
                        Color.black.opacity(0.3)
                            .ignoresSafeArea(edges: .all)
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
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .edgesIgnoringSafeArea(.all)
                    .zIndex(2)
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
                        .zIndex(2)
                    }
                }
                
                // 編輯任務視圖
                Group {
                    if showingEditTask && taskToEdit != nil {
                        ZStack {
                            // 遮罩層
                            Color.black.opacity(0.3)
                                .ignoresSafeArea(edges: .all)
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
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .edgesIgnoringSafeArea(.all)
                        .zIndex(2)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
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
                // 首次初始化時載入資料
                Task {
                    await loadTasks(showLoadingIndicator: true)
                }
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
            
            // 監聽任務數據變化
            NotificationCenter.default.addObserver(
                forName: .todoDataDidChange,
                object: nil,
                queue: .main
            ) { _ in
                Task {
                    await loadTasks(showLoadingIndicator: false)
                }
            }
            
            // 檢查是否需要重新載入
            let currentTime = Date()
            let needsReload = lastLoadTime == nil || 
                            currentTime.timeIntervalSince(lastLoadTime!) > reloadInterval
            
            if needsReload {
                await loadTasks(showLoadingIndicator: lastLoadTime == nil)
            }
        }
        .onChange(of: selectedDate) { newDate in
            // 當選擇的日期改變時，重新載入任務
            Task {
                await loadTasks(showLoadingIndicator: false)
            }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                // 從背景回到前景時重新載入
                Task {
                    await loadTasks(showLoadingIndicator: false)
                }
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
        // 新增：下拉刷新功能
        .refreshable {
            await loadTasks(showLoadingIndicator: true)
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
    
    private func loadTasks(showLoadingIndicator: Bool = true) async {
        if showLoadingIndicator {
            withAnimation(.easeInOut(duration: 0.2)) {
                isLoading = true
            }
        }
        
        do {
            try await viewModel.loadTasks()
            loadUserProfile()
            lastLoadTime = Date()
        } catch {
            print("Error loading tasks: \(error)")
            errorMessage = "載入任務失敗：\(error.localizedDescription)"
            showError = true
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
    let instance: TaskInstance?  // 新增：任務實例
    @State private var localIsCompleted: Bool
    @State private var showError = false
    @State private var errorMessage = ""
    
    init(task: TodoTask, isExample: Bool, instance: TaskInstance? = nil, onUpdate: ((TodoTask) -> Void)? = nil, onTaskSelected: ((TodoTask) -> Void)? = nil) {
        self.task = task
        self.isExample = isExample
        self.onUpdate = onUpdate
        self.onTaskSelected = onTaskSelected
        self.instance = instance
        // 如果有實例，使用實例的完成狀態，否則使用任務的完成狀態
        self._localIsCompleted = State(initialValue: instance?.isCompleted ?? task.isCompleted)
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
                
                // 備註文字 - 修改為不要劃掉
                Text(task.note)
                    .font(.system(size: 15))
                    .foregroundColor(localIsCompleted ? .gray.opacity(0.6) : .black.opacity(0.6))
                    .strikethrough(false) // 不管是否完成都不劃掉備註
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
        .shadow(color: .black.opacity(0.03), radius: 6, x: 0, y: 2)
        .padding(.horizontal, 3) // 添加水平間距，確保陰影不被裁剪
        .padding(.vertical, 2) // 添加垂直間距，確保陰影不被裁剪
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
    
    // 獲取一個日期所在週的索引
    private func getWeekIndex(for date: Date) -> Int? {
        let startOfDay = calendar.startOfDay(for: date)
        
        for (index, weekStart) in weekStarts.enumerated() {
            // 計算週的結束日期（週六）
            let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart)!
            
            // 檢查日期是否在這一週內
            if (startOfDay >= calendar.startOfDay(for: weekStart) && 
                startOfDay <= calendar.startOfDay(for: weekEnd)) {
                return index
            }
        }
        return nil
    }
    
    var body: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width
            let cellWidth = (availableWidth - 32) / 7 // 每個日期單元格的寬度，考慮間距
            
            ZStack(alignment: .center) {
                // 背景框層 - 固定不動
                HStack(spacing: 4) {
                    ForEach(0..<7) { index in
                        // 使用selectedDate計算當前是否選中
                        let isSelected = calendar.component(.weekday, from: selectedDate) - 1 == index
                        
                        RoundedRectangle(cornerRadius: 16)
                            .fill(isSelected ? Color(red: 0.86, green: 0.55, blue: 0.38, opacity: 0.9) : Color.hex(hex: "FEECD8"))
                            .frame(width: cellWidth, height: 78)
                    }
                }
                .padding(.horizontal, 16) // 確保左右有足夠間距
                
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
                .padding(.horizontal, 16) // 確保與背景框對齊
            }
            .frame(width: availableWidth, height: 90) // 確保整個 ZStack 居中
            .background(Color.hex(hex: "FEECD8"))
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.02), radius: 4, x: 0, y: 1)
        }
        .frame(height: 90)
        // 當分頁變動時，更新選中日期
        .onChange(of: pageIndex) { newIdx in
            // 保持當前選中日期在新週的相同星期幾
            let oldDate = selectedDate
            let currentWeekday = calendar.component(.weekday, from: selectedDate) - 1
            if let newDate = calendar.date(byAdding: .day, value: currentWeekday, to: weekStarts[newIdx]) {
                selectedDate = newDate
                
                // 只有在日期真正改變時才觸發震動
                if !calendar.isDate(oldDate, inSameDayAs: selectedDate) {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                }
            }
        }
        // 當選擇的日期改變時，更新頁面索引
        .onChange(of: selectedDate) { newDate in
            if let newIndex = getWeekIndex(for: newDate) {
                if newIndex != pageIndex {
                    withAnimation {
                        pageIndex = newIndex
                    }
                }
            }
        }
        .onAppear {
            // 初始載入時確保頁面索引與選擇的日期匹配
            if let initialIndex = getWeekIndex(for: selectedDate) {
                pageIndex = initialIndex
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
        HStack(spacing: 4) {
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
                    // 觸發震動反饋
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    
                    selectedDate = date
                }
            }
        }
    }
}

// 日期分頁視圖 - 實現左右滑動切換日期
struct DayPagerView: View {
    @Binding var selectedDate: Date
    @ObservedObject var viewModel: TodoViewModel
    let onTaskSelected: (TodoTask) -> Void
    let onError: (Error) -> Void
    let isLoading: Bool
    
    @State private var pageIndex = 3  // 中間那頁 = 今天 (索引從 0 開始，所以是 3)
    @State private var dayDates: [Date] = []
    private let calendar = Calendar.current
    
    // 初始化時生成日期
    init(selectedDate: Binding<Date>, viewModel: TodoViewModel, onTaskSelected: @escaping (TodoTask) -> Void, onError: @escaping (Error) -> Void, isLoading: Bool) {
        self._selectedDate = selectedDate
        self.viewModel = viewModel
        self.onTaskSelected = onTaskSelected
        self.onError = onError
        self.isLoading = isLoading
        
        // 初始化日期範圍
        let today = Calendar.current.startOfDay(for: Date())
        let initialDates = (-3...3).map {
            Calendar.current.date(byAdding: .day, value: $0, to: today)!
        }
        _dayDates = State(initialValue: initialDates)
    }
    
    // 獲取一個日期所在的索引
    private func getDayIndex(for date: Date) -> Int? {
        let startOfDay = calendar.startOfDay(for: date)
        
        for (index, dayDate) in dayDates.enumerated() {
            if calendar.isDate(startOfDay, inSameDayAs: dayDate) {
                return index
            }
        }
        return nil
    }
    
    // 重新生成日期範圍，將當前選中日期置於中間
    private func regenerateDates() {
        let centerDate = calendar.startOfDay(for: selectedDate)
        dayDates = (-3...3).map {
            calendar.date(byAdding: .day, value: $0, to: centerDate)!
        }
        pageIndex = 3  // 重置為中間索引
    }
    
    var body: some View {
        TabView(selection: $pageIndex) {
            ForEach(Array(dayDates.indices), id: \.self) { idx in
                ZStack {
                    if !isLoading {
                        DayContent(
                            date: dayDates[idx],
                            viewModel: viewModel,
                            onTaskSelected: onTaskSelected,
                            onError: onError,
                            isLoading: isLoading
                        )
                    } else {
                        Color.clear // 載入時不顯示內容
                    }
                }
                .tag(idx)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .onChange(of: pageIndex) { newIdx in
            // 當頁面索引變化時，更新選中的日期
            let oldDate = selectedDate
            selectedDate = dayDates[newIdx]
            
            // 只有在日期真正改變時才觸發震動
            if !Calendar.current.isDate(oldDate, inSameDayAs: selectedDate) {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
            }
            
            // 檢查是否需要重新生成日期範圍
            if newIdx <= 1 || newIdx >= dayDates.count - 2 {
                // 等待動畫完成後重新生成
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    regenerateDates()
                }
            }
        }
        .onChange(of: selectedDate) { newDate in
            // 當選擇的日期變化時，檢查是否在當前範圍內
            if let newIndex = getDayIndex(for: newDate) {
                if newIndex != pageIndex {
                    withAnimation {
                        pageIndex = newIndex
                    }
                }
            } else {
                // 如果不在範圍內，重新生成日期範圍
                regenerateDates()
            }
        }
        .onAppear {
            // 初始載入時確保頁面索引與選擇的日期匹配
            if let initialIndex = getDayIndex(for: selectedDate) {
                pageIndex = initialIndex
            } else {
                // 如果選中的日期不在範圍內，重新生成日期範圍
                regenerateDates()
            }
        }
    }
}

// 單日內容視圖
struct DayContent: View {
    let date: Date
    @ObservedObject var viewModel: TodoViewModel
    let onTaskSelected: (TodoTask) -> Void
    let onError: (Error) -> Void
    let isLoading: Bool
    
    var body: some View {
        ScrollView {
            if !isLoading {
                LazyVStack() {
                    ForEach(viewModel.sortedTasksWithCompletionStatus(by: date)) { task in
                        // 獲取該任務在當前日期的實例
                        let instances = viewModel.getInstancesForDate(date, task: task)
                        
                        if !instances.isEmpty {
                            // 如果有實例，顯示每個實例
                            ForEach(instances) { instance in
                                TodoItemView(
                                    task: task,
                                    isExample: false,
                                    instance: instance,  // 傳遞實例
                                    onUpdate: { _ in
                                        Task {
                                            do {
                                                // 切換任務實例的完成狀態
                                                try await viewModel.toggleInstanceCompletion(instance, in: task)
                                            } catch {
                                                onError(error)
                                            }
                                        }
                                    },
                                    onTaskSelected: onTaskSelected
                                )
                            }
                        } else {
                            // 如果沒有實例，表示這是非重複性任務
                            TodoItemView(
                                task: task,
                                isExample: false,
                                onUpdate: { _ in
                                    Task {
                                        // 直接切換任務的完成狀態
                                        await viewModel.toggleTaskCompletion(task)
                                    }
                                },
                                onTaskSelected: onTaskSelected
                            )
                        }
                    }
                    
                    if viewModel.sortedTasksWithCompletionStatus(by: date).isEmpty {
                        Text("目前沒有任務")
                            .foregroundColor(.gray)
                            .padding()
                    }
                    
                    // 底部空間 - 確保有足夠的滾動空間
                    Color.clear.frame(height: 20)
                }
                .padding(.horizontal)
                .padding(.top, 10)
            }
        }
    }
}

#Preview {
    TodoView()
        .environmentObject(TodoViewModel())
        .environmentObject(UserSettingsViewModel()) // 添加 UserSettingsViewModel
}
