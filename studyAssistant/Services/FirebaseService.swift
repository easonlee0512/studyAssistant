//
//  FirebaseSettingView.swift
//  studyAssistant
//
//  Created by 李翊辰 on 2025/5/1.
//
import Firebase
import FirebaseFirestore
import FirebaseAuth
import SwiftUI

class FirebaseService: DataServiceProtocol {
    static let shared = FirebaseService()
    let db = Firestore.firestore()
    private var lastSync: Date?
    private var currentSyncStatus: SyncStatus = .notSynced
    
    // MARK: - Collection Names
    private enum Collection: String {
        case tasks = "tasks"
        case profiles = "profiles"
        case settings = "settings"
    }
    
    // 獲取當前使用者ID，如果未登入則回傳預設值
    private func getCurrentUserId() -> String {
        if let user = Auth.auth().currentUser {
            return user.uid
        }
        return "default"
    }
    
    // MARK: - DataServiceProtocol
    func fetchUserProfile() async throws -> UserProfile {
        let userId = getCurrentUserId()
        
        if let profile = try await fetchUserProfile(userId: userId) {
            return profile
        }
        
        // 如果找不到現有檔案，為當前使用者創建一個新的空白檔案
        var newProfile = UserProfile.defaultProfile()
        newProfile.id = userId
        if let email = Auth.auth().currentUser?.email {
            newProfile.email = email
        }
        try await saveUserProfile(newProfile)
        return newProfile
    }
    
    func updateUserProfile(_ profile: UserProfile) async throws {
        try await saveUserProfile(profile)
    }
    
    func fetchAppSettings() async throws -> AppSettings {
        let userId = getCurrentUserId()
        
        if let settings = try await fetchSettings(userId: userId) {
            return settings
        }
        
        // 如果找不到現有設定，為當前使用者創建一個新的預設設定
        let newSettings = AppSettings.defaultSettings()
        try await saveSettings(newSettings, userId: userId)
        return newSettings
    }
    
    func updateAppSettings(_ settings: AppSettings) async throws {
        let userId = getCurrentUserId()
        try await saveSettings(settings, userId: userId)
    }
    
    func syncStatus() -> SyncStatus {
        return currentSyncStatus
    }
    
    func lastSyncTime() -> Date? {
        return lastSync
    }
    
    // MARK: - Todo Tasks
    func saveTodoTask(_ task: TodoTask) async throws {
        currentSyncStatus = .syncing
        
        // 使用 Task 添加超時機制
        return try await withTimeout(seconds: 10) {
            do {
                let batch = self.db.batch()
                let userId = task.userId.isEmpty ? self.getCurrentUserId() : task.userId
                
                // 建立任務文件參考
                let taskRef = self.db.collection(Collection.tasks.rawValue)
                    .document(userId)
                    .collection("userTasks")
                    .document(task.id)
                
                // 轉換任務資料
                var taskData = task.toFirestore
                
                // 如果是重複任務且有結束日期，加入結束日期
                if task.repeatType != .none {
                    if let repeatEndDate = task.repeatEndDate {
                        taskData["repeatEndDate"] = Timestamp(date: repeatEndDate)
                    } else {
                        // 如果沒有設定結束日期，預設為一年後
                        let oneYearLater = Calendar.current.date(byAdding: .year, value: 1, to: task.startDate) ?? task.startDate
                        taskData["repeatEndDate"] = Timestamp(date: oneYearLater)
                    }
                } else {
                    // 如果不是重複任務，確保移除 repeatEndDate
                    taskData["repeatEndDate"] = nil
                }
                
                // 設置任務資料
                batch.setData(taskData, forDocument: taskRef)
                
                // 檢查是否需要重新生成實例
                let needsRegenerateInstances = await self.needsRegenerateInstances(taskRef: taskRef, newTask: task)
                
                if needsRegenerateInstances {
                    // 處理任務實例
                    let subTasksRef = taskRef.collection("instances")
                    
                    // 先獲取所有現有的實例
                    var completedInstanceDates: [Date] = []
                    var completedInstances: [QueryDocumentSnapshot] = []
                    var incompletedInstances: [QueryDocumentSnapshot] = []
                    
                    if let existingInstances = try? await subTasksRef.getDocuments() {
                        for instance in existingInstances.documents {
                            let data = instance.data()
                            let isCompleted = data["isCompleted"] as? Bool ?? false
                            
                            if isCompleted {
                                // 保存已完成實例的日期
                                if let timestamp = data["date"] as? Timestamp {
                                    completedInstanceDates.append(timestamp.dateValue())
                                }
                                completedInstances.append(instance)
                            } else {
                                incompletedInstances.append(instance)
                            }
                        }
                    }
                    
                    // 只刪除未完成的實例
                    for instance in incompletedInstances {
                        batch.deleteDocument(instance.reference)
                    }
                    
                    // 如果是重複性任務，生成新的實例
                    if task.repeatType != .none {
                        let nextOccurrences = self.calculateNextOccurrences(for: task, limit: 100)
                        
                        for date in nextOccurrences {
                            // 檢查這個日期是否已經有完成的實例
                            let isDateCompleted = completedInstanceDates.contains { completedDate in
                                Calendar.current.isDate(date, inSameDayAs: completedDate)
                            }
                            
                            // 只為未完成的日期生成新實例
                            if !isDateCompleted {
                                let instanceRef = subTasksRef.document()
                                let instanceData: [String: Any] = [
                                    "date": Timestamp(date: date),
                                    "isCompleted": false,
                                    "parentTaskId": task.id
                                ]
                                batch.setData(instanceData, forDocument: instanceRef)
                            }
                        }
                    }
                }
                
                try await batch.commit()
                self.lastSync = Date()
                self.currentSyncStatus = .synced
            } catch {
                self.currentSyncStatus = .error(.networkError)
                print("Firebase error: \(error.localizedDescription)")
                throw error
            }
        }
    }
    
