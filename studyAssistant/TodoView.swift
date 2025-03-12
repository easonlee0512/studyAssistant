import SwiftUI

struct TodoView: View {
    @State private var tasks: [Task] = []
    @State private var showingAddTask = false
    
    struct WeekCalendarView: View {
        @Binding var currentDate: Date
        private let weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

        var body: some View {
            VStack(spacing: 15) {
                HStack {
                    ForEach(weekdays, id: \.self) { day in
                        Text(day).font(.system(size: 18, weight: .bold)).frame(maxWidth: .infinity)
                    }
                }

                HStack {
                    ForEach(0..<7) { index in
                        let date = getDate(for: index)
                        VStack {
                            Text("\(Calendar.current.component(.day, from: date))")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(isToday(date) ? .white : .primary)
                                .frame(width: 40, height: 40)
                                .background(Circle().fill(isToday(date) ? Color.primary : Color.clear))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }

        private func getDate(for index: Int) -> Date {
            let calendar = Calendar.current
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: currentDate)?.start ?? Date()
            return calendar.date(byAdding: .day, value: index, to: startOfWeek) ?? Date()
        }

        private func isToday(_ date: Date) -> Bool {
            return Calendar.current.isDateInToday(date)
        }
    }

    
    var body: some View {
        NavigationStack {
            VStack {
                WeekCalendarView(currentDate: .constant(Date()))
                    .padding(.bottom, 10)
                
                List {
                    // 今日待辦事項
                    Section(header: Text("今日待辦")) {
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
                
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            showingAddTask = true
                        }) {
                            Image(systemName: "plus")
                        }
                    }
                }
                .sheet(isPresented: $showingAddTask) {
                    AddTaskView(tasks: $tasks)
                }
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
            
            VStack(alignment: .leading, spacing: 5) {
                Text(task.title)
                    .strikethrough(task.isCompleted)
                    .font(.title3)
                    .bold()
                    .foregroundColor(task.isCompleted ? .gray : .primary)

                Text(task.startDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.gray)
            }.padding(.vertical, 10)
            
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

struct StatusBarView: View {
    @State private var currentTime = Date()
    
    let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack {
            Text(timeString).font(.system(size: 34, weight: .bold))
            Spacer()
            
            HStack(spacing: 10) {
                SignalView()
                Text("4G").fontWeight(.bold)
                BatteryView()
            }
        }
        .padding()
        .onReceive(timer) { _ in
            currentTime = Date()
        }
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "H:mm"
        return formatter.string(from: currentTime)
    }
}

struct SignalView: View {
    var body: some View {
        Image(systemName: "antenna.radiowaves.left.and.right")
            .font(.system(size: 20))
            .foregroundColor(.gray)
    }
}

struct BatteryView: View {
    var body: some View {
        Image(systemName: "battery.100")
            .font(.system(size: 20))
            .foregroundColor(.green)
    }
}

#Preview {
    TodoView()
}
