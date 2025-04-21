import SwiftUI
import SwiftUICore

// TodoView 是主要的待辦事項視圖，顯示倒數計時、今日日期、一週的日曆以及待辦事項列表。
struct TodoView: View {
    @State private var selectedDate = Date() // 儲存當前選擇的日期
    @State private var tasks: [TodoTask] = [] // 儲存待辦事項列表
    @State private var showingAddTask = false // 控制是否顯示添加任務的視圖
    @State private var userGoal: String = ""  // 存儲用戶設定的目標
    @State private var targetDate: Date? = nil  // 存儲目標日期
    @State private var selectedDay = Calendar.current.component(.day, from: Date()) // 当前选中的日期
    
    // 計算從今天到目標日期還剩下多少天
    private var daysRemaining: Int {
        let today = Calendar.current.startOfDay(for: Date())
        // 如果有目標日期就使用目標日期，否則默認使用50天後
        let targetDate = self.targetDate ?? Calendar.current.date(byAdding: .day, value: 50, to: Date())!
        let target = Calendar.current.startOfDay(for: targetDate)
        return Calendar.current.dateComponents([.day], from: today, to: target).day ?? 0
    }
    
    // 示例任务（当没有任务时显示）
    private var sampleTasks: [TodoTask] {
        return [
            TodoTask(title: "線性代數", note: "備註", startDate: Date(), color: Color(red: 0.7, green: 0.16, blue: 0.13).opacity(0.4), isCompleted: false),
            TodoTask(title: "離散數學", note: "備註", startDate: Date(), color: Color(red: 0.7, green: 0.56, blue: 0).opacity(0.4), isCompleted: false),
            TodoTask(title: "資料結構", note: "復習第四章", startDate: Date(), color: Color(red: 0.18, green: 0.7, blue: 0.31).opacity(0.4), isCompleted: false),
            TodoTask(title: "計算機結構", note: "準備期中考", startDate: Date(), color: Color(red: 0.29, green: 0.28, blue: 0.7).opacity(0.4), isCompleted: true)
        ]
    }
    