    // 檢查是否需要重新生成實例
    private func needsRegenerateInstances(taskRef: DocumentReference, newTask: TodoTask) async -> Bool {
        do {
            // 獲取現有任務資料
            let doc = try await taskRef.getDocument()
            guard let oldData = doc.data() else { return true }  // 如果沒有現有資料，需要生成實例
            
            // 檢查重複類型是否改變
            let oldRepeatType = oldData["repeatType"] as? [String: Any]
            let oldRepeatTypeStr = oldRepeatType?["type"] as? String ?? "none"
            let newRepeatTypeStr: String
            switch newTask.repeatType {
            case .none: newRepeatTypeStr = "none"
            case .daily: newRepeatTypeStr = "daily"
            case .weekly: newRepeatTypeStr = "weekly"
            case .monthly: newRepeatTypeStr = "monthly"
            }
            if oldRepeatTypeStr != newRepeatTypeStr { return true }
            
            // 檢查開始時間是否改變
            let oldStartDate = (oldData["startDate"] as? Timestamp)?.dateValue()
            if oldStartDate != newTask.startDate { return true }
            
            // 檢查結束時間是否改變
            let oldEndDate = (oldData["endDate"] as? Timestamp)?.dateValue()
            if oldEndDate != newTask.endDate { return true }
            
            // 檢查重複結束時間是否改變
            let oldRepeatEndDate = (oldData["repeatEndDate"] as? Timestamp)?.dateValue()
            if oldRepeatEndDate != newTask.repeatEndDate { return true }
            
            return false  // 如果以上都沒有改變，不需要重新生成實例
        } catch {
            print("Error checking task changes: \(error)")
            return true  // 如果出錯，為安全起見重新生成實例
        }
    }
    
    func fetchTodoTasks() async throws -> [TodoTask] {
        currentSyncStatus = .syncing
        do {
            let userId = getCurrentUserId()
            let snapshot = try await db.collection(Collection.tasks.rawValue)
                                      .document(userId)
                                      .collection("userTasks")
                                      .order(by: "createdAt", descending: true)
                                      .getDocuments()
            
            var tasks: [TodoTask] = []
            
            for document in snapshot.documents {
                if var task = TodoTask(documentId: document.documentID, data: document.data()) {
                    // 獲取任務的實例
                    let instancesSnapshot = try await document.reference.collection("instances").getDocuments()
                    var instances: [TaskInstance] = []
                    
                    for instanceDoc in instancesSnapshot.documents {
                        if let instance = TaskInstance(documentId: instanceDoc.documentID, data: instanceDoc.data()) {
                            instances.append(instance)
                        }
                    }
                    
                    task.instances = instances
                    tasks.append(task)
                }
            }
            
            lastSync = Date()
            currentSyncStatus = .synced
            
            return tasks
        } catch {
            currentSyncStatus = .error(.networkError)
            throw error
        }
    }
    
