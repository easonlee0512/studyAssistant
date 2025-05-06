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
import Foundation // 確保可以訪問 NotificationConstants

// 通知名稱常數已移至 NotificationConstants.swift
// extension Notification.Name {
//     static let todoDataDidChange = Notification.Name("todoDataDidChange")
//     static let userAuthDidChange = Notification.Name("userAuthDidChange")
// }

@MainActor
class TodoViewModel: ObservableObject {
    @Published private(set) var tasks: [TodoTask] = []
    private let firebaseService = FirebaseService.shared
    private var authStateListener: AuthStateDidChangeListenerHandle?
    
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
    
    // 添加選中的日期
    @Published var selectedDate: Date = Date()
    
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
        
        // 監聽 Auth 狀態
        setupAuthListener()
    }
    
    deinit {
        // 移除通知監聽
        NotificationCenter.default.removeObserver(self)
        
        // 移除 Auth 監聽
        if let authStateListener = authStateListener {
            Auth.auth().removeStateDidChangeListener(authStateListener)
        }
    }
    
    // 設置通知監聽
    private func setupNotificationObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDataChange),
            name: .todoDataDidChange,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUserAuthChange),
            name: .userAuthDidChange,
            object: nil
        )
    }
    
    // 設置驗證狀態監聽
    private func setupAuthListener() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] (auth, user) in
            Task { @MainActor in
                if user != nil {
                    // 使用者登入，重新載入資料
                    try? await self?.loadTasks()
                } else {
                    // 使用者登出，清空資料
                    self?.tasks = []
                }
                
                // 發送使用者驗證狀態改變通知
                NotificationCenter.default.post(name: .userAuthDidChange, object: nil)
            }
        }
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
    
    // 處理使用者驗證狀態變更通知
    @objc private func handleUserAuthChange() {
        Task {
            do {
                try await loadTasks()
            } catch {
                print("Error reloading tasks after auth change: \(error)")
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
        
        // 確保已經登入
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw ValidationError.notLoggedIn
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
            endDate: newTaskEndDate,
            userId: currentUserId
        )
        
        try await firebaseService.saveTodoTask(task)
        tasks.append(task)
        
        // 發送資料變更通知
        postDataChangeNotification()
    }
    
    // 載入所有任務
    func loadTasks() async throws {
        // 確保已經登入
        guard Auth.auth().currentUser != nil else {
            tasks = []
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        // 首先嘗試進行數據遷移
        do {
            try await firebaseService.migrateTasksToUserCollection()
        } catch {
            print("任務遷移錯誤（可能已經遷移完成）: \(error.localizedDescription)")
        }
        
        // 載入任務
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
        isLoading = true
        errorMessage = nil
        
        // 確保已經登入
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            errorMessage = "請先登入再新增任務"
            isLoading = false
            return
        }
        
        do {
            // 確保任務有使用者 ID
            var updatedTask = task
            updatedTask.userId = currentUserId
            
            try await firebaseService.saveTodoTask(updatedTask)
            
            // 重新加載任務列表以獲取最新數據
            try await loadTasks()
            
            // 發送資料變更通知
            postDataChangeNotification()
            
            // 清空錯誤訊息
            errorMessage = nil
        } catch {
            // 設置錯誤訊息
            errorMessage = "儲存任務失敗: \(error.localizedDescription)"
            print("Error adding task: \(error)")
        }
        
        isLoading = false
    }
    
    func updateTask(_ task: TodoTask) async {
        // 確保已經登入
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("Error: User not logged in")
            return
        }
        
        do {
            // 確保任務有使用者 ID
            var updatedTask = task
            if updatedTask.userId.isEmpty {
                updatedTask.userId = currentUserId
            }
            
            try await firebaseService.saveTodoTask(updatedTask)
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
    case notLoggedIn
    
    var errorDescription: String? {
        switch self {
        case .emptyTitle:
            return "任務標題不能為空"
        case .notLoggedIn:
            return "請先登入再新增任務"
        }
    }
}

