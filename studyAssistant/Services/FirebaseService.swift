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
    private let db = Firestore.firestore()
    private var lastSync: Date?
    private var currentSyncStatus: SyncStatus = .notSynced
    
    // MARK: - Collection Names
    private enum Collection: String {
        case tasks = "tasks"
        case timerRecords = "timerRecords"
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
                
                // 創建一個包含當前使用者ID的任務副本
                var updatedTask = task
                updatedTask.userId = self.getCurrentUserId()
                
                let taskRef = self.db.collection(Collection.tasks.rawValue).document(task.id)
                
                // 儲存任務資料
                batch.setData(updatedTask.toFirestore, forDocument: taskRef)
                
                // 如果是重複性任務，建立子任務 (限制子任務數量以避免過長處理時間)
                if task.repeatType != .none {
                    let subTasksRef = taskRef.collection("instances")
                    let nextOccurrences = self.calculateNextOccurrences(for: task, limit: 5) // 從10減少到5
                    
                    for date in nextOccurrences {
                        let instanceRef = subTasksRef.document()
                        batch.setData([
                            "date": Timestamp(date: date),
                            "isCompleted": false,
                            "parentTaskId": task.id
                        ], forDocument: instanceRef)
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
            let snapshot = try await db.collection(Collection.tasks.rawValue)
                .whereField("userId", isEqualTo: getCurrentUserId())
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
            
            // 刪除主任務
            let taskRef = db.collection(Collection.tasks.rawValue).document(taskId)
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
    
    // MARK: - Timer Records
    func saveTimerRecord(_ record: TimerRecord) async throws {
        var updatedRecord = record
        updatedRecord.userId = getCurrentUserId()
        
        let recordRef = db.collection(Collection.timerRecords.rawValue).document(record.id)
        try await recordRef.setData(updatedRecord.toFirestore, merge: true)
    }
    
    func getTimerRecords(userId: String) async throws -> [TimerRecord] {
        let snapshot = try await db.collection(Collection.timerRecords.rawValue)
            .whereField("userId", isEqualTo: userId)
            .whereField("isDeleted", isEqualTo: false)
            .order(by: "startTime", descending: true)
            .getDocuments()
            
        return snapshot.documents.compactMap { document in
            TimerRecord(documentId: document.documentID, data: document.data())
        }
    }
    
    func getTimerStatistics(userId: String) async throws -> TimerStatistics {
        let records = try await getTimerRecords(userId: userId)
        return TimerStatistics.calculate(from: records)
    }
    
    func getTimerStatistics(userId: String, from: Date, to: Date) async throws -> TimerStatistics {
        let snapshot = try await db.collection(Collection.timerRecords.rawValue)
            .whereField("userId", isEqualTo: userId)
            .whereField("isDeleted", isEqualTo: false)
            .whereField("startTime", isGreaterThanOrEqualTo: Timestamp(date: from))
            .whereField("startTime", isLessThanOrEqualTo: Timestamp(date: to))
            .order(by: "startTime", descending: true)
            .getDocuments()
            
        let records = snapshot.documents.compactMap { document in
            TimerRecord(documentId: document.documentID, data: document.data())
        }
        
        return TimerStatistics.calculate(from: records)
    }
    
    // MARK: - Private Timer Helpers
    private func calculateTimerStatistics(userId: String? = nil, from: Date? = nil, to: Date? = nil) async throws -> TimerStatistics {
        let currentUserId = userId ?? getCurrentUserId()
        
        var query = db.collection(Collection.timerRecords.rawValue)
            .whereField("userId", isEqualTo: currentUserId)
        
        if let fromDate = from {
            query = query.whereField("startTime", isGreaterThanOrEqualTo: Timestamp(date: fromDate))
        }
        if let toDate = to {
            query = query.whereField("startTime", isLessThanOrEqualTo: Timestamp(date: toDate))
        }
        
        let snapshot = try await query.getDocuments()
        var statistics = TimerStatistics()
        
        for document in snapshot.documents {
            let data = document.data()
            guard let startTime = (data["startTime"] as? Timestamp)?.dateValue(),
                  let endTime = (data["endTime"] as? Timestamp)?.dateValue(),
                  let isCompleted = data["isCompleted"] as? Bool else {
                continue
            }
            
            let duration = endTime.timeIntervalSince(startTime)
            statistics.totalTime += duration
            
            if isCompleted {
                statistics.completedSessions += 1
            } else {
                statistics.incompleteSessions += 1
            }
        }
        
        let totalSessions = statistics.completedSessions + statistics.incompleteSessions
        if totalSessions > 0 {
            statistics.averageSessionTime = statistics.totalTime / Double(totalSessions)
        }
        
        return statistics
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
                
            case .weekly(let days):
                for weekday in days {
                    if let nextDate = calendar.nextDate(after: currentDate,
                                                      matching: DateComponents(weekday: weekday + 1),
                                                      matchingPolicy: .nextTime) {
                        occurrences.append(nextDate)
                        currentDate = nextDate
                    }
                }
                
            case .monthly(let days):
                for day in days {
                    if let nextDate = calendar.nextDate(after: currentDate,
                                                      matching: DateComponents(day: day),
                                                      matchingPolicy: .nextTime) {
                        occurrences.append(nextDate)
                        currentDate = nextDate
                    }
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
}
 