    func deleteTodoTask(_ taskId: String) async throws {
        currentSyncStatus = .syncing
        do {
            let batch = db.batch()
            let userId = getCurrentUserId()
            
            // 刪除主任務
            let taskRef = db.collection(Collection.tasks.rawValue)
                           .document(userId)
                           .collection("userTasks")
                           .document(taskId)
            
            batch.deleteDocument(taskRef)
            
            // 刪除所有子任務
            let subTasksSnapshot = try await taskRef.collection("instances").getDocuments()
            for document in subTasksSnapshot.documents {
                batch.deleteDocument(document.reference)
            }
            
            try await batch.commit()
            lastSync = Date()
            currentSyncStatus = .synced
        } catch {
            currentSyncStatus = .error(.networkError)
            throw error
        }
    }
    
    // MARK: - Task Instance Operations
    func updateTaskInstanceCompletion(taskId: String, instanceId: String, isCompleted: Bool) async throws {
        currentSyncStatus = .syncing
        
        do {
            let userId = getCurrentUserId()
            let instanceRef = db.collection(Collection.tasks.rawValue)
                .document(userId)
                .collection("userTasks")
                .document(taskId)
                .collection("instances")
                .document(instanceId)
            
            // 只更新實例的完成狀態
            try await instanceRef.updateData([
                "isCompleted": isCompleted
            ])
            
            lastSync = Date()
            currentSyncStatus = .synced
        } catch {
            currentSyncStatus = .error(.networkError)
            throw error
        }
    }
    
    // MARK: - Private Helpers
    private func calculateNextOccurrences(for task: TodoTask, limit: Int) -> [Date] {
        var occurrences: [Date] = []
        let calendar = Calendar.current
        
        // 確保不超過結束日期
        let endDate = task.repeatEndDate ?? calendar.date(byAdding: .year, value: 1, to: task.startDate) ?? task.startDate
        
        // 先加入開始日期（當天）
        occurrences.append(task.startDate)
        
        // 從開始日期開始計算下一個日期
        var currentDate = task.startDate
        
        while occurrences.count < limit {
            // 檢查是否已超過結束日期
            if currentDate > endDate {
                break
            }
            
            switch task.repeatType {
            case .daily:
                if let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) {
                    // 檢查是否超過結束日期
                    if nextDate <= endDate {
                        occurrences.append(nextDate)
                    }
                    currentDate = nextDate
                }
                
            case .weekly:
                // 使用創建時的星期幾
                let weekday = calendar.component(.weekday, from: task.startDate)
                if let nextDate = calendar.nextDate(
                    after: currentDate,
                    matching: DateComponents(weekday: weekday),
                    matchingPolicy: .nextTime
                ) {
                    // 檢查是否超過結束日期
                    if nextDate <= endDate {
                        occurrences.append(nextDate)
                    }
                    currentDate = nextDate
                }
                
            case .monthly:
                // 使用創建時的日期
                let dayOfMonth = calendar.component(.day, from: task.startDate)
                if let nextDate = calendar.nextDate(
                    after: currentDate,
                    matching: DateComponents(day: dayOfMonth),
                    matchingPolicy: .nextTime
                ) {
                    // 檢查是否超過結束日期
                    if nextDate <= endDate {
                        occurrences.append(nextDate)
                    }
                    currentDate = nextDate
                }
                
            case .none:
                return []
            }
            
            // 如果下一個日期超過結束日期，就停止
            if currentDate > endDate {
                break
            }
        }
        
