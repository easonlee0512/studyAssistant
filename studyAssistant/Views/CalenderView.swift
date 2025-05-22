import SwiftUI
import SwiftUICore
// 添加 Date 擴展的引用

// 添加全域常數
private let maxTaskRows = 4 // 每個日期格子最多顯示的任務行數

// 避免重複宣告，僅保留isSameDay方法
extension Date {
    func isSameDay(as other: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: other)
    }
}

// MARK: - 行事曆排版邏輯

// 事件排列位置管理器
class EventPlacementManager {
    // 存儲每個事件的排列位置
    private var eventPositions: [String: Int] = [:]
    
    // 獲取事件的排列位置
    func getPosition(for taskId: String) -> Int {
        return eventPositions[taskId] ?? 0
    }
    
    // 設置事件的排列位置
    func setPosition(for taskId: String, position: Int) {
        eventPositions[taskId] = position
    }
    
    // 清除所有事件位置
    func clearPositions() {
        eventPositions.removeAll()
    }
}

// 擴展 TodoTask，添加事件類型判斷和排版邏輯
extension TodoTask {
    // 判斷是否為全天事件或長於24小時的事件
    var isAllDayOrMultiDay: Bool {
        // 如果已標記為全天事件
        if isAllDay {
            return true
        }
        
        // 計算事件持續時間（小時）
        let duration = Calendar.current.dateComponents([.hour], from: startDate, to: endDate).hour ?? 0
        
        // 如果持續時間 >= 24小時，視為全天事件
        return duration >= 24
    }
    
    // 判斷是否為跨午夜但小於24小時的事件
    var isOvernightEvent: Bool {
        // 如果是全天事件，則不是跨午夜事件
        if isAllDayOrMultiDay {
            return false
        }
        
        // 獲取開始日期的日期部分
        let startDay = Calendar.current.startOfDay(for: startDate)
        // 獲取結束日期的日期部分
        let endDay = Calendar.current.startOfDay(for: endDate)
        
        // 如果開始和結束不是同一天，但持續時間小於24小時，則是跨午夜事件
        return startDay != endDay
    }
    
    // 獲取事件持續時間（分鐘）
    var durationInMinutes: Int {
        return Calendar.current.dateComponents([.minute], from: startDate, to: endDate).minute ?? 0
    }
}

// 定義靜態的事件位置管理器
let eventPlacementManager = EventPlacementManager()

// MARK: - 日曆主視圖
struct CalendarView: View {
    // MARK: 狀態變量
    @EnvironmentObject var viewModel: TodoViewModel
    @EnvironmentObject var staticViewModel: StaticViewModel
    @State private var selectedDate = Date()  // 當前選中的日期
    @State private var currentDate = Date()   // 顯示的當前月份
    @State private var showingAddTask = false // 控制添加任務視圖顯示
    @State private var showingTodoDetail = false // 控制待辦詳情視圖顯示
    @State private var offsetX: CGFloat = 0   // 統一位移控制
    @State private var isDragging = false
    @State private var selectedDateId: String? = nil  // 用於追踪選中的日期
    
    // 背景和底部导航颜色
    let backgroundColor = Color.hex(hex: "F3D4B8")
    let bottomBarColor = Color.hex(hex: "FEECD8")
    
    // TabBar的高度 - 根據 TabBarNew 計算：圖標(40) + 頂部間距(25) + 底部間距(10) + 垂直內邊距(8) + 安全區域(20)
    private let tabBarHeight: CGFloat = 83
    
    // 取得顯示 TodoAddView 的位置 - 確保它被放置在 TabBar 的上方
    private var todoAddViewPosition: CGFloat {
        // 使用 tabBarHeight 來設置視圖的位置，讓它顯示在 TabBar 上方
        // 注意：這裡故意使用比 TodoView 小的偏移值，以讓日曆視圖中的 TodoAddView 顯示得更低一些
        return tabBarHeight + 5// 減少偏移量，使視圖更接近 TabBar
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // 標題列
                HStack {
                    Spacer(minLength: 45)

                    Text(monthYearString)
                        .font(.system(size: 24, weight: .medium))
                        .kerning(0.5)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .animation(nil, value: currentDate)

                    Button(action: {
                        showingAddTask = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Color.hex(hex: "E28A5F"))
                    }
                    .padding(.trailing, 15)
                    .frame(width: 45)
                }
                .padding(.top, 110)
                .padding(.bottom, 35)
                .frame(height: 80)
                .background(backgroundColor)

                // 使用新的 MonthPagerView
                MonthPagerView(
                    currentDate: $currentDate,
                    viewModel: viewModel,
                    selectedDate: $selectedDate,
                    showingTodoDetail: $showingTodoDetail
                )
                .frame(maxHeight: .infinity)
                .padding(.top, 20)
                .padding(.horizontal, 1)
            }
            .background(backgroundColor)
            .ignoresSafeArea()
            .padding(.top, -7)
            
