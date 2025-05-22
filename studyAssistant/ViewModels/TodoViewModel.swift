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

@MainActor
class TodoViewModel: ObservableObject {
    @Published private(set) var tasks: [TodoTask] = []
    private let firebaseService = FirebaseService.shared
    private var authStateListener: AuthStateDidChangeListenerHandle?
    
    // 新增任務相關狀態
    @Published var newTaskTitle = ""
    @Published var newTaskNote = ""
    @Published var newTaskColor = Color(red: 0.7, green: 0.16, blue: 0.13).opacity(0.4)
    @Published var newTaskFocusTime = 0
    @Published var newTaskCategory = "學習"
    @Published var newTaskIsAllDay = false
    @Published var newTaskStartDate = Date()
    @Published var newTaskEndDate = Date().addingTimeInterval(3600)
    @Published var newTaskRepeatType: RepeatType = .none
    @Published var newTaskRepeatEndDate: Date? = nil
    @Published var newTaskSelectedDays: Set<Int> = []
    @Published var newTaskSelectedMonthDays: Set<Int> = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    @Published var keyboardHeight: CGFloat = 0  // 追蹤鍵盤高度
    
    // 預定義的顏色選項
    let colorOptions: [Color] = [
        Color(red: 0.7, green: 0.16, blue: 0.13).opacity(0.4),
        Color(red: 0.7, green: 0.56, blue: 0).opacity(0.4),
        Color(red: 0.18, green: 0.7, blue: 0.31).opacity(0.4),
        Color(red: 0.29, green: 0.28, blue: 0.7).opacity(0.4)
    ]
    
    // 重複選項
    let repeatOptions = ["不重複", "每天", "每週", "每月"]
    
    // 添加一個標記來記錄是否已經嘗試過遷移
    private var hasMigrationAttempted = false
    
    // 添加一個變數來記錄上次載入時間
    private var lastTasksLoadTime: Date? = nil
    // 添加一個變數來設定快取時間（秒）
    private let cacheTimeInterval: TimeInterval = 60 // 1分鐘快取
    
    // 添加一個變數來保存監聽器
    private var tasksListener: ListenerRegistration?
    
    // 添加一個佇列來處理待更新的任務
    private var pendingUpdates: [String: TodoTask] = [:]
    private var updateTimer: Timer?
    
    // 添加一個佇列來處理待更新的任務
    private var completionUpdateQueue: [String: (task: TodoTask, retryCount: Int)] = [:]
    private var isProcessingQueue = false
    
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
        
