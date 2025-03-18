import SwiftUI

// MARK: - 任務數據模型
/// 待辦事項數據模型，包含任務的基本信息
struct TodoItem: Identifiable {
    let id = UUID()                // 唯一標識符
    var title: String              // 任務標題
    var date: Date                 // 任務日期
    var startTime: Date            // 開始時間
    var durationHours: Int         // 持續時間（小時）
    var isCompleted: Bool          // 完成狀態
}

// MARK: - 新增任務視圖
/// 用於添加新任務的彈出視圖
struct AddTodoView: View {
    @Environment(\.dismiss) var dismiss       // 環境變量，用於關閉視圖
    @Binding var todos: [TodoItem]            // 綁定的任務數組
    @Binding var isPresented: Bool            // 控制視圖顯示狀態
    @State private var title = ""             // 任務標題輸入
    @State private var startTime = Date()     // 開始時間
    @State private var durationHours = 1      // 持續時間，默認1小時
    let selectedDate: Date                    // 選中的日期
    
    var body: some View {
        VStack {
            // 標題
            Text("新增任務")
                .font(.headline)
                .padding(.top)
            
            // 表單輸入區域
            VStack(spacing: 15) {
                // 任務名稱輸入框
                TextField("任務名稱", text: $title)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                // 開始時間選擇器
                DatePicker("開始時間", selection: $startTime, displayedComponents: .hourAndMinute)
                    .padding(.horizontal)
                
                // 持續時間步進器
                Stepper(value: $durationHours, in: 1...24) {
                    Text("持續時間: \(durationHours) 小時")
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
            
            // 底部按鈕區域
            HStack(spacing: 20) {
                // 取消按鈕
                Button("取消") {
                    isPresented = false  // 關閉視圖
                }
                .foregroundColor(.red)
                
                // 新增按鈕
                Button("新增") {
                    // 創建新任務並添加到數組
                    let newTodo = TodoItem(
                        title: title,
                        date: selectedDate,
                        startTime: startTime,
                        durationHours: durationHours,
                        isCompleted: false
                    )
                    todos.append(newTodo)
                    isPresented = false  // 關閉視圖
                }
                .disabled(title.isEmpty)  // 標題為空時禁用按鈕
            }
            .padding(.bottom)
        }
        .frame(width: 280)  // 控制視圖寬度
        .background(Color.white)
        .cornerRadius(15)
    }
}

// MARK: - 任務列表項視圖
/// 顯示單個任務的行視圖
struct TodoItemRow: View {
    let todo: TodoItem  // 要顯示的任務
    
    var body: some View {
        VStack(alignment: .leading) {
            // 任務標題
            Text(todo.title)
                .font(.title3)
                .bold()
            
            // 任務時間信息
            Text("\(todo.startTime.formatted(date: .omitted, time: .shortened)) - \(durationText)")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.vertical, 5)
    }
    
    /// 計算結束時間文本
    private var durationText: String {
        let calendar = Calendar.current
        if let endTime = calendar.date(byAdding: .hour, value: todo.durationHours, to: todo.startTime) {
            return endTime.formatted(date: .omitted, time: .shortened)
        }
        return ""
    }
}

// MARK: - 日曆主視圖
struct CalendarView: View {
    // MARK: 狀態變量
    @State private var selectedDate = Date()  // 當前選中的日期
    @State private var showingDetail = false  // 控制詳情視圖顯示
    @State private var showingAddTask = false // 控制添加任務視圖顯示
    
    // 示例任務數據
    @State private var todos: [TodoItem] = [
        TodoItem(title: "買牛奶", date: Date(), startTime: Date(), durationHours: 1, isCompleted: false),
        TodoItem(title: "完成 Swift 專案", date: Date(), startTime: Date(), durationHours: 2, isCompleted: false),
        TodoItem(title: "運動 30 分鐘", date: Date(), startTime: Date(), durationHours: 1, isCompleted: false)
    ]
    
    // MARK: 計算屬性
    /// 過濾選中日期的任務
    var filteredTodos: [TodoItem] {
        todos.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
    }
    
    // MARK: 視圖體
    var body: some View {
        ZStack {
            // 主日曆視圖
            NavigationStack {
                VStack(alignment: .leading, spacing: 20) {
                    // 頂部年份和工具按鈕
                    HStack {
                        Text("\(yearString)")
                            .font(.title2)
                            .foregroundColor(.red)
                        Spacer()
                        
                        // 右上角功能按鈕
                        HStack(spacing: 20) {
                            Button(action: {}) {
                                Image(systemName: "line.3.horizontal")
                                    .foregroundColor(.red)
                            }
                            Button(action: {}) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.red)
                            }
                            Button(action: {}) {
                                Image(systemName: "plus")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // 月份顯示
                    Text("\(monthString)")
                        .font(.system(size: 40, weight: .bold))
                        .padding(.horizontal)
                    
                    // 星期標題行
                    HStack {
                        ForEach(["日", "一", "二", "三", "四", "五", "六"], id: \.self) { day in
                            Text(day)
                                .frame(maxWidth: .infinity)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal)
                    
                    // 日期網格
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 15) {
                        ForEach(0..<42) { index in
                            if let date = getDate(for: index) {
                                VStack(spacing: 5) {
                                    // 日期數字
                                    Text("\(Calendar.current.component(.day, from: date))")
                                        .font(.system(size: 20))

                                    // 顯示當天的任務列表
                                    VStack(alignment: .leading) {
                                        ForEach(todos.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }) { todo in
                                            Text(todo.title)
                                                .font(.caption2)
                                                .foregroundColor(.gray)
                                                .lineLimit(1)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                    }.frame(height: 30)
                                }
                                .frame(height: 60)
                                .overlay(
                                    // 今天的日期添加紅色圓圈標記
                                    Circle()
                                        .stroke(isToday(date) ? Color.red : Color.clear, lineWidth: 1)
                                )
                                .onTapGesture {
                                    // 點擊日期顯示詳情
                                    selectedDate = date
                                    showingDetail = true
                                }
                            } else {
                                // 空白單元格
                                Text("")
                                    .frame(height: 60)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
            }
            
            // MARK: 任務詳情彈出視圖
            if showingDetail {
                // 半透明背景遮罩
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        showingDetail = false
                    }
                
                // 任務詳情視圖
                VStack {
                    // 頂部標題和添加按鈕
                    HStack {
                        Text(dateFormatted)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        // 添加任務按鈕
                        Button(action: {
                            showingAddTask = true
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                                .font(.title)
                        }
                    }
                    .padding()
                    
                    // 任務列表
                    List {
                        ForEach(filteredTodos) { todo in
                            TodoItemRow(todo: todo)
                        }
                        .onDelete(perform: deleteTodo)  // 支持滑動刪除
                    }
                    .frame(maxHeight: 300)
                    
                    // 關閉按鈕
                    Button("關閉") {
                        showingDetail = false
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding(.bottom)
                }
                .frame(width: 300)
                .background(Color.white)
                .cornerRadius(15)
                .shadow(radius: 10)
                .zIndex(1)
            }
            
            // MARK: 新增任務彈出視圖
            if showingAddTask {
                // 半透明背景遮罩
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        showingAddTask = false
                    }
                
                // 新增任務表單
                AddTodoView(
                    todos: $todos,
                    isPresented: $showingAddTask,
                    selectedDate: selectedDate
                )
                .shadow(radius: 10)
                .zIndex(2)
            }
        }
    }
    
    // MARK: 輔助函數
    /// 刪除任務
    private func deleteTodo(at offsets: IndexSet) {
        // 獲取要刪除的任務ID
        let filteredIndices = offsets.map { filteredTodos[$0] }
        // 從主數組中移除這些任務
        todos.removeAll { todo in
            filteredIndices.contains { $0.id == todo.id }
        }
    }
    
    /// 格式化完整日期
    private var dateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: selectedDate)
    }
    
    /// 獲取年份字符串
    private var yearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年"
        return formatter.string(from: selectedDate)
    }
    
    /// 獲取月份字符串
    private var monthString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月"
        return formatter.string(from: selectedDate)
    }
    
    /// 計算網格中索引對應的日期
    private func getDate(for index: Int) -> Date? {
        let calendar = Calendar.current
        // 獲取月份的第一天
        let firstDayOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedDate))!
        // 獲取月份第一天是星期幾
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        // 計算偏移天數
        let offsetDays = index - (firstWeekday - 1)
        // 返回對應的日期
        return calendar.date(byAdding: .day, value: offsetDays, to: firstDayOfMonth)
    }
    
    /// 檢查日期是否是今天
    private func isToday(_ date: Date) -> Bool {
        Calendar.current.isDate(date, inSameDayAs: Date())
    }
    
    /// 獲取指定日期的任務摘要文本
    private func tasksForDate(_ date: Date) -> String {
        // 過濾出當天的任務
        let tasks = todos.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
        // 只顯示前兩個任務的標題
        let taskTitles = tasks.prefix(2).map { $0.title }
        // 如果有更多任務，添加省略號
        return taskTitles.joined(separator: ", ") + (tasks.count > 2 ? "..." : "")
    }
}

// MARK: - 預覽
#Preview {
    CalendarView()
}