            // 使用 ZStack 覆蓋方式顯示新增任務視圖
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
                    
                    // 新增任務視圖 - 傳遞 TabBar 高度
                    TodoAddView(
                        viewModel: viewModel, 
                        isPresented: $showingAddTask, 
                        selectedDate: selectedDate,
                        tabBarHeight: todoAddViewPosition
                    )
                        .environmentObject(staticViewModel)
                        .transition(.move(edge: .bottom))
                }
                .gesture(
                    DragGesture()
                        .onChanged { _ in
                            // 當開始滑動時就關閉鍵盤
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                         to: nil, from: nil, for: nil)
                        }
                )
                .zIndex(1)
                .ignoresSafeArea(.keyboard) // 忽略鍵盤
                .edgesIgnoringSafeArea(.bottom)
            }
            
            // 使用ZStack覆蓋方式顯示詳情視圖
            if showingTodoDetail {
                ZStack {
                    // 添加半透明背景，點擊時關閉詳情視圖
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showingTodoDetail = false
                            }
                        }
                    
                    TodoDetailView(
                        viewModel: viewModel,
                        date: selectedDate,
                        isPresented: $showingTodoDetail
                    )
                    .padding(.top, 100) // 向下移動詳情視圖
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: showingTodoDetail)
            }
        }
        .background(backgroundColor)
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.3), value: showingAddTask)
        .animation(.easeInOut(duration: 0.3), value: showingTodoDetail)
        .task {
            // 首次加載資料
            await loadTasks()
            
            // 添加通知觀察者，當資料變更時重新載入
            NotificationCenter.default.addObserver(
                forName: .todoDataDidChange,
                object: nil,
                queue: .main
            ) { _ in
                Task {
                    await loadTasks()
                }
            }
        }
        .onDisappear {
            // 移除通知觀察者
            NotificationCenter.default.removeObserver(self, name: .todoDataDidChange, object: nil)
        }
    }
    
    // 載入任務
    private func loadTasks() async {
        do {
            try await viewModel.loadTasks()
        } catch {
            print("Error loading tasks in CalendarView: \(error)")
        }
    }
    
    // MARK: 輔助函數
    private func selectDate(_ row: Int, _ column: Int) {
        if let date = getDateFromRowColumn(row: row, column: column) {
            selectedDate = date
            showingTodoDetail = true  // 顯示詳情視圖而不是添加任務視圖
        }
    }
    
    private func getDateFromRowColumn(row: Int, column: Int) -> Date? {
        let dayValue = Int(calendarData(for: currentDate)[row][column]) ?? 1
        let calendar = Calendar.current
        
        // 确定该日期是哪个月
        var dateComponents = calendar.dateComponents([.year, .month], from: currentDate)
        
        // 如果是上个月的日期
        if row == 0 && column < firstWeekdayOfMonth {
            if let prevMonth = calendar.date(byAdding: .month, value: -1, to: currentDate) {
                dateComponents = calendar.dateComponents([.year, .month], from: prevMonth)
            }
        }
        // 如果是下个月的日期
        else if dayValue <= 14 && row >= 4 {
            if let nextMonth = calendar.date(byAdding: .month, value: 1, to: currentDate) {
                dateComponents = calendar.dateComponents([.year, .month], from: nextMonth)
            }
        }
        
        dateComponents.day = dayValue
        return calendar.date(from: dateComponents)
    }
    
    private func isCurrentMonth(_ row: Int, _ column: Int) -> Bool {
        if row == 0 && column < firstWeekdayOfMonth {
            return false
        }
        let dayNumber = Int(calendarData(for: currentDate)[row][column]) ?? 0
        if row >= 4 && dayNumber < 15 {
            return false
        }
        return true
    }
    
    // MARK: 計算屬性
    /// 取得當月的第一天是星期幾 (0-6, 0 = 星期日)
    var firstWeekdayOfMonth: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: currentDate)
        let firstDayOfMonth = calendar.date(from: components)!
        return calendar.component(.weekday, from: firstDayOfMonth) - 1
    }
    
    /// 取得當月的天數
    var daysInMonth: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: currentDate)
        let firstDayOfMonth = calendar.date(from: components)!
        let range = calendar.range(of: .day, in: .month, for: firstDayOfMonth)!
        return range.count
    }
    
    /// 取得上個月的天數
    var daysInPrevMonth: Int {
        let calendar = Calendar.current
        if let prevMonth = calendar.date(byAdding: .month, value: -1, to: currentDate) {
            let range = calendar.range(of: .day, in: .month, for: prevMonth)!
            return range.count
        }
        return 31
    }
    
    /// 新增一個 calendarData(for:) 產生指定月份的 calendarData
    func calendarData(for date: Date) -> [[String]] {
        var result: [[String]] = Array(repeating: Array(repeating: "", count: 7), count: 6)
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)
        let firstDayOfMonth = calendar.date(from: components)!
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth) - 1
        let range = calendar.range(of: .day, in: .month, for: firstDayOfMonth)!
        let daysInMonth = range.count
        // 上個月天數
        let prevMonth = calendar.date(byAdding: .month, value: -1, to: date)!
        let prevRange = calendar.range(of: .day, in: .month, for: prevMonth)!
        let daysInPrevMonth = prevRange.count
        // 填充上個月的日期
        for i in 0..<firstWeekday {
            result[0][i] = "\(daysInPrevMonth - firstWeekday + i + 1)"
        }
        // 填充當月的日期
        var day = 1
        var row = 0
        var col = firstWeekday
        while day <= daysInMonth {
            result[row][col] = "\(day)"
            day += 1
            col += 1
            if col == 7 {
                col = 0
                row += 1
            }
        }
        // 填充下個月的日期
        var nextMonthDay = 1
        while row < 6 {
            while col < 7 {
                result[row][col] = "\(nextMonthDay)"
                nextMonthDay += 1
                col += 1
            }
            col = 0
            row += 1
        }
        return result
    }
    
    /// 格式化年月標題
    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy MMM"
        return formatter.string(from: currentDate)
    }
}

