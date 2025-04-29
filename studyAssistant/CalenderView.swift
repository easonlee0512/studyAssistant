import SwiftUI
import SwiftUICore



// MARK: - 日曆主視圖
struct CalendarView: View {
    // MARK: 狀態變量
    @State private var selectedDate = Date()  // 當前選中的日期
    @State private var currentDate = Date()   // 顯示的當前月份
    @State private var showingAddTask = false // 控制添加任務視圖顯示
    @State private var showingTodoDetail = false // 控制待辦詳情視圖顯示
    @EnvironmentObject var allTasks: AllTasks // 全域任務環境物件
    @GestureState private var dragOffset: CGFloat = 0 // 用於偵測滑動
    @State private var pageOffset: CGFloat = 0 // 用於動畫偏移
    
    // 待辦事項列表（這裡是示例，實際應從數據源獲取）
    @State private var todos: [String] = ["完成數學作業", "準備英文演講", "讀完物理課本第五章", "健身1小時"]
    
    // 背景和底部导航颜色
    let backgroundColor = Color(red: 0.95, green: 0.83, blue: 0.72)
    let bottomBarColor = Color(hex: "FEECD8")
    
    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 標題與新增任務按鈕
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
                        ZStack {
                            Circle()
                                .fill(Color(hex: "E28A5F"))
                                .frame(width: 30, height: 30)

                            Text("+")
                                .font(.system(size: 30))
                                .foregroundColor(Color(red: 0.97, green: 0.87, blue: 0.78))
                                .offset(y: -2)
                        }
                    }
                    .padding(.trailing, 15)
                    .frame(width: 45)
                }
                .padding(.top, 7)
                .padding(.bottom, 7)

                GeometryReader { geometry in
                    let width = geometry.size.width
                    HStack(spacing: 0) {
                        // 上個月
                        CalendarMonthWithWeekdaysView(
                            calendarData: calendarData(for: Calendar.current.date(byAdding: .month, value: -1, to: currentDate)!),
                            monthDate: Calendar.current.date(byAdding: .month, value: -1, to: currentDate)!,
                            geometry: geometry,
                            selectDate: selectDate
                        )
                        // 本月
                        CalendarMonthWithWeekdaysView(
                            calendarData: calendarData(for: currentDate),
                            monthDate: currentDate,
                            geometry: geometry,
                            selectDate: selectDate
                        )
                        // 下個月
                        CalendarMonthWithWeekdaysView(
                            calendarData: calendarData(for: Calendar.current.date(byAdding: .month, value: 1, to: currentDate)!),
                            monthDate: Calendar.current.date(byAdding: .month, value: 1, to: currentDate)!,
                            geometry: geometry,
                            selectDate: selectDate
                        )
                    }
                    .frame(width: width * 3, alignment: .leading)
                    .offset(x: -width + dragOffset + pageOffset)
                    .gesture(
                        DragGesture()
                            .updating($dragOffset) { value, state, _ in
                                state = value.translation.width
                            }
                            .onEnded { value in
                                let threshold: CGFloat = width / 3
                                if value.translation.width < -threshold {
                                    // 向左滑，下一個月
                                    withAnimation(.spring()) {
                                        pageOffset = -width
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                        if let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentDate) {
                                            currentDate = nextMonth
                                        }
                                        pageOffset = 0
                                    }
                                } else if value.translation.width > threshold {
                                    // 向右滑，上個月
                                    withAnimation(.spring()) {
                                        pageOffset = width
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                        if let prevMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentDate) {
                                            currentDate = prevMonth
                                        }
                                        pageOffset = 0
                                    }
                                } else {
                                    // 沒有超過閾值，彈回原位
                                    withAnimation(.spring()) {
                                        pageOffset = 0
                                    }
                                }
                            }
                    )
                }
                .padding(.horizontal)
            }
            
            // 使用TodoAddView替代原有的AddTodoView
            if showingAddTask {
                TodoAddView(isPresented: $showingAddTask)
                    .transition(.move(edge: .bottom))
                    .zIndex(2)
            }
            
            // 顯示待辦事項詳情視圖
            if showingTodoDetail {
                TodoDetailView(
                    date: selectedDate,
                    todos: todos,
                    isPresented: $showingTodoDetail
                )
                .transition(.scale)
                .zIndex(2)
            }
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
        .environmentObject(AllTasks())
}

