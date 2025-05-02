//
//  TodoViewModel.swift
//  studyAssistant
//
//  Created by 李翊辰 on 2025/5/1.
//
import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore

// 定義通知名稱常數
extension Notification.Name {
    static let todoDataDidChange = Notification.Name("todoDataDidChange")
}

@MainActor
class TodoViewModel: ObservableObject {
    @Published private(set) var tasks: [TodoTask] = []
    private let firebaseService = FirebaseService.shared
    
    // 新增任務相關狀態
    @Published var newTaskTitle = ""
    @Published var newTaskNote = ""
    @Published var newTaskColor = Color(red: 0.7, green: 0.16, blue: 0.13).opacity(0.4)
    @Published var newTaskFocusTime = 30
    @Published var newTaskCategory = "學習"
    @Published var newTaskIsAllDay = false
    @Published var newTaskStartDate = Date()
    @Published var newTaskEndDate = Date().addingTimeInterval(3600)
    @Published var newTaskRepeatType: RepeatType = .none
    @Published var newTaskSelectedDays: Set<Int> = []
    @Published var newTaskSelectedMonthDays: Set<Int> = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // 預定義的顏色選項
    let colorOptions: [Color] = [
        Color(red: 0.7, green: 0.16, blue: 0.13).opacity(0.4),
        Color(red: 0.7, green: 0.56, blue: 0).opacity(0.4),
        Color(red: 0.18, green: 0.7, blue: 0.31).opacity(0.4),
        Color(red: 0.29, green: 0.28, blue: 0.7).opacity(0.4)
    ]
    
    // 重複選項
    let repeatOptions = ["不重複", "每天", "每週", "每月"]
    
    init() {
        Task {
            do {
                try await loadTasks()
            } catch {
                print("Error loading tasks: \(error)")
            }
        }
        
        // 設置通知監聽
        setupNotificationObserver()
    }
    
    deinit {
        // 移除通知監聽
        NotificationCenter.default.removeObserver(self)
    }
    
    // 設置通知監聽
    private func setupNotificationObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDataChange),
            name: .todoDataDidChange,
            object: nil
        )
    }
    
    // 處理資料變更通知
    @objc private func handleDataChange() {
        Task {
            do {
                try await loadTasks()
            } catch {
                print("Error reloading tasks from notification: \(error)")
            }
        }
    }
    
    // 發送資料變更通知
    private func postDataChangeNotification() {
        NotificationCenter.default.post(name: .todoDataDidChange, object: nil)
    }
    
    // 初始化新任務表單
    func initNewTaskForm(selectedDate: Date) {
        newTaskTitle = ""
        newTaskNote = ""
        newTaskColor = colorOptions[0]
        newTaskFocusTime = 30
        newTaskCategory = "學習"
        newTaskIsAllDay = false
        newTaskStartDate = selectedDate
        newTaskEndDate = selectedDate.addingTimeInterval(3600)
        newTaskRepeatType = .none
        newTaskSelectedDays.removeAll()
        newTaskSelectedMonthDays.removeAll()
        errorMessage = nil
    }
    
    // 轉換重複選項為 RepeatType
    func convertRepeatOption(_ option: String) -> RepeatType {
        switch option {
        case "每天":
            return .daily
        case "每週":
            return .weekly(Array(newTaskSelectedDays))
        case "每月":
            return .monthly(Array(newTaskSelectedMonthDays))
        default:
            return .none
        }
    }
    
    // 格式化日期
    func formatDate(_ date: Date, isDateOnly: Bool) -> String {
        let formatter = DateFormatter()
        if isDateOnly {
            formatter.dateFormat = "M月 d日 EEE"
        } else {
            formatter.dateFormat = "HH:mm"
        }
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
    
    // 驗證並儲存新任務
    func saveNewTask() async throws {
        guard !newTaskTitle.isEmpty else {
            throw ValidationError.emptyTitle
        }
        
        isLoading = true
        defer { isLoading = false }
        
        let task = TodoTask(
            title: newTaskTitle,
            note: newTaskNote,
            color: newTaskColor,
            focusTime: newTaskFocusTime,
            category: newTaskCategory,
            isAllDay: newTaskIsAllDay,
            isCompleted: false,
            repeatType: newTaskRepeatType,
            startDate: newTaskStartDate,
            endDate: newTaskEndDate
        )
        
        try await firebaseService.saveTodoTask(task)
        tasks.append(task)
        
        // 發送資料變更通知
        postDataChangeNotification()
    }
    
    // 載入所有任務
    func loadTasks() async throws {
        isLoading = true
        defer { isLoading = false }
        
        tasks = try await firebaseService.fetchTodoTasks()
    }
    
    // 刪除任務
    func deleteTask(_ task: TodoTask) async throws {
        try await firebaseService.deleteTodoTask(task.id)
        tasks.removeAll { $0.id == task.id }
        
        // 發送資料變更通知
        postDataChangeNotification()
    }
    
    func addTask(_ task: TodoTask) async {
        do {
            try await firebaseService.saveTodoTask(task)
            do {
                try await loadTasks()
                
                // 發送資料變更通知
                postDataChangeNotification()
            } catch {
                print("Error loading tasks: \(error)")
            }
        } catch {
            print("Error adding task: \(error)")
        }
    }
    
    func updateTask(_ task: TodoTask) async {
        do {
            try await firebaseService.saveTodoTask(task)
            do {
                try await loadTasks()
                
                // 發送資料變更通知
                postDataChangeNotification()
            } catch {
                print("Error loading tasks: \(error)")
            }
        } catch {
            print("Error updating task: \(error)")
        }
    }
    
    func toggleTaskCompletion(_ task: TodoTask) async {
        var updatedTask = task
        updatedTask.isCompleted.toggle()
        await updateTask(updatedTask)
    }
    
    // MARK: - 任務過濾
    func tasksForDate(_ date: Date) -> [TodoTask] {
        tasks.filter { task in
            task.shouldDisplay(on: date)
        }
    }
    
    func tasksForCategory(_ category: String) -> [TodoTask] {
        tasks.filter { $0.category == category }
    }
    
    // MARK: - 任務排序
    func sortedTasks(by date: Date) -> [TodoTask] {
        let filteredTasks = tasksForDate(date)
        return filteredTasks.sorted { task1, task2 in
            if task1.isCompleted == task2.isCompleted {
                return task1.startDate < task2.startDate
            }
            return !task1.isCompleted && task2.isCompleted
        }
    }
}

// 驗證錯誤
enum ValidationError: LocalizedError {
    case emptyTitle
    
    var errorDescription: String? {
        switch self {
        case .emptyTitle:
            return "任務標題不能為空"
        }
    }
}