        // 設置 Firestore 實時監聽
        setupFirestoreListener()
    }
    
    deinit {
        // 移除通知監聽
        NotificationCenter.default.removeObserver(self)
        
        // 移除 Auth 監聽
        if let authStateListener = authStateListener {
            Auth.auth().removeStateDidChangeListener(authStateListener)
        }
        
        // 移除 Firestore 監聽
        tasksListener?.remove()
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
                    // 設置 Firestore 監聽
                    self?.setupFirestoreListener()
                } else {
                    // 使用者登出，清空資料
                    self?.tasks = []
                    // 移除 Firestore 監聽
                    self?.tasksListener?.remove()
                }
                
                // 發送使用者驗證狀態改變通知
                NotificationCenter.default.post(name: .userAuthDidChange, object: nil)
            }
        }
    }
    
    // 設置 Firestore 實時監聽
    private func setupFirestoreListener() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        // 移除舊的監聽器
        tasksListener?.remove()
        
        // 設置新的監聽器
        tasksListener = firebaseService.db.collection("tasks")
            .document(userId)
            .collection("userTasks")
            .addSnapshotListener { [weak self] (snapshot: QuerySnapshot?, error: Error?) in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error listening for task updates: \(error)")
                    return
                }
                
                guard let snapshot = snapshot else { return }
                
                // 檢查是否有變化
                let changes = snapshot.documentChanges
                if !changes.isEmpty {
                    print("檢測到任務更新，共 \(changes.count) 個變化")
                    
                    Task {
                        do {
                            // 直接重新載入所有任務，包括實例
                            let updatedTasks = try await self.firebaseService.fetchTodoTasks()
                            
                            // 在主線程更新 UI
                            await MainActor.run {
                                self.tasks = updatedTasks
                                self.lastTasksLoadTime = Date()
                                // 發送資料變更通知
                                NotificationCenter.default.post(name: .todoDataDidChange, object: nil)
                            }
                        } catch {
                            print("Error reloading tasks: \(error)")
                        }
                    }
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
            // 檢查用戶是否已登入
            if Auth.auth().currentUser != nil {
                // 用戶已登入，重新載入任務
                do {
                    try await loadTasks()
                } catch {
                    print("Error reloading tasks after auth change: \(error)")
                }
            } else {
                // 用戶已登出，清空任務列表
                await MainActor.run {
                    self.tasks = []
                    print("用戶已登出，任務列表已清空")
                }
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
        newTaskFocusTime = 0
        newTaskCategory = "學習"
        newTaskIsAllDay = false
        newTaskStartDate = selectedDate
        newTaskEndDate = selectedDate.addingTimeInterval(3600)
        newTaskRepeatType = .none
        newTaskRepeatEndDate = nil
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
            return .weekly
        case "每月":
            return .monthly
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
            repeatEndDate: newTaskRepeatType != .none ? newTaskRepeatEndDate : nil,
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
        
        // 強制重新載入資料
        isLoading = true
        defer { isLoading = false }
        
        // 只在第一次載入時嘗試進行數據遷移
        if !hasMigrationAttempted {
            do {
                try await firebaseService.migrateTasksToUserCollection()
                hasMigrationAttempted = true
            } catch {
                print("任務遷移錯誤（可能已經遷移完成）: \(error.localizedDescription)")
                hasMigrationAttempted = true
            }
        }
        
        // 載入任務
        tasks = try await firebaseService.fetchTodoTasks()
        lastTasksLoadTime = Date()
        print("從Firebase重新載入任務數據")
        
        // 設置監聽器（如果還沒有設置）
        if tasksListener == nil {
            setupFirestoreListener()
        }
    }
    
    // 刪除任務
    func deleteTask(_ task: TodoTask) async throws {
        // 確保已經登入
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw ValidationError.notLoggedIn
        }
        
        // 確保只能刪除自己的任務
        guard task.userId == currentUserId else {
            throw ValidationError.unauthorized
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // 從 Firestore 刪除任務
            try await firebaseService.deleteTodoTask(task.id)
            
            // 從本地陣列中移除任務
            tasks.removeAll { $0.id == task.id }
            
            // 發送資料變更通知
            postDataChangeNotification()
            
            // 發送任務刪除通知（包含類別資訊）
            NotificationCenter.default.post(
                name: .taskDeleted,
                object: nil,
                userInfo: ["category": task.category, "taskId": task.id]
            )
        } catch {
            throw error
        }
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
            
            // 如果是重複任務，設定 repeatEndDate
            if updatedTask.repeatType != .none {
                updatedTask.repeatEndDate = newTaskRepeatEndDate
            }
            
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
    
    func toggleTaskCompletion(_ task: TodoTask) async {
        // 如果是重複任務，不應該直接切換主任務的完成狀態
        if task.repeatType != .none {
            return
        }
        
        // 1. 立即更新本地狀態
        var updatedTask = task
        updatedTask.isCompleted.toggle()
        
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = updatedTask
        }
        
        // 2. 將更新加入佇列
        completionUpdateQueue[task.id] = (updatedTask, 0)
        
        // 3. 如果沒有正在處理的更新，開始處理佇列
        if !isProcessingQueue {
            Task {
                await processCompletionQueue()
            }
        }
    }
    
    private func processCompletionQueue() async {
        guard !isProcessingQueue else { return }
        isProcessingQueue = true
        
        while !completionUpdateQueue.isEmpty {
            // 取得並移除第一個待更新的任務
            guard let (taskId, (task, retryCount)) = completionUpdateQueue.first else { break }
            completionUpdateQueue.removeValue(forKey: taskId)
            
            do {
                // 嘗試保存到 Firebase
                try await firebaseService.saveTodoTask(task)
                
                // 發送局部更新通知
                NotificationCenter.default.post(
                    name: .todoTaskDidUpdate,
                    object: nil,
                    userInfo: ["taskId": taskId, "isCompleted": task.isCompleted]
                )
            } catch {
                print("Error updating task completion: \(error)")
                
                // 如果失敗且重試次數未超過限制，重新加入佇列
                if retryCount < 3 {
                    completionUpdateQueue[taskId] = (task, retryCount + 1)
                } else {
                    // 超過重試次數，恢復本地狀態
                    if let index = tasks.firstIndex(where: { $0.id == taskId }) {
                        var originalTask = task
                        originalTask.isCompleted.toggle()
                        tasks[index] = originalTask
                    }
                    
                    // 通知用戶更新失敗
                    errorMessage = "更新任務狀態失敗，請稍後再試"
                }
            }
            
            // 短暫延遲，避免過於頻繁的請求
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        }
        
        isProcessingQueue = false
    }
    
    func updateTask(_ task: TodoTask) async throws {
        // 確保已經登入
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw ValidationError.notLoggedIn
        }
        
        // 保存原始任務狀態，用於錯誤恢復
        let originalTask = task
        
        do {
            // 確保任務有使用者 ID
            var updatedTask = task
            if updatedTask.userId.isEmpty {
                updatedTask.userId = currentUserId
            }
            
            // 在背景執行保存操作
            try await firebaseService.saveTodoTask(updatedTask)
            
            // 更新本地任務列表
            if let index = tasks.firstIndex(where: { $0.id == task.id }) {
                tasks[index] = updatedTask
            }
            
            // 發送資料變更通知
            NotificationCenter.default.post(name: .todoDataDidChange, object: nil)
        } catch {
            print("Error updating task: \(error)")
            // 如果更新失敗，恢復原始狀態
            if let index = tasks.firstIndex(where: { $0.id == task.id }) {
                tasks[index] = originalTask
            }
            throw error
        }
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
            return task1.startDate < task2.startDate
        }
    }
    
    // 按完成狀態和開始時間排序 - 未完成任務在前，已完成任務在後
    func sortedTasksWithCompletionStatus(by date: Date) -> [TodoTask] {
        let filteredTasks = tasksForDate(date)
        return filteredTasks.sorted { task1, task2 in
            if task1.isCompleted == task2.isCompleted {
                return task1.startDate < task2.startDate
            }
            return !task1.isCompleted && task2.isCompleted
        }
    }
    
    // 根據ID獲取任務
    func getTaskById(_ id: String) -> TodoTask? {
        return tasks.first { $0.id == id }
    }
    
    // MARK: - Task Instances
    
    func toggleInstanceCompletion(_ instance: TaskInstance, in task: TodoTask) async throws {
        // 1. 立即更新本地狀態
        if let taskIndex = tasks.firstIndex(where: { $0.id == task.id }),
           let instanceIndex = tasks[taskIndex].instances.firstIndex(where: { $0.id == instance.id }) {
            var updatedTask = tasks[taskIndex]
            var updatedInstance = instance
            updatedInstance.isCompleted.toggle()
            updatedTask.instances[instanceIndex] = updatedInstance
            
            // 不修改原始任務的 isCompleted 狀態
            tasks[taskIndex] = updatedTask
            
            do {
                // 2. 只更新實例的完成狀態
                try await firebaseService.updateTaskInstanceCompletion(
                    taskId: task.id,
                    instanceId: instance.id,
                    isCompleted: updatedInstance.isCompleted
                )
            } catch {
                // 3. 如果更新失敗，恢復本地狀態
                updatedInstance.isCompleted.toggle()
                updatedTask.instances[instanceIndex] = updatedInstance
                tasks[taskIndex] = updatedTask
                
                // 4. 拋出錯誤
                throw error
            }
        }
    }
    
    // 獲取特定日期的任務實例
    func getInstancesForDate(_ date: Date, task: TodoTask) -> [TaskInstance] {
        let calendar = Calendar.current
        return task.instances.filter { instance in
            calendar.isDate(instance.date, inSameDayAs: date)
        }
    }
    
    // 獲取所有未完成的任務實例
    func getIncompleteInstances(task: TodoTask) -> [TaskInstance] {
        return task.instances.filter { !$0.isCompleted }
    }
    
    // 獲取所有已完成的任務實例
    func getCompletedInstances(task: TodoTask) -> [TaskInstance] {
        return task.instances.filter { $0.isCompleted }
    }
    
    // 更新任務實例
    func updateInstance(_ instance: TaskInstance, in task: TodoTask) async throws {
        if let taskIndex = tasks.firstIndex(where: { $0.id == task.id }) {
            var updatedTask = tasks[taskIndex]
            if let instanceIndex = updatedTask.instances.firstIndex(where: { $0.id == instance.id }) {
                updatedTask.instances[instanceIndex] = instance
                
                // 只更新實例的完成狀態，不使用 updateTask
                try await firebaseService.updateTaskInstanceCompletion(
                    taskId: task.id,
                    instanceId: instance.id,
                    isCompleted: instance.isCompleted
                )
                
                // 更新本地狀態
                tasks[taskIndex] = updatedTask
            }
        }
    }
    
    // 刪除任務實例
    func deleteInstance(_ instance: TaskInstance, from task: TodoTask) async throws {
        if let taskIndex = tasks.firstIndex(where: { $0.id == task.id }) {
            var updatedTask = tasks[taskIndex]
            updatedTask.instances.removeAll { $0.id == instance.id }
            try await updateTask(updatedTask)
        }
    }
}

// 驗證錯誤
enum ValidationError: LocalizedError {
    case emptyTitle
    case notLoggedIn
    case unauthorized
    
    var errorDescription: String? {
        switch self {
        case .emptyTitle:
            return "任務標題不能為空"
        case .notLoggedIn:
            return "請先登入再操作任務"
        case .unauthorized:
            return "您沒有權限刪除此任務"
        }
    }
}

// 添加新的通知名稱
extension Notification.Name {
    static let todoTaskDidUpdate = Notification.Name("todoTaskDidUpdate")
}