// MARK: - 預覽
#Preview {
    CalendarView()
        .environmentObject(TodoViewModel())
        .environmentObject(StaticViewModel())
}

// 修改 CalendarMonthWithWeekdaysView 讓高度自動填滿
struct CalendarMonthWithWeekdaysView: View {
    let calendarData: [[String]]
    let monthDate: Date
    let geometry: GeometryProxy
    let selectDate: (Int, Int) -> Void
    let viewModel: TodoViewModel
    let isDragging: Bool
    let weekDays = ["日", "一", "二", "三", "四", "五", "六"]
    var body: some View {
        VStack(spacing: 0) {
            // 星期標題
            HStack(spacing: 0) {
                ForEach(weekDays, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 13))
                        .frame(width: geometry.size.width / 7)
                        .padding(.bottom, 5)
                }
            }
            .frame(height: 25)
            // 日期格子
            CalendarMonthView(
                calendarData: calendarData,
                monthDate: monthDate,
                geometry: geometry,
                selectDate: selectDate,
                viewModel: viewModel,
                isDragging: isDragging
            )
            .frame(maxHeight: .infinity)
        }
        .frame(height: geometry.size.height)
    }
}

// 新增日期單元格視圖
struct DateCellView: View {
    let dateText: String
    let isToday: Bool
    let isCurrentMonth: Bool
    
    var body: some View {
        ZStack {
            if isToday {
                Circle()
                    .fill(Color.hex(hex: "E28A5F"))
                    .frame(width: 22, height: 22)
            }
            
            Text(dateText)
                .font(.system(size: 13, weight: isToday ? .medium : .regular))
                .foregroundColor(isToday ? .white : (isCurrentMonth ? .black : .gray.opacity(0.6)))
        }
    }
}

// 新增單個任務條視圖
struct SingleTaskBarView: View {
    let task: TodoTask
    let cellDate: Date
    let width: CGFloat
    let rowIdx: Int 
    
    private func isFirstDayOfWeek(_ date: Date) -> Bool {
        return Calendar.current.component(.weekday, from: date) == 1  // 週日
    }
    
    private func isLastDayOfWeek(_ date: Date) -> Bool {
        return Calendar.current.component(.weekday, from: date) == 7  // 週六
    }
    
