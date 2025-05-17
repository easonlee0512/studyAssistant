import SwiftUI
import SwiftUICore
import FirebaseFirestore
import FirebaseAuth
// 添加 Date 擴展的引用



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
                .padding(.bottom, 35)  // 從 25 改為 35，增加底部間距
                .frame(height: 80)
                .background(backgroundColor)

                // 日曆部分
                GeometryReader { calendarGeometry in
                    let calendarHeight = calendarGeometry.size.height
                    HStack(spacing: 0) {
                        // 左邊月份（上個月）
                        CalendarMonthWithWeekdaysView(
                            calendarData: calendarData(for: Calendar.current.date(byAdding: .month, value: -1, to: currentDate) ?? currentDate),
                            monthDate: Calendar.current.date(byAdding: .month, value: -1, to: currentDate) ?? currentDate,
                            geometry: calendarGeometry,
                            selectDate: selectDate,
                            viewModel: viewModel,
                            isDragging: isDragging
                        )
                        .frame(width: calendarGeometry.size.width)
                        
                        // 當前月份
                        CalendarMonthWithWeekdaysView(
                            calendarData: calendarData(for: currentDate),
                            monthDate: currentDate,
                            geometry: calendarGeometry,
                            selectDate: selectDate,
                            viewModel: viewModel,
                            isDragging: isDragging
                        )
                        .frame(width: calendarGeometry.size.width)
                        
                        // 右邊月份（下個月）
                        CalendarMonthWithWeekdaysView(
                            calendarData: calendarData(for: Calendar.current.date(byAdding: .month, value: 1, to: currentDate) ?? currentDate),
                            monthDate: Calendar.current.date(byAdding: .month, value: 1, to: currentDate) ?? currentDate,
                            geometry: calendarGeometry,
                            selectDate: selectDate,
                            viewModel: viewModel,
                            isDragging: isDragging
                        )
                        .frame(width: calendarGeometry.size.width)
                    }
                    .frame(height: calendarHeight)
                    .offset(x: -calendarGeometry.size.width + offsetX)
                    .drawingGroup()  // 添加 GPU 加速
                    .clipped()
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 1, coordinateSpace: .local)  // 將最小滑動距離從 3 降至 1
                            .onChanged { value in
                                if !isDragging {
                                    withAnimation(.easeInOut(duration: 0.1)) {
                                        isDragging = true
                                    }
                                }
                                offsetX = value.translation.width
                            }
                            .onEnded { value in
                                let width = calendarGeometry.size.width
                                let threshold = width / 8  // 將閾值從 width/5 降至 width/8
                                let velocity = value.predictedEndTranslation.width - value.translation.width
                                let shouldChange = abs(value.translation.width) > threshold || abs(velocity) > 100  // 降低速度閾值從 200 到 100
                                
                                var targetOffset: CGFloat = 0
                                var newDate: Date? = nil
                                
                                if value.translation.width < 0 && shouldChange {
                                    targetOffset = -width
                                    newDate = Calendar.current.date(byAdding: .month, value: 1, to: currentDate)
                                } else if value.translation.width > 0 && shouldChange {
                                    targetOffset = width
                                    newDate = Calendar.current.date(byAdding: .month, value: -1, to: currentDate)
                                }
                                
                                // 加快動畫速度
                                withAnimation(.easeOut(duration: 0.2)) {
                                    offsetX = targetOffset
                                }
                                
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    isDragging = false
                                }
                                
                                // 加快切換速度
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    if let d = newDate {
                                        currentDate = d
                                        let generator = UIImpactFeedbackGenerator(style: .light)
                                        generator.impactOccurred()
                                    }
                                    offsetX = 0
                                }
                            }
                    )
                }
                .padding(.top, 20)  // 從 15 改為 20，增加頂部間距
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
                isCurrentMonth: true,
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

