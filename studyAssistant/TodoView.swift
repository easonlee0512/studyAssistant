import SwiftUI

struct TodoView: View {
    @State private var tasks: [Task] = []
    @State private var showingAddTask = false
    @State private var newTaskTitle = ""
    
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
    var dueDate: Date
    var isCompleted: Bool
    var priority: Priority
    
    enum Priority: String, CaseIterable {
        case high = "高"
        case medium = "中"
        case low = "低"
    }
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
                
                Text(task.dueDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            PriorityBadge(priority: task.priority)
        }
    }
}

// 優先級標籤
struct PriorityBadge: View {
    let priority: Task.Priority
    
    var body: some View {
        Text(priority.rawValue)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(priorityColor.opacity(0.2))
            .foregroundColor(priorityColor)
            .clipShape(Capsule())
    }
    
    var priorityColor: Color {
        switch priority {
        case .high:
            return .red
        case .medium:
            return .orange
        case .low:
            return .blue
        }
    }
}

// 添加任務視圖
struct AddTaskView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var tasks: [Task]
    @State private var title = ""
    @State private var dueDate = Date()
    @State private var priority: Task.Priority = .medium
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("任務名稱", text: $title)
                
                DatePicker("截止日期", selection: $dueDate)
                
                Picker("優先級", selection: $priority) {
                    ForEach(Task.Priority.allCases, id: \.self) { priority in
                        Text(priority.rawValue).tag(priority)
                    }
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
                        let task = Task(title: title, dueDate: dueDate, isCompleted: false, priority: priority)
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