    private func calculateTaskPosition() -> (isStart: Bool, isEnd: Bool, isWeekStart: Bool, isWeekEnd: Bool) {
        let isFirstDay = utcCalendar.isDate(cellDate, inSameDayAs: task.startDate)
        let isLastDay = utcCalendar.isDate(cellDate, inSameDayAs: task.endDate)
        let isWeekStart = isFirstDayOfWeek(cellDate)
        let isWeekEnd = isLastDayOfWeek(cellDate)
        
        return (isFirstDay, isLastDay, isWeekStart, isWeekEnd)
    }
    
    private func shouldShowText() -> Bool {
        let calendar = Calendar.current
        
        // 如果是單日任務，顯示文字
        if utcCalendar.isDate(task.startDate, inSameDayAs: task.endDate) {
            return utcCalendar.isDate(cellDate, inSameDayAs: task.startDate)
        }
        
        // 獲取當前日期所在的週的起始和結束
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: cellDate))!
        let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek)!
        
        // 計算任務在本週的實際起始和結束日
        let taskStartInWeek = max(task.startDate, startOfWeek)
        let taskEndInWeek = min(task.endDate, endOfWeek)
        
        // 如果任務不在這週，返回 false
        if taskStartInWeek > endOfWeek || taskEndInWeek < startOfWeek {
            return false
        }
        
        // 計算本週任務的中間日期
        let daysBetween = calendar.dateComponents([.day], from: taskStartInWeek, to: taskEndInWeek).day ?? 0
        let middleOffset = daysBetween / 2
        let middleDate = calendar.date(byAdding: .day, value: middleOffset, to: taskStartInWeek)!
        
        // 如果當前日期是本週任務的中間日期，顯示文字
        return calendar.isDate(cellDate, inSameDayAs: middleDate)
    }
    
    var body: some View {
        let position = calculateTaskPosition()
        let showText = shouldShowText()
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: cellDate) // 1=週日, 7=週六
        let forceLeftRadius = (weekday == 1)  // 週日
        let forceRightRadius = (weekday == 7) // 週六
        
        return TaskBarView(
            color: task.color,
            showLeftRadius: position.isStart || forceLeftRadius,
            showRightRadius: position.isEnd || forceRightRadius,
            isSingle: (position.isStart && position.isEnd) || (forceLeftRadius && forceRightRadius),
            width: width
        ) {
            Group {
                if showText {
                    Text(task.title)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                } else {
                    EmptyView()
                }
            }
        }
        .frame(maxWidth: width)
        .offset(y: CGFloat(rowIdx) * 18)
        .transition(.opacity.combined(with: .scale))
    }
}

// 修改日期格子視圖
struct DayCellView: View {
    let row: Int
    let column: Int
    let dateText: String
    let cellDate: Date?
    let tasksForThisDay: [TodoTask?] // 接收 Optional 陣列
    let allTasksForThisDay: [TodoTask] // 新增：該天所有該顯示的任務
    let isToday: Bool
    let isCurrentMonth: Bool
    let geometry: GeometryProxy
    let cellHeight: CGFloat
    let dateLabelHeight: CGFloat
    let onTap: () -> Void
    
    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                DateCellView(dateText: dateText, isToday: isToday, isCurrentMonth: isCurrentMonth)
                    .frame(height: dateLabelHeight)
                    .padding(.top, 2)
                Spacer().frame(height: 4)
                if let date = cellDate {
                    TaskListView(tasksForThisDay: tasksForThisDay, cellDate: date, geometry: geometry)
                }
                Spacer() // 讓任務條往上貼齊
            }
            // +幾永遠在最底
            if allTasksForThisDay.count > maxTaskRows {
                Text("+\(allTasksForThisDay.count - maxTaskRows)")
                    .font(.system(size: 7))
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 2)
            }
        }
        .frame(width: geometry.size.width / 7, height: cellHeight)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

struct CalendarMonthView: View {
    let calendarData: [[String]]
    let monthDate: Date
    let geometry: GeometryProxy
    let selectDate: (Int, Int) -> Void
    @ObservedObject var viewModel: TodoViewModel
    let isDragging: Bool
    @State private var selectedDateId: String? = nil
    private let calendar = Calendar.current
    private let maxRows = 4 // 最大顯示行數
    
