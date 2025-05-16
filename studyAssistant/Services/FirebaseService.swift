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
                let userId = self.getCurrentUserId()
                
                // 創建一個包含當前使用者ID的任務副本
                var updatedTask = task
                updatedTask.userId = userId
                
                // 將任務存儲在使用者ID下
                let taskRef = self.db.collection(Collection.tasks.rawValue)
                                   .document(userId)
                                   .collection("userTasks")
                                   .document(task.id)
                
                // 如果只是更新完成狀態，則只更新相關欄位
                if let existingData = try? await taskRef.getDocument().data(),
                   let existingTask = TodoTask(documentId: task.id, data: existingData),
                   existingTask.isCompleted != task.isCompleted &&
                   existingTask.title == task.title &&
                   existingTask.note == task.note &&
                   existingTask.startDate == task.startDate &&
                   existingTask.endDate == task.endDate {
                    
                    // 只更新完成狀態和更新時間
                    batch.updateData([
                        "isCompleted": task.isCompleted,
                        "updatedAt": Timestamp(date: Date())
                    ], forDocument: taskRef)
                } else {
                    // 完整更新
                    batch.setData(updatedTask.toFirestore, forDocument: taskRef)
                    
                    // 如果是重複性任務，建立子任務
                    if task.repeatType != .none {
                        let subTasksRef = taskRef.collection("instances")
                        let nextOccurrences = self.calculateNextOccurrences(for: task, limit: 5)
                        
                        for date in nextOccurrences {
                            let instanceRef = subTasksRef.document()
                            batch.setData([
                                "date": Timestamp(date: date),
                                "isCompleted": false,
                                "parentTaskId": task.id
                            ], forDocument: instanceRef)
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
    
    func fetchTodoTasks() async throws -> [TodoTask] {
        currentSyncStatus = .syncing
        do {
            let userId = getCurrentUserId()
            let snapshot = try await db.collection(Collection.tasks.rawValue)
                                      .document(userId)
                                      .collection("userTasks")
                                      .order(by: "createdAt", descending: true)
                                      .getDocuments()
            
            lastSync = Date()
            currentSyncStatus = .synced
            
            return snapshot.documents.compactMap { document in
                TodoTask(documentId: document.documentID, data: document.data())
            }
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
    
    // MARK: - Private Helpers
    private func calculateNextOccurrences(for task: TodoTask, limit: Int) -> [Date] {
        var occurrences: [Date] = []
        let calendar = Calendar.current
        var currentDate = task.startDate
        
        while occurrences.count < limit {
            switch task.repeatType {
            case .daily:
                if let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) {
                    occurrences.append(nextDate)
                    currentDate = nextDate
                }
                
            case .weekly:
                // 使用創建時的星期幾
                let weekday = calendar.component(.weekday, from: task.startDate)
                    if let nextDate = calendar.nextDate(after: currentDate,
                                                  matching: DateComponents(weekday: weekday),
                                                      matchingPolicy: .nextTime) {
                        occurrences.append(nextDate)
                        currentDate = nextDate
                }
                
            case .monthly:
                // 使用創建時的日期
                let dayOfMonth = calendar.component(.day, from: task.startDate)
                    if let nextDate = calendar.nextDate(after: currentDate,
                                                  matching: DateComponents(day: dayOfMonth),
                                                      matchingPolicy: .nextTime) {
                        occurrences.append(nextDate)
                        currentDate = nextDate
                }
                
            case .none:
                return []
            }
        }
        
        return Array(occurrences.prefix(limit))
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
 
