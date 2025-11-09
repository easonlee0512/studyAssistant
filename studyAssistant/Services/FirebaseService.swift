//
//  FirebaseSettingView.swift
//  studyAssistant
//
//  Created by 李翊辰 on 2025/5/1.
//
import Firebase
import FirebaseFirestore
import FirebaseAuth
import FirebaseFunctions
import SwiftUI

class FirebaseService: DataServiceProtocol {
    static let shared = FirebaseService()
    let db = Firestore.firestore()
    private let functions = Functions.functions(region: "asia-east1")
    private var lastSync: Date?
    private var currentSyncStatus: SyncStatus = .notSynced

    // MARK: - Collection Names
    private enum Collection: String {
        case tasks = "tasks"
        case profiles = "profiles"
        case settings = "settings"
    }

    // MARK: - Helper Methods
    /// 將包含 Timestamp 的字典轉換為可序列化的格式（使用 ISO 8601 字符串）
    private func convertTimestampsToStrings(_ data: [String: Any]) -> [String: Any] {
        var result = data
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        for (key, value) in data {
            if let timestamp = value as? Timestamp {
                result[key] = dateFormatter.string(from: timestamp.dateValue())
            } else if let dict = value as? [String: Any] {
                result[key] = convertTimestampsToStrings(dict)
            } else if let array = value as? [[String: Any]] {
                result[key] = array.map { convertTimestampsToStrings($0) }
            }
        }

        return result
    }

    /// 將 Cloud Functions 返回的日期數據轉換為 Timestamp 對象
    private func convertToTimestamps(_ data: [String: Any]) -> [String: Any] {
        var result = data

        for (key, value) in data {
            // 檢查是否是 Firestore Timestamp 的序列化格式 {_seconds: ..., _nanoseconds: ...}
            if let dict = value as? [String: Any],
               let seconds = dict["_seconds"] as? Int64 ?? dict["_seconds"] as? Int as? Int64,
               let nanoseconds = dict["_nanoseconds"] as? Int32 ?? dict["_nanoseconds"] as? Int as? Int32 {
                result[key] = Timestamp(seconds: seconds, nanoseconds: nanoseconds)
            }
            // 檢查是否是 ISO 8601 字符串
            else if let dateString = value as? String {
                let dateFormatter = ISO8601DateFormatter()
                dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let date = dateFormatter.date(from: dateString) {
                    result[key] = Timestamp(date: date)
                }
            }
            // 遞歸處理嵌套字典
            else if let dict = value as? [String: Any] {
                result[key] = convertToTimestamps(dict)
            }
            // 遞歸處理數組
            else if let array = value as? [[String: Any]] {
                result[key] = array.map { convertToTimestamps($0) }
            }
        }

        return result
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

        do {
            // 準備任務資料（使用現有的 toFirestore 方法）
            var taskData = task.toFirestore

            // 如果是重複任務且沒有結束日期，Cloud Functions 會自動設置為一年後
            // 這裡只需要傳遞 repeatEndDate（如果有的話）
            if task.repeatType != .none, let repeatEndDate = task.repeatEndDate {
                taskData["repeatEndDate"] = Timestamp(date: repeatEndDate)
            }

            // 轉換 Timestamp 為 ISO 8601 字符串以便序列化
            let convertedTaskData = convertTimestampsToStrings(taskData)

            // 調用 Cloud Functions 創建任務（實例將由服務端生成）
            let result = try await functions.httpsCallable("createTask").call([
                "task": convertedTaskData
            ])

            guard let data = result.data as? [String: Any],
                  let success = data["success"] as? Bool,
                  success else {
                let errorMsg = (result.data as? [String: Any])?["error"] as? String ?? "未知錯誤"
                throw NSError(domain: "FirebaseServiceErrorDomain", code: -1,
                             userInfo: [NSLocalizedDescriptionKey: "創建任務失敗: \(errorMsg)"])
            }

            lastSync = Date()
            currentSyncStatus = .synced
        } catch {
            currentSyncStatus = .error(.networkError)
            throw error
        }
    }
    