    var body: some View {
        let cellHeight = (geometry.size.height - 25) / 6
        
        // 預先計算所有所需數據
        let tasksData = prepareTasksData()
        
        VStack(spacing: 0) {
            ForEach(0..<6) { rowIndex in
                HStack(spacing: 0) {
                    ForEach(0..<7) { columnIndex in
                        let dateText = calendarData[rowIndex][columnIndex]
                        let cellDate = getCellDate(row: rowIndex, column: columnIndex)
                        
                        // 獲取該天所有該顯示的任務
                        let allTasksForThisDay: [TodoTask] = getTasksForDate(cellDate)
                        
                        // 從分配結果中獲取當天的任務列表
                        let tasksToShowInCell: [TodoTask?] = cellDate.map { date in
                            (0..<maxRows).map { tasksData.rowAssignments[date]?[$0] }
                        } ?? Array(repeating: nil, count: maxRows)
                        
                        let isToday = cellDate.map { calendar.isDateInToday($0) } ?? false
                        let isCurrentCellMonth = cellDate.map { calendar.isDate($0, equalTo: monthDate, toGranularity: .month) } ?? false
                        
                        DayCellView(
                            row: rowIndex,
                            column: columnIndex,
                            dateText: dateText,
                            cellDate: cellDate,
                            tasksForThisDay: tasksToShowInCell,
                            allTasksForThisDay: allTasksForThisDay,
                            isToday: isToday,
                            isCurrentMonth: isCurrentCellMonth,
                            geometry: geometry,
                            cellHeight: cellHeight,
                            dateLabelHeight: 20,
                            onTap: {
                                selectedDateId = "\(rowIndex)-\(columnIndex)"
                                if let date = cellDate {
                                    selectDate(rowIndex, columnIndex)
                                }
                            }
                        )
                    }
                }
            }
        }
        .frame(width: geometry.size.width, height: geometry.size.height - 25)
        .drawingGroup()
        .animation(nil, value: isDragging)
        .onAppear {
            eventPlacementManager.clearPositions()
        }
    }
    
