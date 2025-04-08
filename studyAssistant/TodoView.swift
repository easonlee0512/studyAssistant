import SwiftUI

// TodoView 是主要的待辦事項視圖，顯示倒數計時、今日日期、一週的日曆以及待辦事項列表。
struct TodoView: View {
    @State private var selectedDate = Date() // 儲存當前選擇的日期
    @State private var tasks: [TodoTask] = [] // 儲存待辦事項列表
    @State private var showingAddTask = false // 控制是否顯示添加任務的視圖
    @State private var userGoal: String = ""  // 存儲用戶設定的目標
    @State private var targetDate: Date? = nil  // 存儲目標日期
    
    // 計算從今天到目標日期還剩下多少天
    private var daysRemaining: Int {
        let today = Calendar.current.startOfDay(for: Date())
        // 如果有目標日期就使用目標日期，否則默認使用50天後
        let targetDate = self.targetDate ?? Calendar.current.date(byAdding: .day, value: 50, to: Date())!
        let target = Calendar.current.startOfDay(for: targetDate)
        return Calendar.current.dateComponents([.day], from: today, to: target).day ?? 0
    }
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                // 顯示用戶目標或默認倒數天數
                HStack {
                    if !userGoal.isEmpty {
                        Text(userGoal)  // 顯示用戶設定的目標
                            .font(.largeTitle)
                            .bold()
                            .foregroundColor(.red)
                            .padding(.all)
                    } else {
                        Text("考試倒數 \(daysRemaining) 天")  // 默認顯示
                            .font(.largeTitle)
                            .bold()
                            .foregroundColor(.red)
                            .padding(.all)
                    }
                    Spacer()
                }
                
                // 顯示選擇的日期（年-月-日格式）
                Text(selectedDate, format: Date.FormatStyle().year().month().day())
                    .font(.title)
                    .bold()
                    .padding()
                
                // 顯示一週日曆視圖
                WeekCalendarView(selectedDate: $selectedDate)
                    .padding(.horizontal)
                    .frame(maxWidth: .infinity, alignment: .center)
                
                List {
                    // 今日待辦事項區域
                    Section(header: HStack {
                        Text("今日待辦")
                        Spacer() // 右側空白
                        Button(action: {
                            showingAddTask = true // 顯示添加任務視圖
                        }) {
                            Image(systemName: "plus") // 顯示「+」按鈕
                        }
                    }) {
                        // 過濾並顯示尚未完成的待辦事項
                        ForEach(tasks.filter { !$0.isCompleted }) { task in
                            TaskRow(task: task) { updatedTask in
                                // 更新任務狀態
                                if let index = tasks.firstIndex(where: { $0.id == updatedTask.id }) {
                                    tasks[index] = updatedTask
                                }
                            }
                        }
                        .onDelete(perform: deleteTasks) // 支援刪除任務
                    }
                    
                    // 已完成事項區域
                    Section(header: Text("已完成")) {
                        // 顯示已完成的任務
                        ForEach(tasks.filter { $0.isCompleted }) { task in
                            TaskRow(task: task) { updatedTask in
                                // 更新任務狀態
                                if let index = tasks.firstIndex(where: { $0.id == updatedTask.id }) {
                                    tasks[index] = updatedTask
                                }
                            }
                        }
                        .onDelete(perform: deleteTasks) // 支援刪除任務
                    }
                }
                .sheet(isPresented: $showingAddTask) {
                    AddTaskView(tasks: $tasks) // 顯示新增任務的視圖
                }
                
                Spacer() // 使內容底部空間自適應
            }
            .onAppear {
                loadUserSettings()  // 載入用戶設定
            }
        }
    }
    
    // 載入用戶設定
    private func loadUserSettings() {
        // 從 UserDefaults 讀取用戶設定的目標
        userGoal = UserDefaults.standard.string(forKey: "userGoal") ?? ""
        
        // 從 UserDefaults 讀取目標日期
        if let savedDate = UserDefaults.standard.object(forKey: "targetDate") as? Date {
            targetDate = savedDate
        }
    }
    
    // 刪除任務
    private func deleteTasks(at offsets: IndexSet) {
        tasks.remove(atOffsets: offsets)
    }
}