    var body: some View {
        ZStack {
            // 背景色
            Color(hex: "F3D4B7")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                VStack(spacing: 20) {
                    // 顯示用戶目標或默認倒數天數
                    VStack(alignment: .leading, spacing: 5) {
                        if !userGoal.isEmpty {
                            Text(userGoal)
                                .font(.system(size: 30, weight: .bold))
                        } else {
                            Text("考試倒數 \(daysRemaining) 天")
                                .font(.system(size: 30, weight: .bold))
                        }
                        
                        // 顯示當前日期
                        Text(formattedDate)
                            .font(.system(size: 24, weight: .bold))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top)
                    
                    // 週曆視圖 - 使用新的样式
                    WeekViewNew(selectedDay: $selectedDay)
                        .padding(.horizontal)
                    
                    // 待辦事項標題
                    HStack {
                        Text("To Do List")
                            .font(.system(size: 24, weight: .bold))
                        Spacer()
                        Button(action: {
                            showingAddTask = true // 顯示添加任務視圖
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(Color(hex: "E28A5F"))
                        }
                    }
                    .padding(.horizontal)
                }
                
                // 任務列表 - 使用新的样式
                ScrollView {
                    VStack(spacing: 15) {
                        if tasks.isEmpty {
                            // 如果没有任务，显示示例任务
                            ForEach(sampleTasks) { task in
                                TaskRowNewView(task: task, isExample: true)
                            }
                        } else {
                            // 顯示未完成的任務
                            ForEach(tasks.filter { !$0.isCompleted }) { task in
                                TaskRowNewView(task: task) { updatedTask in
                                    // 更新任務狀態
                                    if let index = tasks.firstIndex(where: { $0.id == updatedTask.id }) {
                                        tasks[index] = updatedTask
                                    }
                                }
                            }
                            
                            // 顯示已完成的任務
                            ForEach(tasks.filter { $0.isCompleted }) { task in
                                TaskRowNewView(task: task) { updatedTask in
                                    // 更新任務狀態
                                    if let index = tasks.firstIndex(where: { $0.id == updatedTask.id }) {
                                        tasks[index] = updatedTask
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 15)
                }
                .padding(.bottom, 0)
            }
            
            // 使用ZStack直接覆盖显示TodoAddView，而不是使用sheet
            if showingAddTask {
                TodoAddView(tasks: $tasks, isPresented: $showingAddTask)
                    .transition(.move(edge: .bottom))
                    .zIndex(1)
            }
        }
        .onAppear {
            loadUserSettings() // 載入用戶設定
        }
    }
    
    // 格式化日期為 "Mar 3, 2025" 格式
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: selectedDate)
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

// 擴展任務模型，添加新的字段
struct TodoTask: Identifiable {
    let id = UUID() // 唯一的識別符
    var title: String // 任務標題
    var note: String = "" // 任務備註
    var startDate: Date // 任務開始時間
    var color: Color = Color(red: 0.7, green: 0.56, blue: 0).opacity(0.4) // 任務顏色
    var isCompleted: Bool // 是否完成
    
    // 格式化時間為字符串
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: startDate)
    }
}

// 新的任務行視圖 - 使用新的样式
struct TaskRowNewView: View {
    @State var task: TodoTask
    var isExample: Bool = false
    var onUpdate: ((TodoTask) -> Void)? = nil
    
    var body: some View {
        HStack {
            Image(systemName: "checklist")
                .resizable()
                .frame(width: 30, height: 30)
                .foregroundColor(.black.opacity(0.8))
            
            VStack(alignment: .leading, spacing: 5) {
                Text(task.title)
                    .font(.system(size: 20, weight: .semibold))
                    .strikethrough(task.isCompleted)
                
                Text(task.note)
                    .font(.system(size: 15))
                    .foregroundColor(.black.opacity(0.6))
                
                Text(task.formattedTime)
                    .font(.system(size: 15))
            }
            .padding(.leading, 10)
            
            Spacer()
            
            if !isExample {
                Button(action: {
                    task.isCompleted.toggle()
                    if let onUpdate = onUpdate {
                        onUpdate(task)
                    }
                }) {
                    Image(systemName: task.isCompleted ? "checkmark.square.fill" : "square")
                        .font(.system(size: 24))
                        .foregroundColor(.black)
                }
            } else {
                Image(systemName: "square")
                    .font(.system(size: 24))
                    .foregroundColor(.black)
            }
        }
        .padding()
        .background(task.color)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.09), radius: 10, x: 3, y: 3)
    }
}

// 新的週曆視圖 - 使用新的样式
struct WeekViewNew: View {
    @Binding var selectedDay: Int
    let days = ["Sun", "Mon", "Tue", "Wed", "Thr", "Fri", "Sat"]
    
    var dates: [Int] {
        let currentDay = Calendar.current.component(.day, from: Date())
        let startDay = currentDay - 3
        return (0..<7).map { startDay + $0 }
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            ForEach(0..<7) { index in
                VStack(spacing: 5) {
                    Text(days[index])
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(dates[index] == selectedDay ? .black : Color(hex: "222222"))
                    
                    Text("\(dates[index])")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)
                }
                .frame(width: (373 - 24) / 7, height: 78)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(dates[index] == selectedDay ? Color(red: 0.86, green: 0.55, blue: 0.38, opacity: 0.9) : Color(hex: "FEECD8"))
                )
                .onTapGesture {
                    selectedDay = dates[index]
                }
            }
        }
        .padding(.leading, 0)
        .padding(.trailing, 1)
        .padding(.vertical, 0.84615)
        .frame(width: 373, alignment: .center)
        .background(Color(hex: "FEECD8"))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.04), radius: 6, x: 1, y: 1)
    }
}

#Preview {
    TodoView()
}