        return occurrences
    }
    
    // MARK: - Private Data Access
    private func saveUserProfile(_ profile: UserProfile) async throws {
        // 確保使用者個人檔案使用當前登入的使用者ID
        var updatedProfile = profile
        updatedProfile.id = getCurrentUserId()
        
        try await db.collection(Collection.profiles.rawValue)
            .document(updatedProfile.id)
            .setData(updatedProfile.toFirestore, merge: true)
    }
    
    private func fetchUserProfile(userId: String) async throws -> UserProfile? {
        let doc = try await db.collection(Collection.profiles.rawValue)
            .document(userId)
            .getDocument()
        return doc.exists ? UserProfile(documentId: doc.documentID, data: doc.data() ?? [:]) : nil
    }
    
    private func saveSettings(_ settings: AppSettings, userId: String) async throws {
        try await db.collection(Collection.settings.rawValue)
            .document(userId)
            .setData(settings.toFirestore, merge: true)
    }
    
    private func fetchSettings(userId: String) async throws -> AppSettings? {
        let doc = try await db.collection(Collection.settings.rawValue)
            .document(userId)
            .getDocument()
        return doc.exists ? AppSettings(documentId: doc.documentID, data: doc.data() ?? [:]) : nil
    }
    
    // 添加超時功能的輔助方法
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            // 添加實際操作任務
            group.addTask {
                try await operation()
            }
            
            // 添加超時任務
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw NSError(domain: "FirebaseServiceErrorDomain", code: -1, 
                             userInfo: [NSLocalizedDescriptionKey: "操作超時，請稍後再試。"])
            }
            
            // 返回第一個完成的任務結果（操作成功或超時）
            let result = try await group.next()!
            group.cancelAll() // 取消所有剩餘任務
            return result
        }
    }
    
    // MARK: - 數據遷移
    // 添加一個標記來記錄是否已經遷移過
    private static var hasMigrationAttempted = false
    
    func migrateTasksToUserCollection() async throws {
        // 如果已經嘗試過遷移，則直接返回
        if FirebaseService.hasMigrationAttempted {
            return
        }
        
        FirebaseService.hasMigrationAttempted = true
        let userId = getCurrentUserId()
        
        // 只在開發模式下輸出日誌
        #if DEBUG
        print("開始遷移任務數據到用戶集合，用戶ID：\(userId)")
        #endif
        
        // 獲取所有屬於當前用戶ID的舊任務
        let oldTasksSnapshot = try await db.collection(Collection.tasks.rawValue)
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        
        if oldTasksSnapshot.documents.isEmpty {
            // 只在開發模式下輸出日誌
            #if DEBUG
            print("沒有找到需要遷移的任務")
            #endif
            return
        }
        
        // 只在開發模式下輸出日誌
        #if DEBUG
        print("找到 \(oldTasksSnapshot.documents.count) 個需要遷移的任務")
        #endif
        
        // 創建批量操作
        let batch = db.batch()
        
        // 遷移每個任務
        for document in oldTasksSnapshot.documents {
            let taskId = document.documentID
            let taskData = document.data()
            
            // 新的任務引用
            let newTaskRef = db.collection(Collection.tasks.rawValue)
                               .document(userId)
                               .collection("userTasks")
                               .document(taskId)
            
            // 寫入新位置
            batch.setData(taskData, forDocument: newTaskRef)
            
            // 刪除舊任務
            let oldTaskRef = db.collection(Collection.tasks.rawValue).document(taskId)
            batch.deleteDocument(oldTaskRef)
            
            // 檢查是否有子任務需要遷移
            let instancesSnapshot = try await oldTaskRef.collection("instances").getDocuments()
            
            for instanceDoc in instancesSnapshot.documents {
                let instanceId = instanceDoc.documentID
                let instanceData = instanceDoc.data()
                
                // 新的子任務引用
                let newInstanceRef = newTaskRef.collection("instances").document(instanceId)
                
                // 寫入新位置
                batch.setData(instanceData, forDocument: newInstanceRef)
                
                // 刪除舊子任務
                batch.deleteDocument(oldTaskRef.collection("instances").document(instanceId))
            }
        }
        
        // 提交批量操作
        try await batch.commit()
        
        // 只在開發模式下輸出日誌
        #if DEBUG
        print("任務遷移完成")
        #endif
    }
}
 
