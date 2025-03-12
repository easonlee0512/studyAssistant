import SwiftUI

struct TodoView: View {
    @State private var tasks: [Task] = []
    @State private var showingAddTask = false
    
    var body: some View {
        NavigationStack {
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
            .navigationTitle("待辦事項")
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

#Preview {
    TodoView()
}
