import SwiftUI

struct TodoView: View {
    @State private var selectedDate = Date()
    @State private var tasks: [Task] = []
    @State private var showingAddTask = false
    
    // 倒數 50 天的目標日期
    private let countdownTargetDate = Calendar.current.date(byAdding: .day, value: 50, to: Date())!
    
    // 計算倒數天數
    private var daysRemaining: Int {
        let today = Calendar.current.startOfDay(for: Date())
        let target = Calendar.current.startOfDay(for: countdownTargetDate)
        return Calendar.current.dateComponents([.day], from: today, to: target).day ?? 0
    }
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                // 左上角顯示「考研倒數 50 天」，字體放大
                HStack {
                    Text("考研倒數 \(daysRemaining) 天")
                        .font(.largeTitle) // 放大字體
                        .bold()
                        .foregroundColor(.red)
                        .padding(.all)
                    Spacer()
                }
                
                // 顯示當前年月日
                Text(selectedDate, format: Date.FormatStyle().year().month().day())
                    .font(.title)
                    .bold()
                    .padding()
                
                // 一週日曆
                WeekCalendarView(selectedDate: $selectedDate)
                    .padding(.horizontal)
                    .frame(maxWidth: .infinity, alignment: .center)
                
                List {
                    // 今日待辦事項
                    Section(header: HStack {
                        Text("今日待辦")
                        Spacer()
                        Button(action: {
                            showingAddTask = true
                        }) {
                            Image(systemName: "plus")
                        }
                    }) {
                        ForEach(tasks.filter { !$0.isCompleted }) { task in
                            TaskRow(task: task) { updatedTask in
                                if let index = tasks.firstIndex(where: { $0.id == updatedTask.id }) {
                                    tasks[index] = updatedTask
                                }
                            }
                        }
                        .onDelete(perform: deleteTasks)
                    }
                    
                    // 已完成事項
                    Section(header: Text("已完成")) {
                        ForEach(tasks.filter { $0.isCompleted }) { task in
                            TaskRow(task: task) { updatedTask in
                                if let index = tasks.firstIndex(where: { $0.id == updatedTask.id }) {
                                    tasks[index] = updatedTask
                                }
                            }
                        }
                        .onDelete(perform: deleteTasks)
                    }
                }
                .sheet(isPresented: $showingAddTask) {
                    AddTaskView(tasks: $tasks)
                }
                
                Spacer()
            }
        }
    }
    
    private func deleteTasks(at offsets: IndexSet) {
        tasks.remove(atOffsets: offsets)
    }
}

// 任務模型
struct Task: Identifiable {
    let id = UUID()
    var title: String
    var startDate: Date
    var isCompleted: Bool
}

// 任務列表項
struct TaskRow: View {
    @State var task: Task
    var onUpdate: (Task) -> Void
    
    var body: some View {
        HStack {
            Button(action: {
                task.isCompleted.toggle()
                onUpdate(task)
            }) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(task.isCompleted ? .green : .gray)
            }
            
            VStack(alignment: .leading) {
                Text(task.title)
                    .strikethrough(task.isCompleted)
                    .font(.title3)
                    .bold()
                    .foregroundColor(task.isCompleted ? .gray : .primary)
                
                Text(task.startDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
    }
}

// 添加任務視圖
struct AddTaskView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var tasks: [Task]
    @State private var title = ""
    @State private var startTime = Date()
    @State private var durationHours = 1
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("任務名稱", text: $title)
                
                DatePicker("開始時間", selection: $startTime, displayedComponents: .hourAndMinute)
                
                Stepper(value: $durationHours, in: 1...24) {
                    Text("持續時間: \(durationHours) 小時")
                }
            }
            .navigationTitle("新增任務")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("新增") {
                        let task = Task(title: title, startDate: startTime, isCompleted: false)
                        tasks.append(task)
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}

// 一週日曆視圖
struct WeekCalendarView: View {
    @Binding var selectedDate: Date
    private let calendar = Calendar.current
    
    private var weekDates: [Date] {
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: startOfWeek) }
    }
    
    var body: some View {
        HStack {
            ForEach(weekDates, id: \.self) { date in
                VStack {
                    Text(date, format: .dateTime.weekday(.abbreviated))
                        .font(.caption)
                    Text(date, format: .dateTime.day())
                        .font(.headline)
                        .foregroundColor(calendar.isDate(date, inSameDayAs: selectedDate) ? .white : .primary)
                        .frame(width: 40, height: 40)
                        .background(calendar.isDate(date, inSameDayAs: selectedDate) ? Color.black : Color.clear)
                        .clipShape(Circle())
                        .onTapGesture {
                            selectedDate = date
                        }
                }
            }
        }
    }
}

#Preview {
    TodoView()
}