// 任務模型，用於存儲每個任務的資料
struct TodoTask: Identifiable {
    let id = UUID() // 唯一的識別符
    var title: String // 任務標題
    var startDate: Date // 任務開始時間
    var isCompleted: Bool // 是否完成
}

// 顯示單個任務的行視圖
struct TaskRow: View {
    @State var task: TodoTask
    var onUpdate: (TodoTask) -> Void // 任務更新回調
    
    var body: some View {
        HStack {
            // 任務的完成狀態切換
            Button(action: {
                task.isCompleted.toggle() // 切換完成狀態
                onUpdate(task) // 更新任務狀態
            }) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(task.isCompleted ? .green : .gray) // 根據是否完成變換顏色
            }
            
            VStack(alignment: .leading) {
                // 顯示任務標題
                Text(task.title)
                    .strikethrough(task.isCompleted) // 完成的任務標題加刪除線
                    .font(.title3)
                    .bold()
                    .foregroundColor(task.isCompleted ? .gray : .primary)
                
                // 顯示任務開始時間
                Text(task.startDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer() // 右邊空白
        }
    }
}

// 新增任務的視圖
struct AddTaskView: View {
    @Environment(\.dismiss) var dismiss // 用於關閉當前視圖
    @Binding var tasks: [TodoTask] // 傳入待辦事項列表的綁定
    @State private var title = "" // 任務標題
    @State private var startTime = Date() // 任務開始時間
    @State private var durationHours = 1 // 任務持續時間（小時）
    
    var body: some View {
        NavigationStack {
            Form {
                // 任務名稱輸入框
                TextField("任務名稱", text: $title)
                
                // 任務開始時間選擇器
                DatePicker("開始時間", selection: $startTime, displayedComponents: .hourAndMinute)
                
                // 任務持續時間選擇器
                Stepper(value: $durationHours, in: 1...24) {
                    Text("持續時間: \(durationHours) 小時")
                }
            }
            .navigationTitle("新增任務")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // 取消按鈕
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss() // 關閉視圖
                    }
                }
                
                // 確認按鈕（新增任務）
                ToolbarItem(placement: .confirmationAction) {
                    Button("新增") {
                        let task = TodoTask(title: title, startDate: startTime, isCompleted: false)
                        tasks.append(task) // 將新任務添加到任務列表
                        dismiss() // 關閉視圖
                    }
                    .disabled(title.isEmpty) // 如果任務名稱为空，禁用新增按鈕
                }
            }
        }
    }
}

// 一週日曆視圖，用於顯示並選擇一週中的日期
struct WeekCalendarView: View {
    @Binding var selectedDate: Date // 綁定當前選擇的日期
    private let calendar = Calendar.current
    
    // 取得當前週的日期
    private var weekDates: [Date] {
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: startOfWeek) }
    }
    
    var body: some View {
        HStack {
            // 顯示每一天的日期和星期
            ForEach(weekDates, id: \.self) { date in
                VStack {
                    Text(date, format: .dateTime.weekday(.abbreviated))
                        .font(.caption)
                    Text(date, format: .dateTime.day())
                        .font(.headline)
                        .foregroundColor(calendar.isDate(date, inSameDayAs: selectedDate) ? .white : .primary)
                        .frame(width: 40, height: 40)
                        .background(calendar.isDate(date, inSameDayAs: selectedDate) ? Color.black : Color.clear)
                        .clipShape(Circle()) // 使用圓形背景來突出顯示選中的日期
                        .onTapGesture {
                            selectedDate = date // 更新選中的日期
                        }
                }
            }
        }
    }
}

#Preview {
    TodoView() // 預覽 TodoView 視圖
}