    // 輔助函數：準備所有任務數據
    private func prepareTasksData() -> (allTasks: [TodoTask], rowAssignments: [Date: [Int: TodoTask]]) {
        // 獲取當月的日期範圍
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: monthDate))!
        let nextMonthStart = calendar.date(byAdding: .month, value: 1, to: monthStart)!
        let daysInMonth = calendar.dateComponents([.day], from: monthStart, to: nextMonthStart).day!
        
        // 收集所有任務（包括重複任務的實例）
        var allTasksForMonth: [TodoTask] = []
        // 使用 Set 追踪已添加的多日任務 ID，避免重複添加
        var addedMultiDayTaskIds = Set<String>()
        
        // 為當月每一天收集任務
        for day in 0..<daysInMonth {
            if let date = calendar.date(byAdding: .day, value: day, to: monthStart) {
                let tasksForDate = getTasksForDate(date)
                
                for task in tasksForDate {
                    // 對於跨多天的任務，使用 ID 去重
                    if !task.startDate.isSameDay(as: task.endDate) {
                        if !addedMultiDayTaskIds.contains(task.id) {
                            allTasksForMonth.append(task)
                            addedMultiDayTaskIds.insert(task.id)
                        }
                    } else {
                        // 對於單日任務或重複任務的實例，直接添加
                        // 因為它們只會在特定日期顯示一次
                        allTasksForMonth.append(task)
                    }
                }
            }
        }
        
        // 分配任務行
        let rowAssignments = assignRowsForMonth(allTasks: allTasksForMonth)
        
        return (allTasksForMonth, rowAssignments)
    }
    
    // 輔助函數：獲取指定日期的所有任務
    private func getTasksForDate(_ date: Date?) -> [TodoTask] {
        guard let date = date else { return [] }
        
        let tasksForDate = viewModel.tasksForDate(date)
        var tasksToShow: [TodoTask] = []
        
        for task in tasksForDate {
            if task.repeatType == .none {
                tasksToShow.append(task)
            } else {
                // 獲取當前日期的實例
                let instances = viewModel.getInstancesForDate(date, task: task)
                
                // 即使沒有當前日期的實例，也檢查是否有已完成的實例
                var foundInstance = false
                
                // 檢查所有實例，查找匹配當前日期的實例
                for instance in task.instances {
                    if Calendar.current.isDate(instance.date, inSameDayAs: date) {
                        var instanceTask = task
                        instanceTask.startDate = instance.date
                        instanceTask.endDate = instance.date
                        instanceTask.isCompleted = instance.isCompleted
                        tasksToShow.append(instanceTask)
                        foundInstance = true
                        break
                    }
                }
                
                // 如果沒有找到實例但根據當前的重複模式應該顯示
                if !foundInstance && !instances.isEmpty {
                    let instance = instances.first!
                    var instanceTask = task
                    instanceTask.startDate = instance.date
                    instanceTask.endDate = instance.date
                    instanceTask.isCompleted = instance.isCompleted
                    tasksToShow.append(instanceTask)
                }
            }
        }
        
        return tasksToShow
    }
    
    // 計算這格的 Date，根據 monthDate
    func getCellDate(row: Int, column: Int) -> Date? {
        let dateText = calendarData[row][column]
        guard let day = Int(dateText) else { return nil }
        let calendar = Calendar.current
        var dateComponents = calendar.dateComponents([.year, .month], from: monthDate)
        dateComponents.day = day
        // 判斷這格是本月、上月還是下月
        if row == 0 && day > 7 { // 上個月
            return calendar.date(byAdding: .month, value: -1, to: calendar.date(from: dateComponents)!)
        } else if row >= 4 && day < 15 { // 下個月
            return calendar.date(byAdding: .month, value: 1, to: calendar.date(from: dateComponents)!)
        }
        // 本月
        return calendar.date(from: dateComponents)
    }
    
    // 將任務分配邏輯移至此處
    func assignRowsForMonth(allTasks: [TodoTask]) -> [Date: [Int: TodoTask]] {
        var rowUsage: [Date: [Int: TodoTask]] = [:]
        var taskRowAssignment: [String: Int] = [:]
        let calendar = Calendar.current

        // 1. 先分配跨天任務
        let multiDayTasks = allTasks
            .filter { !$0.startDate.isSameDay(as: $0.endDate) }
            .sorted { $0.startDate < $1.startDate }

        for task in multiDayTasks {
            let start = calendar.startOfDay(for: task.startDate)
            let end = calendar.startOfDay(for: task.endDate)
            let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0
            let datesSpanned = (0...days).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }

            // 找一個 row，這個 row 在所有日期都沒被佔用
            var assignedRow: Int? = nil
            rowLoop: for row in 0..<maxRows {
                for date in datesSpanned {
                    if rowUsage[date]?[row] != nil {
                        continue rowLoop
                    }
                }
                assignedRow = row
                break
            }
            if let row = assignedRow {
                taskRowAssignment[task.id] = row
                for date in datesSpanned {
                    if rowUsage[date] == nil { rowUsage[date] = [:] }
                    rowUsage[date]![row] = task
                }
            }
        }

        // 2. 再分配單日任務
        let singleDayTasks = allTasks
            .filter { $0.startDate.isSameDay(as: $0.endDate) }
            .sorted { t1, t2 in
                if t1.startDate == t2.startDate {
                    return t1.durationInMinutes > t2.durationInMinutes
                }
                return t1.startDate < t2.startDate
            }

        for task in singleDayTasks {
            let date = calendar.startOfDay(for: task.startDate)
            for row in 0..<maxRows {
                if rowUsage[date]?[row] == nil {
                    if rowUsage[date] == nil { rowUsage[date] = [:] }
                    rowUsage[date]![row] = task
                    break
                }
            }
        }

        return rowUsage
    }
}

// 自訂 modifier 控制橫條圓角，支援左右圓角
struct TaskBarCornerModifier: ViewModifier {
    let showLeftRadius: Bool
    let showRightRadius: Bool
    let isSingle: Bool
    let radius: CGFloat
    
    func body(content: Content) -> some View {
        if isSingle {
            // 單日任務顯示所有圓角
            content.clipShape(RoundedRectangle(cornerRadius: radius))
        } else if showLeftRadius && !showRightRadius {
            // 起始日只有左側圓角
            content.clipShape(
                .rect(
                    topLeadingRadius: radius,
                    bottomLeadingRadius: radius,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 0
                )
            )
        } else if !showLeftRadius && showRightRadius {
            // 結束日只有右側圓角
            content.clipShape(
                .rect(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: radius,
                    topTrailingRadius: radius
                )
            )
        } else {
            // 中間日期完全不顯示圓角
            content.clipShape(Rectangle())
        }
    }
}