    func fetchTodoTasks() async throws -> [TodoTask] {
        currentSyncStatus = .syncing

        do {
            // 調用 Cloud Functions 獲取任務（包含實例）
            let result = try await functions.httpsCallable("fetchTasks").call()

            guard let data = result.data as? [String: Any],
                  let success = data["success"] as? Bool,
                  success,
                  let tasksData = data["tasks"] as? [[String: Any]] else {
                throw NSError(domain: "FirebaseServiceErrorDomain", code: -1,
                             userInfo: [NSLocalizedDescriptionKey: "獲取任務失敗"])
            }

            var tasks: [TodoTask] = []

            for taskData in tasksData {
                // 轉換日期數據為 Timestamp 格式
                let convertedTaskData = convertToTimestamps(taskData)

                if var task = TodoTask(documentId: convertedTaskData["id"] as? String ?? "", data: convertedTaskData) {
                    // 解析實例數據
                    if let instancesData = convertedTaskData["instances"] as? [[String: Any]] {
                        var instances: [TaskInstance] = []
                        for instanceData in instancesData {
                            let convertedInstanceData = convertToTimestamps(instanceData)
                            if let instance = TaskInstance(documentId: convertedInstanceData["id"] as? String ?? "", data: convertedInstanceData) {
                                instances.append(instance)
                            }
                        }
                        task.instances = instances
                    }
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
            // 調用 Cloud Functions 刪除任務（包含所有實例）
            let result = try await functions.httpsCallable("deleteTask").call([
                "taskId": taskId
            ])

            guard let data = result.data as? [String: Any],
                  let success = data["success"] as? Bool,
                  success else {
                throw NSError(domain: "FirebaseServiceErrorDomain", code: -1,
                             userInfo: [NSLocalizedDescriptionKey: "刪除任務失敗"])
            }

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
            // 調用 Cloud Functions 更新實例狀態
            let result = try await functions.httpsCallable("updateTaskInstance").call([
                "taskId": taskId,
                "instanceId": instanceId,
                "isCompleted": isCompleted
            ])

            guard let data = result.data as? [String: Any],
                  let success = data["success"] as? Bool,
                  success else {
                throw NSError(domain: "FirebaseServiceErrorDomain", code: -1,
                             userInfo: [NSLocalizedDescriptionKey: "更新任務實例失敗"])
            }

            lastSync = Date()
            currentSyncStatus = .synced
        } catch {
            currentSyncStatus = .error(.networkError)
            throw error
        }
    }

    // 切換非重複任務的完成狀態
    func toggleTaskCompletion(taskId: String, isCompleted: Bool) async throws {
        currentSyncStatus = .syncing

        do {
            // 調用 Cloud Functions 切換任務完成狀態
            let result = try await functions.httpsCallable("toggleTaskCompletion").call([
                "taskId": taskId,
                "isCompleted": isCompleted
            ])

            guard let data = result.data as? [String: Any],
                  let success = data["success"] as? Bool,
                  success else {
                throw NSError(domain: "FirebaseServiceErrorDomain", code: -1,
                             userInfo: [NSLocalizedDescriptionKey: "更新任務完成狀態失敗"])
            }

            lastSync = Date()
            currentSyncStatus = .synced
        } catch {
            currentSyncStatus = .error(.networkError)
            throw error
        }
    }
    
    // MARK: - Private Data Access
    private func saveUserProfile(_ profile: UserProfile) async throws {
        // 轉換 Timestamp 為 ISO 8601 字符串
        let convertedProfile = convertTimestampsToStrings(profile.toFirestore)

        // 調用 Cloud Functions 更新用戶資料
        let result = try await functions.httpsCallable("updateUserProfile").call([
            "profile": convertedProfile
        ])

        guard let data = result.data as? [String: Any],
              let success = data["success"] as? Bool,
              success else {
            throw NSError(domain: "FirebaseServiceErrorDomain", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "更新用戶資料失敗"])
        }
    }

    private func fetchUserProfile(userId: String) async throws -> UserProfile? {
        // 調用 Cloud Functions 獲取用戶資料
        let result = try await functions.httpsCallable("getUserProfile").call()

        guard let data = result.data as? [String: Any],
              let success = data["success"] as? Bool,
              success else {
            return nil
        }

        guard let profileData = data["profile"] as? [String: Any] else {
            return nil
        }

        // 轉換日期數據為 Timestamp 格式
        let convertedProfileData = convertToTimestamps(profileData)

        return UserProfile(documentId: convertedProfileData["id"] as? String ?? userId, data: convertedProfileData)
    }
    
    private func saveSettings(_ settings: AppSettings, userId: String) async throws {
        // 轉換 Timestamp 為 ISO 8601 字符串
        let convertedSettings = convertTimestampsToStrings(settings.toFirestore)

        // 調用 Cloud Functions 更新應用設定
        let result = try await functions.httpsCallable("updateAppSettings").call([
            "settings": convertedSettings
        ])

        guard let data = result.data as? [String: Any],
              let success = data["success"] as? Bool,
              success else {
            throw NSError(domain: "FirebaseServiceErrorDomain", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "更新應用設定失敗"])
        }
    }

    private func fetchSettings(userId: String) async throws -> AppSettings? {
        // 調用 Cloud Functions 獲取應用設定
        let result = try await functions.httpsCallable("getAppSettings").call()

        guard let data = result.data as? [String: Any],
              let success = data["success"] as? Bool,
              success else {
            return nil
        }

        guard let settingsData = data["settings"] as? [String: Any] else {
            return nil
        }

        // 轉換日期數據為 Timestamp 格式
        let convertedSettingsData = convertToTimestamps(settingsData)

        return AppSettings(documentId: convertedSettingsData["id"] as? String ?? userId, data: convertedSettingsData)
    }
    
}
 
