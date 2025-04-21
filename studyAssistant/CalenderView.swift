import SwiftUI
import SwiftUICore

// MARK: - 日曆主視圖
struct CalendarView: View {
    // MARK: 狀態變量
    @State private var selectedDate = Date()  // 當前選中的日期
    @State private var currentDate = Date()   // 顯示的當前月份
    @State private var showingAddTask = false // 控制添加任務視圖顯示
    @State private var showingTodoDetail = false // 控制待辦詳情視圖顯示
    
    // 用于TodoAddView的任务列表
    @State private var todoTasks: [TodoTask] = []
    
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
                    Spacer()

                    Text(monthYearString)
                        .font(.system(size: 24, weight: .medium))
                        .kerning(0.5)
                        .foregroundColor(.black)

                    Spacer()

                    Button(action: {
                        showingAddTask = true
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color(red: 0.89, green: 0.54, blue: 0.37, opacity: 0.8))
                                .frame(width: 30, height: 30)

                            Text("+")
                                .font(.system(size: 30))
                                .foregroundColor(Color(red: 0.97, green: 0.87, blue: 0.78))
                                .offset(y: -2)
                        }
                    }
                    .padding(.trailing, 15)
                }
                .padding(.top, 20)
                .padding(.bottom, 10)

                // 星期標題
                HStack(spacing: 0) {
                    ForEach(["日", "一", "二", "三", "四", "五", "六"], id: \.self) { day in
                        Text(day)
                            .font(.system(size: 15))
                            .frame(maxWidth: .infinity)
                            .padding(.bottom, 5)
                    }
                }
                
                // 日期格子
                GeometryReader { geometry in
                    VStack(spacing: 8) {
                        ForEach(0..<6) { row in
                            HStack(spacing: 0) {
                                ForEach(0..<7) { column in
                                    let dateText = calendarData[row][column]
                                    
                                    // 日期格子视图改为居中对齐
                                    Text(dateText)
                                        .font(.system(size: 15))
                                        .foregroundColor(isCurrentMonth(row, column) ? .black : .black.opacity(0.25))
                                        .frame(width: geometry.size.width / 7, alignment: .center)
                                        .frame(height: (geometry.size.height / 6) - 8)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            selectDate(row, column)
                                        }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            // 使用TodoAddView替代原有的AddTodoView
            if showingAddTask {
                TodoAddView(tasks: $todoTasks, isPresented: $showingAddTask)
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
        let dayValue = Int(calendarData[row][column]) ?? 1
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
        let dayNumber = Int(calendarData[row][column]) ?? 0
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
    
    /// 生成月曆數據
    var calendarData: [[String]] {
        var result: [[String]] = Array(repeating: Array(repeating: "", count: 7), count: 6)
        
        let firstWeekday = firstWeekdayOfMonth
        let lastDayOfPrevMonth = daysInPrevMonth
        
        // 填充上個月的日期
        for i in 0..<firstWeekday {
            result[0][i] = "\(lastDayOfPrevMonth - firstWeekday + i + 1)"
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
}