// 新增一個 CalendarMonthWithWeekdaysView，包住星期標題和格子
struct CalendarMonthWithWeekdaysView: View {
    let calendarData: [[String]]
    let monthDate: Date
    let geometry: GeometryProxy
    let selectDate: (Int, Int) -> Void
    let weekDays = ["日", "一", "二", "三", "四", "五", "六"]
    @EnvironmentObject var allTasks: AllTasks
    var body: some View {
        VStack(spacing: 0) {
            // 星期標題
            HStack(spacing: 0) {
                ForEach(weekDays, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 15))
                        .frame(width: geometry.size.width / 7)
                        .padding(.bottom, 5)
                }
            }
            .frame(height: 30)
            // 日期格子
            CalendarMonthView(
                calendarData: calendarData,
                monthDate: monthDate,
                isCurrentMonth: true,
                geometry: geometry,
                selectDate: selectDate
            )
            .environmentObject(allTasks)
        }
    }
}

// 修改 CalendarMonthView 支援橫跨多天的任務橫條
struct CalendarMonthView: View {
    let calendarData: [[String]]
    let monthDate: Date
    let isCurrentMonth: Bool
    let geometry: GeometryProxy
    let selectDate: (Int, Int) -> Void
    @EnvironmentObject var allTasks: AllTasks
    var body: some View {
        let cellHeight = geometry.size.height / 7  // 改小格子高度
        VStack(spacing: 0) {
            ForEach(0..<6) { row in
                HStack(spacing: 0) {
                    ForEach(0..<7) { column in
                        let dateText = calendarData[row][column]
                        let cellDate = getCellDate(row: row, column: column)
                        let tasksForThisDay = allTasks.tasks.filter { task in
                            guard let cellDate = cellDate else { return false }
                            if task.repeatType == .daily {
                                return true
                            }
                            return cellDate >= task.startDate.startOfDay && cellDate <= task.endDate.startOfDay
                        }
                        let dateLabelHeight: CGFloat = 20   // 預留給日期數字的高度
                        ZStack {
                            // 背景
                            Rectangle()
                                .fill(Color.clear)
                                .frame(width: geometry.size.width / 7, height: cellHeight)
                            
                            // 任務區域
                            VStack(spacing: 0) {
                                Spacer()
                                    .frame(height: dateLabelHeight)
                                
                                // 任務橫條區域
                                VStack(spacing: 2) {
                                    Spacer()
                                        .frame(height: 1)  // 加入頂部間距
                                    
                                    ForEach(Array(tasksForThisDay.prefix(4)), id: \ .id) { task in
                                        let isStart = cellDate != nil && Calendar.current.isDate(cellDate!, inSameDayAs: task.startDate)
                                        let isEnd = cellDate != nil && Calendar.current.isDate(cellDate!, inSameDayAs: task.endDate)
                                        let isLeftEdge = column == 0
                                        let isRightEdge = column == 6
                                        let showLeftRadius = isLeftEdge
                                        let showRightRadius = isRightEdge
                                        TaskBarView(
                                            color: task.color,
                                            showLeftRadius: showLeftRadius,
                                            showRightRadius: showRightRadius,
                                            isSingle: false,
                                            width: geometry.size.width / 7
                                        ) {
                                            Text(task.title)
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundColor(.white)
                                                .lineLimit(1)
                                        }
                                    }
                                    
                                    if tasksForThisDay.count > 4 {
                                        Text("+\(tasksForThisDay.count - 4)")
                                            .font(.system(size: 8))
                                            .foregroundColor(.gray)
                                            .padding(.bottom, 2)
                                    }
                                }
                                .frame(maxHeight: cellHeight - dateLabelHeight,
                                               alignment: .top)//向上對其
                                
                                Spacer(minLength: 0)
                            }
                            
                            // 日期數字（永遠在最上層）
                            VStack {
                                Text(dateText)
                                    .font(.system(size: 15))
                                    .foregroundColor(.black)
                                    .frame(height: dateLabelHeight, alignment: .top)
                                    .padding(.leading, 2)
                                    .padding(.top, 2)
                                
                                Spacer()
                            }
                        }
                        .frame(width: geometry.size.width / 7, height: cellHeight)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectDate(row, column)
                        }
                    }
                }
            }
        }
        .frame(width: geometry.size.width)
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
        .frame(width: width)  // 保持外部容器原始寬度
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

// Date 擴充，取得當天 00:00:00
extension Date {
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }
}