// 修改 CalendarMonthView 讓格子自動平均分配
struct CalendarMonthView: View {
    let calendarData: [[String]]
    let monthDate: Date
    let isCurrentMonth: Bool
    let geometry: GeometryProxy
    let selectDate: (Int, Int) -> Void
    let viewModel: TodoViewModel
    let isDragging: Bool
    @State private var selectedDateId: String? = nil
    private let calendar = Calendar.current
    var body: some View {
        let cellHeight = (geometry.size.height - 25) / 6
        VStack(spacing: 0) {
            ForEach(0..<6) { row in
                HStack(spacing: 0) {
                    ForEach(0..<7) { column in
                        let dateText = calendarData[row][column]
                        let cellDate = getCellDate(row: row, column: column)
                        let tasksForThisDay = cellDate.map { date in
                            viewModel.tasksForDate(date)
                        } ?? []
                        let dateLabelHeight: CGFloat = 20
                        let isToday = cellDate.map { calendar.isDateInToday($0) } ?? false
                        let isCurrentMonth = !((row == 0 && Int(dateText) ?? 0 > 7) || 
                                            (row >= 4 && Int(dateText) ?? 0 < 15))
                        let isSelected = selectedDateId == "\(row)-\(column)"
                        ZStack {
                            Rectangle()
                                .fill(Color.clear)
                                .frame(width: geometry.size.width / 7, height: cellHeight)
                            VStack(spacing: 3) {
                                // 日期數字和今日圓圈
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
                                .frame(height: dateLabelHeight)
                                
                                // 任務列表
                                VStack(spacing: 2) {
                                    ForEach(Array(tasksForThisDay.prefix(4)), id: \.id) { task in
                                        TaskBarView(
                                            color: task.color,
                                            showLeftRadius: true,
                                            showRightRadius: true,
                                            isSingle: true,
                                            width: geometry.size.width / 7 - 6
                                        ) {
                                            Text(task.title)
                                                .font(.system(size: 9, weight: .medium))
                                                .foregroundColor(.white)
                                                .lineLimit(1)
                                        }
                                        .frame(maxWidth: geometry.size.width / 7 - 6)
                                        .clipped()
                                        .transition(.opacity.combined(with: .scale))
                                        .animation(.spring(response: 0.3), value: task.id)
                                    }
                                    if tasksForThisDay.count > 4 {
                                        Text("+\(tasksForThisDay.count - 4)")
                                            .font(.system(size: 7))
                                            .foregroundColor(.gray)
                                            .padding(.bottom, -8)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 2)
                            }
                        }
                        .frame(width: geometry.size.width / 7, height: cellHeight)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedDateId = "\(row)-\(column)"
                            selectDate(row, column)
                        }
                    }
                }
            }
        }
        .frame(width: geometry.size.width, height: geometry.size.height - 25)
        .drawingGroup()  // 添加 GPU 加速
        .animation(nil, value: isDragging)
    }
    
    // 計算這格的 Date，根據 monthDate
    func getCellDate(row: Int, column: Int) -> Date? {
        let dateText = calendarData[row][column]
        guard let day = Int(dateText) else { return nil }
        let calendar = Calendar.current
        var dateComponents = calendar.dateComponents([.year, .month], from: monthDate)
        dateComponents.day = day
        // 判斷這格是本月、上月還是下月
        if row == 0 && day > 7 {
            // 上個月
            if let prevMonth = calendar.date(byAdding: .month, value: -1, to: monthDate) {
                var prevComponents = calendar.dateComponents([.year, .month], from: prevMonth)
                prevComponents.day = day
                return calendar.date(from: prevComponents)
            }
        } else if row >= 4 && day < 15 {
            // 下個月
            if let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthDate) {
                var nextComponents = calendar.dateComponents([.year, .month], from: nextMonth)
                nextComponents.day = day
                return calendar.date(from: nextComponents)
            }
        }
        // 本月
        return calendar.date(from: dateComponents)
    }
}

// 修改 TaskBarView，讓橫條寬度填滿格子，並支援左右圓角
struct TaskBarView<Content: View>: View {
    let color: Color
    let showLeftRadius: Bool
    let showRightRadius: Bool
    let isSingle: Bool
    let width: CGFloat
    let content: () -> Content
    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 4)
                .fill(color)
                .modifier(TaskBarCornerModifier(showLeftRadius: showLeftRadius, showRightRadius: showRightRadius, isSingle: isSingle, radius: 4))
                .frame(width: width - 4, height: 16)  // 減少寬度
                .shadow(color: .black.opacity(0.09), radius: 3, x: 3, y: 3)
            content()
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 2)  // 減少左邊間距（原本是 3）
        }
        .frame(width: width)
        .drawingGroup()  // 添加 GPU 加速
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
            content.clipShape(RoundedRectangle(cornerRadius: radius))
        } else if showLeftRadius && showRightRadius {
            content.clipShape(RoundedRectangle(cornerRadius: radius))
        } else if showLeftRadius {
            content.clipShape(RoundedCorners(radius: radius, corners: [.topLeft, .bottomLeft]))
        } else if showRightRadius {
            content.clipShape(RoundedCorners(radius: radius, corners: [.topRight, .bottomRight]))
        } else {
            content.clipShape(Rectangle())
        }
    }
}

// 自訂 shape 支援部分圓角
struct RoundedCorners: Shape {
    var radius: CGFloat = 8.0
    var corners: UIRectCorner = .allCorners
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

// 已將 Date 擴充移至 Extensions/Date+Extension.swift
// extension Date {
//     var startOfDay: Date {
//         Calendar.current.startOfDay(for: self)
//     }
// }