// 修改 TaskBarView，確保任務條不重疊且正確連接
struct TaskBarView<Content: View>: View {
    let color: Color
    let showLeftRadius: Bool
    let showRightRadius: Bool
    let isSingle: Bool
    let width: CGFloat
    let content: () -> Content
    
    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(color)
                .modifier(TaskBarCornerModifier(
                    showLeftRadius: showLeftRadius,
                    showRightRadius: showRightRadius,
                    isSingle: isSingle,
                    radius: 4
                ))
                .frame(width: width - (isSingle ? 8 : (showLeftRadius || showRightRadius ? 4 : 0)), height: 16)  // 單日任務兩邊各縮 4 點，跨日任務圓角那邊縮 4 點
                .shadow(color: .black.opacity(0.2), radius: 4, x: 1, y: 1)
                .overlay(
                    content()
                        .foregroundColor(.white)
                        .frame(maxWidth: width - 8, alignment: .center)
                        .lineLimit(1)
                        .truncationMode(.tail)
                )
        }
        .frame(width: width, alignment: showLeftRadius ? .trailing : (showRightRadius ? .leading : .center))  // 開始日靠右對齊，結束日靠左對齊，中間置中
    }
}

// 新增 MonthPagerView 結構
struct MonthPagerView: View {
    @Binding var currentDate: Date
    @ObservedObject var viewModel: TodoViewModel
    @Binding var selectedDate: Date
    @Binding var showingTodoDetail: Bool
    @State private var pageIndex = 4  // 中間頁面 = 當前月份
    @State private var monthDates: [Date] = []  // 改為 @State 變量
    @State private var isAnimating = false  // 追踪動畫狀態
    private let calendar = Calendar.current
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
    
    // 預先準備 9 個月（-4 ~ +4）
    private var allMonthDates: [Date] {
        let today = calendar.startOfDay(for: Date())
        let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: today))!
        return (-4...4).map {
            calendar.date(byAdding: .month, value: $0, to: currentMonthStart)!
        }
    }
    
    // 獲取一個日期所在月份的索引
    private func getMonthIndex(for date: Date) -> Int? {
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
        
        for (index, monthDate) in allMonthDates.enumerated() {
            if calendar.isDate(monthDate, equalTo: startOfMonth, toGranularity: .month) {
                return index
            }
        }
        return nil
    }
    
    init(currentDate: Binding<Date>, viewModel: TodoViewModel, selectedDate: Binding<Date>, showingTodoDetail: Binding<Bool>) {
        self._currentDate = currentDate
        self.viewModel = viewModel
        self._selectedDate = selectedDate
        self._showingTodoDetail = showingTodoDetail
        
        // 初始化月份數組
        let today = Calendar.current.startOfDay(for: currentDate.wrappedValue)
        let currentMonth = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: today))!
        let initialDates = (-4...4).map {
            Calendar.current.date(byAdding: .month, value: $0, to: currentMonth)!
        }
        _monthDates = State(initialValue: initialDates)
        
        // 預先準備震動生成器
        feedbackGenerator.prepare()
    }
    
    var body: some View {
        GeometryReader { geometry in
            TabView(selection: $pageIndex) {
                ForEach(monthDates.indices, id: \.self) { idx in
                    CalendarMonthWithWeekdaysView(
                        calendarData: calendarData(for: monthDates[idx]),
                        monthDate: monthDates[idx],
                        geometry: geometry,
                        selectDate: { row, column in
                            if let date = getDateFromRowColumn(row: row, column: column, monthDate: monthDates[idx]) {
                                selectedDate = date
                                showingTodoDetail = true
                            }
                        },
                        viewModel: viewModel,
                        isDragging: isAnimating
                    )
                    .tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .onChange(of: pageIndex) { newIdx in
                // 當頁面索引變化時，更新當前月份
                let oldDate = currentDate
                
                withAnimation(.easeOut(duration: 0.2)) {
                    currentDate = monthDates[newIdx]
                }
                
                // 只有在月份真正改變時才觸發震動
                if !calendar.isDate(oldDate, equalTo: currentDate, toGranularity: .month) {
                    feedbackGenerator.impactOccurred(intensity: 0.5)
                }
                
                // 當滑動到邊緣時重新生成月份
                if newIdx <= 1 || newIdx >= monthDates.count - 2 {
                    // 延遲重新生成，等待動畫完成
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        let newDates = (-4...4).map {
                            calendar.date(byAdding: .month, value: $0, to: currentDate)!
                        }
                        withAnimation(nil) {
                            monthDates = newDates
                            pageIndex = 4  // 重置到中間位置
                        }
                    }
                }
            }
            .onChange(of: selectedDate) { newDate in
                // 當選擇的日期變化時，檢查是否需要切換月份
                if !calendar.isDate(currentDate, equalTo: newDate, toGranularity: .month) {
                    if let newIndex = getMonthIndex(for: newDate) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            pageIndex = newIndex
                            currentDate = monthDates[newIndex]
                        }
                    }
                }
            }
            .onAppear {
                // 初始載入時確保頁面索引與當前月份匹配
                if let initialIndex = getMonthIndex(for: currentDate) {
                    pageIndex = initialIndex
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { _ in
                        isAnimating = true
                        feedbackGenerator.prepare()
                    }
                    .onEnded { _ in
                        // 延遲重置動畫狀態
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            isAnimating = false
                        }
                    }
            )
        }
    }
    
    // 計算指定月份的日曆數據
    private func calendarData(for date: Date) -> [[String]] {
        var result: [[String]] = Array(repeating: Array(repeating: "", count: 7), count: 6)
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)
        let firstDayOfMonth = calendar.date(from: components)!
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth) - 1
        let range = calendar.range(of: .day, in: .month, for: firstDayOfMonth)!
        let daysInMonth = range.count
        
        // 上個月天數
        let prevMonth = calendar.date(byAdding: .month, value: -1, to: date)!
        let prevRange = calendar.range(of: .day, in: .month, for: prevMonth)!
        let daysInPrevMonth = prevRange.count
        
        // 填充上個月的日期
        for i in 0..<firstWeekday {
            result[0][i] = "\(daysInPrevMonth - firstWeekday + i + 1)"
        }
        
        // 填充當月的日期
        var day = 1
        var currentGridRow = 0
        var currentGridCol = firstWeekday
        while day <= daysInMonth {
            result[currentGridRow][currentGridCol] = "\(day)"
            day += 1
            currentGridCol += 1
            if currentGridCol == 7 {
                currentGridCol = 0
                currentGridRow += 1
            }
        }
        
        // 填充下個月的日期
        var nextMonthDay = 1
        while currentGridRow < 6 {
            while currentGridCol < 7 {
                result[currentGridRow][currentGridCol] = "\(nextMonthDay)"
                nextMonthDay += 1
                currentGridCol += 1
            }
            currentGridCol = 0
            currentGridRow += 1
        }
        return result
    }
    
    // 從行列獲取日期
    private func getDateFromRowColumn(row: Int, column: Int, monthDate: Date) -> Date? {
        let calendar = Calendar.current
        let dayValue = Int(calendarData(for: monthDate)[row][column]) ?? 1
        var dateComponents = calendar.dateComponents([.year, .month], from: monthDate)
        
        // 如果是上個月的日期
        if row == 0 && column < calendar.component(.weekday, from: monthDate) - 1 {
            if let prevMonth = calendar.date(byAdding: .month, value: -1, to: monthDate) {
                dateComponents = calendar.dateComponents([.year, .month], from: prevMonth)
            }
        }
        // 如果是下個月的日期
        else if dayValue <= 14 && row >= 4 {
            if let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthDate) {
                dateComponents = calendar.dateComponents([.year, .month], from: nextMonth)
            }
        }
        
        dateComponents.day = dayValue
        return calendar.date(from: dateComponents)
    }
}

