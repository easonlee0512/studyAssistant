import SwiftUI

// 首先定義任務模型
struct TodoItem: Identifiable {
    let id = UUID()
    var title: String
    var date: Date
    var startTime: Date
    var durationHours: Int
    var isCompleted: Bool
}

// 新增任務視圖
struct AddTodoView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var todos: [TodoItem]
    @Binding var isPresented: Bool
    @State private var title = ""
    @State private var startTime = Date()
    @State private var durationHours = 1
    let selectedDate: Date
    
    var body: some View {
        VStack {
            Text("新增任務")
                .font(.headline)
                .padding(.top)
            
            VStack(spacing: 15) {
                TextField("任務名稱", text: $title)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                DatePicker("開始時間", selection: $startTime, displayedComponents: .hourAndMinute)
                    .padding(.horizontal)
                
                Stepper(value: $durationHours, in: 1...24) {
                    Text("持續時間: \(durationHours) 小時")
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
            
            HStack(spacing: 20) {
                Button("取消") {
                    isPresented = false
                }
                .foregroundColor(.red)
                
                Button("新增") {
                    let newTodo = TodoItem(
                        title: title,
                        date: selectedDate,
                        startTime: startTime,
                        durationHours: durationHours,
                        isCompleted: false
                    )
                    todos.append(newTodo)
                    isPresented = false
                }
                .disabled(title.isEmpty)
            }
            .padding(.bottom)
        }
        .frame(width: 280)
        .background(Color.white)
        .cornerRadius(15)
    }
}

// 在 CalendarView 中修改任務列表項的顯示
struct TodoItemRow: View {
    let todo: TodoItem
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(todo.title)
                .font(.title3)
                .bold()
            
            Text("\(todo.startTime.formatted(date: .omitted, time: .shortened)) - \(durationText)")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.vertical, 5)
    }
    
    private var durationText: String {
        let calendar = Calendar.current
        if let endTime = calendar.date(byAdding: .hour, value: todo.durationHours, to: todo.startTime) {
            return endTime.formatted(date: .omitted, time: .shortened)
        }
        return ""
    }
}

struct CalendarView: View {
    @State private var selectedDate = Date()
    @State private var showingDetail = false
    @State private var showingAddTask = false
    @State private var todos: [TodoItem] = [
        TodoItem(title: "買牛奶", date: Date(), startTime: Date(), durationHours: 1, isCompleted: false),
        TodoItem(title: "完成 Swift 專案", date: Date(), startTime: Date(), durationHours: 2, isCompleted: false),
        TodoItem(title: "運動 30 分鐘", date: Date(), startTime: Date(), durationHours: 1, isCompleted: false)
    ]
    
    var filteredTodos: [TodoItem] {
        todos.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
    }
    
    var body: some View {
        ZStack {
            NavigationStack {
                VStack(alignment: .leading, spacing: 20) {
                    // 年份顯示
                    HStack {
                        Text("\(yearString)")
                            .font(.title2)
                            .foregroundColor(.red)
                        Spacer()
                        
                        // 右上角按鈕
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
                    
                    // 星期列
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
                                    Text("\(Calendar.current.component(.day, from: date))")
                                        .font(.system(size: 20))

                                    VStack(alignment: .leading) { // 讓待辦事項換行顯示
                                    ForEach(todos.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }) { todo in
                                            Text(todo.title)
                                                .font(.caption2)
                                                .foregroundColor(.gray)
                                                .lineLimit(1)
                                                .frame(maxWidth: .infinity, alignment: .leading) // 左對齊
                                        }
                                    }.frame(height: 30)
                                }
                                .frame(height: 60)
                                .overlay(
                                    Circle()
                                        .stroke(isToday(date) ? Color.red : Color.clear, lineWidth: 1)
                                )
                                .onTapGesture {
                                    selectedDate = date
                                    showingDetail = true
                                }
                            } else {
                                Text("")
                                    .frame(height: 60)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
            }
            
            // 半透明背景和 TodoDetailView
            if showingDetail {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        showingDetail = false
                    }
                
                VStack {
                    HStack {
                        Text(dateFormatted)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        Button(action: {
                            showingAddTask = true
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                                .font(.title)
                        }
                    }
                    .padding()
                    
                    List {
                        ForEach(filteredTodos) { todo in
                            TodoItemRow(todo: todo)
                        }
                        .onDelete(perform: deleteTodo)
                    }
                    .frame(maxHeight: 300)
                    
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
            
            // 修改新增任務視圖的顯示方式
            if showingAddTask {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        showingAddTask = false
                    }
                
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
    
    // 刪除任務
    private func deleteTodo(at offsets: IndexSet) {
        let filteredIndices = offsets.map { filteredTodos[$0] }
        todos.removeAll { todo in
            filteredIndices.contains { $0.id == todo.id }
        }
    }
    
    // 格式化日期
    private var dateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: selectedDate)
    }
    
    private var yearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年"
        return formatter.string(from: selectedDate)
    }
    
    private var monthString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月"
        return formatter.string(from: selectedDate)
    }
    
    private func getDate(for index: Int) -> Date? {
        let calendar = Calendar.current
        let firstDayOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedDate))!
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        let offsetDays = index - (firstWeekday - 1)
        return calendar.date(byAdding: .day, value: offsetDays, to: firstDayOfMonth)
    }
    
    private func isToday(_ date: Date) -> Bool {
        Calendar.current.isDate(date, inSameDayAs: Date())
    }
    private func tasksForDate(_ date: Date) -> String {
    let tasks = todos.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
    let taskTitles = tasks.prefix(2).map { $0.title }
    return taskTitles.joined(separator: ", ") + (tasks.count > 2 ? "..." : "")
}

}

#Preview {
    CalendarView()
}