// 方便後面判斷「同一天」用
let utcCalendar = Calendar(identifier: .gregorian)

// 處理缺少的屬性
extension TodoTask {
    // 如果 TodoTask 已經有 isAllDay 屬性，就註釋掉這個屬性
    /*
    var isAllDay: Bool {
        // 默認邏輯：如果開始時間和結束時間的時分秒都是0，視為全天事件
        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.hour, .minute, .second], from: startDate)
        let endComponents = calendar.dateComponents([.hour, .minute, .second], from: endDate)
        
        return startComponents.hour == 0 && startComponents.minute == 0 && startComponents.second == 0 &&
               endComponents.hour == 0 && endComponents.minute == 0 && endComponents.second == 0
    }
    */
}

// Array 安全下標擴展
extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// 修改任務列表視圖，調整間距
struct TaskListView: View {
    let tasksForThisDay: [TodoTask?]   // 改成 Optional 陣列
    let cellDate: Date
    let geometry: GeometryProxy
    let maxRows: Int = maxTaskRows // 使用全域常數

    var body: some View {
        ZStack(alignment: .top) {
            ForEach(0..<maxRows, id: \.self) { rowIdx in
                if let task = tasksForThisDay[safe: rowIdx], let unwrappedTask = task {  // 如果有任務才畫
                    SingleTaskBarView(
                        task: unwrappedTask,
                        cellDate: cellDate,
                        width: geometry.size.width / 7,
                        rowIdx: rowIdx
                    )
                }
            }
        }
    }
}
