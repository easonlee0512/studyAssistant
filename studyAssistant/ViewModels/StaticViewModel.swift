//
//  StaticViewModel.swift
//  studyAssistant
//
//  Created by 李翊辰 on 2025/5/7.
//

import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseFunctions
import FirebaseAuth

@MainActor
class StaticViewModel: ObservableObject {
    @Published var statistics: [LearningStatistic] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    @Published var tokenUsage = TokenUsageStats()

    private let db = Firestore.firestore()
    private let functions = Functions.functions(region: "asia-east1")

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
    
    // 初始化並設置監聽器
    init() {
        setupAuthListener()
        setupNotificationObserver()
    }
    
    // 設置驗證狀態監聽
    private func setupAuthListener() {
        Auth.auth().addStateDidChangeListener { [weak self] (auth, user) in
            if user != nil {
                // 使用者登入，載入數據
                Task {
                    await self?.fetchStatistics()
                    await self?.fetchTokenUsageStats()
                }
            } else {
                // 使用者登出，清空數據
                self?.statistics = []
                self?.tokenUsage = TokenUsageStats()
            }
        }
    }
    
    // 設置通知監聽
    private func setupNotificationObserver() {
        // 監聽任務刪除通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTaskDeleted),
            name: .taskDeleted,
            object: nil
        )
    }
    
    // 處理任務刪除通知
    @objc private func handleTaskDeleted(_ notification: Notification) {
        guard let category = notification.userInfo?["category"] as? String else { return }

        // 忽略空類別
        if category.isEmpty { return }
        
        Task {
            // 檢查該類別是否還有其它任務
            let todoViewModel = TodoViewModel()
            let remainingTasks = todoViewModel.tasksForCategory(category)
            
            if remainingTasks.isEmpty {
                // 如果沒有剩餘任務，刪除該統計類別
                if let statistic = statistics.first(where: { $0.category == category }),
                   let statisticId = statistic.id {
                    await deleteStatistic(statisticId)
                }
            } else {
                // 更新該類別的任務計數
                let completedTasksCount = remainingTasks.filter { $0.isCompleted }.count
                await updateCategoryTaskStats(
                    category: category,
                    completedCount: completedTasksCount,
                    totalCount: remainingTasks.count
                )
            }
        }
    }
    
    // 從Cloud Functions獲取統計數據
    func fetchStatistics() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            self.statistics = []
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            print("[StaticViewModel] 開始獲取統計數據，用戶ID: \(userId)")

            // 調用 Cloud Functions 獲取統計數據
            let result = try await functions.httpsCallable("fetchStatistics").call()

            print("[StaticViewModel] 收到 Cloud Function 回應: \(result.data)")

            guard let data = result.data as? [String: Any] else {
                print("[StaticViewModel] 錯誤: 無法解析回應數據為字典")
                throw NSError(domain: "StaticViewModelErrorDomain", code: -1,
                             userInfo: [NSLocalizedDescriptionKey: "無法解析回應數據"])
            }

            print("[StaticViewModel] 回應數據鍵: \(data.keys)")

            guard let success = data["success"] as? Bool else {
                print("[StaticViewModel] 錯誤: 回應中沒有 success 字段")
                let errorMsg = data["error"] as? String ?? "未知錯誤"
                throw NSError(domain: "StaticViewModelErrorDomain", code: -1,
                             userInfo: [NSLocalizedDescriptionKey: "獲取統計數據失敗: \(errorMsg)"])
            }

            print("[StaticViewModel] success 狀態: \(success)")

            guard success else {
                let errorMsg = data["error"] as? String ?? "未知錯誤"
                print("[StaticViewModel] 錯誤: Cloud Function 返回失敗: \(errorMsg)")
                throw NSError(domain: "StaticViewModelErrorDomain", code: -1,
                             userInfo: [NSLocalizedDescriptionKey: "獲取統計數據失敗: \(errorMsg)"])
            }

            guard let statsData = data["statistics"] as? [[String: Any]] else {
                print("[StaticViewModel] 錯誤: 無法解析 statistics 數據")
                throw NSError(domain: "StaticViewModelErrorDomain", code: -1,
                             userInfo: [NSLocalizedDescriptionKey: "無法解析統計數據"])
            }

            print("[StaticViewModel] 成功獲取 \(statsData.count) 條統計數據")

            var newStatistics: [LearningStatistic] = []

            for statData in statsData {
                // 轉換日期數據為 Timestamp 格式
                let convertedStatData = convertToTimestamps(statData)

                let id = convertedStatData["id"] as? String ?? ""
                let userId = convertedStatData["userId"] as? String ?? ""
                let category = convertedStatData["category"] as? String ?? ""
                let progress = convertedStatData["progress"] as? Double ?? 0.0
                let taskcount = convertedStatData["taskcount"] as? Int ?? 0
                let taskcompletecount = convertedStatData["taskcompletecount"] as? Int ?? 0
                let totalFocusTime = convertedStatData["totalFocusTime"] as? Int ?? 0
                let version = convertedStatData["version"] as? Int ?? 1

                let dateTimestamp = convertedStatData["date"] as? Timestamp
                let date = dateTimestamp?.dateValue() ?? Date()

                let updatedAtTimestamp = convertedStatData["updatedAt"] as? Timestamp
                let updatedAt = updatedAtTimestamp?.dateValue() ?? Date()

                let statistic = LearningStatistic(
                    id: id,
                    userId: userId,
                    category: category,
                    progress: progress,
                    taskcount: taskcount,
                    taskcompletecount: taskcompletecount,
                    totalFocusTime: totalFocusTime,
                    date: date,
                    updatedAt: updatedAt,
                    version: version
                )

                newStatistics.append(statistic)
            }

            self.statistics = newStatistics
            self.isLoading = false

            // 獲取Token使用量
            await fetchTokenUsageStats()
        } catch {
            self.errorMessage = "載入統計數據失敗: \(error.localizedDescription)"
            self.isLoading = false
            print("[StaticViewModel] Error fetching statistics: \(error)")

            // 獲取更詳細的錯誤信息
            if let functionsError = error as NSError? {
                print("[StaticViewModel] Error domain: \(functionsError.domain)")
                print("[StaticViewModel] Error code: \(functionsError.code)")
                print("[StaticViewModel] Error userInfo: \(functionsError.userInfo)")

                // 檢查是否有底層錯誤
                if let underlyingError = functionsError.userInfo[NSUnderlyingErrorKey] as? NSError {
                    print("[StaticViewModel] Underlying error: \(underlyingError)")
                    print("[StaticViewModel] Underlying error domain: \(underlyingError.domain)")
                    print("[StaticViewModel] Underlying error code: \(underlyingError.code)")
                }
            }
        }
    }
    
    // 保存或更新統計數據
    func saveStatistic(_ statistic: LearningStatistic) async -> Bool {
        guard Auth.auth().currentUser?.uid != nil else {
            return false
        }

        isLoading = true
        errorMessage = nil

        do {
            var updatedStatistic = statistic
            updatedStatistic.updatedAt = Date()

            // 準備統計數據
            var data: [String: Any] = [
                "userId": updatedStatistic.userId,
                "category": updatedStatistic.category,
                "progress": updatedStatistic.progress,
                "taskcount": updatedStatistic.taskcount,
                "taskcompletecount": updatedStatistic.taskcompletecount,
                "totalFocusTime": updatedStatistic.totalFocusTime,
                "date": Timestamp(date: updatedStatistic.date),
                "updatedAt": Timestamp(date: updatedStatistic.updatedAt),
                "version": updatedStatistic.version
            ]

            // 如果有 ID，加入到 data 中
            if let statisticId = updatedStatistic.id {
                data["id"] = statisticId
            }

            // 轉換 Timestamp 為 ISO 8601 字符串
            let convertedData = convertTimestampsToStrings(data)

            // 調用 Cloud Functions 更新統計數據
            let parameters: [String: Any] = ["statistic": convertedData]

            let result = try await functions.httpsCallable("updateStatistic").call(parameters)

            guard let responseData = result.data as? [String: Any],
                  let success = responseData["success"] as? Bool,
                  success else {
                throw NSError(domain: "StaticViewModelErrorDomain", code: -1,
                             userInfo: [NSLocalizedDescriptionKey: "保存統計數據失敗"])
            }

            // 重新載入數據以確保UI更新
            await fetchStatistics()

            isLoading = false
            return true
        } catch {
            errorMessage = "保存統計數據失敗: \(error.localizedDescription)"
            isLoading = false
            print("Error saving statistic: \(error)")
            return false
        }
    }
    
    // 按分類計算總專注時間
    func totalFocusTimeByCategory() -> [String: Int] {
        var result: [String: Int] = [:]
        
        for stat in statistics {
            result[stat.category, default: 0] += stat.totalFocusTime
        }
        
        return result
    }
    
    // 獲取類別進度
    func getCategoryProgress() -> [String: Double] {
        var result: [String: Double] = [:]
        
        for stat in statistics {
            result[stat.category] = stat.progress
        }
        
        return result
    }
    
    // 獲取類別任務完成率
    func getCategoryTaskCompletionRate() -> [String: Double] {
        var result: [String: Double] = [:]
        
        for stat in statistics {
            if stat.taskcount > 0 {
                result[stat.category] = Double(stat.taskcompletecount) / Double(stat.taskcount)
            } else {
                result[stat.category] = 0.0
            }
        }
        
        return result
    }
    
    // 更新類別進度
    func updateCategoryProgress(category: String, progress: Double) async {
        // 檢查是否已存在該類別的統計數據
        if let existingStat = statistics.first(where: { $0.category == category }) {
            var updatedStat = existingStat
            updatedStat.progress = progress
            _ = await saveStatistic(updatedStat)
        } else {
            // 創建新的統計數據
            let newStat = LearningStatistic(
                userId: Auth.auth().currentUser?.uid ?? "",
                category: category,
                progress: progress
            )
            _ = await saveStatistic(newStat)
        }
    }
    
    // 更新類別專注時間
    func updateCategoryFocusTime(category: String, additionalTime: Int) async {
        // 檢查是否已存在該類別的統計數據
        if let existingStat = statistics.first(where: { $0.category == category }) {
            var updatedStat = existingStat
            updatedStat.totalFocusTime += additionalTime
            _ = await saveStatistic(updatedStat)
        } else {
            // 創建新的統計數據
            let newStat = LearningStatistic(
                userId: Auth.auth().currentUser?.uid ?? "",
                category: category,
                totalFocusTime: additionalTime
            )
            _ = await saveStatistic(newStat)
        }
    }
    
    // 更新類別任務統計
    func updateCategoryTaskStats(category: String, completedCount: Int, totalCount: Int) async {
        // 檢查是否已存在該類別的統計數據
        if let existingStat = statistics.first(where: { $0.category == category }) {
            var updatedStat = existingStat
            updatedStat.taskcount = totalCount
            updatedStat.taskcompletecount = completedCount
            _ = await saveStatistic(updatedStat)
        } else {
            // 創建新的統計數據
            let newStat = LearningStatistic(
                userId: Auth.auth().currentUser?.uid ?? "",
                category: category,
                taskcount: totalCount,
                taskcompletecount: completedCount
            )
            _ = await saveStatistic(newStat)
        }
    }
    
    // 新增：同時更新任務統計和專注時間的方法
    func updateCategoryStats(category: String, completedCount: Int, totalCount: Int, totalFocusTime: Int) async {
        // 檢查是否已存在該類別的統計數據
        if let existingStat = statistics.first(where: { $0.category == category }) {
            var updatedStat = existingStat
            updatedStat.taskcount = totalCount
            updatedStat.taskcompletecount = completedCount
            updatedStat.totalFocusTime = totalFocusTime // 直接設置總專注時間
            _ = await saveStatistic(updatedStat)
            
            print("更新現有統計：\(category) - 完成度：\(completedCount)/\(totalCount), 專注時間：\(totalFocusTime)分鐘")
        } else {
            // 創建新的統計數據
            let newStat = LearningStatistic(
                userId: Auth.auth().currentUser?.uid ?? "",
                category: category,
                taskcount: totalCount,
                taskcompletecount: completedCount,
                totalFocusTime: totalFocusTime,
                date: Date(),
                updatedAt: Date(),
                version: 1
            )
            _ = await saveStatistic(newStat)
            
            print("創建新統計：\(category) - 完成度：\(completedCount)/\(totalCount), 專注時間：\(totalFocusTime)分鐘")
        }
    }
    
    // 計算類別數量
    func categoryCount() -> Int {
        return Set(statistics.map { $0.category }).count
    }
    
    // 刪除統計類別
    func deleteStatistic(_ statisticId: String) async {
        guard Auth.auth().currentUser?.uid != nil else {
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            // 調用 Cloud Functions 刪除統計數據
            let result = try await functions.httpsCallable("deleteStatistic").call([
                "statisticId": statisticId
            ])

            guard let data = result.data as? [String: Any],
                  let success = data["success"] as? Bool,
                  success else {
                throw NSError(domain: "StaticViewModelErrorDomain", code: -1,
                             userInfo: [NSLocalizedDescriptionKey: "刪除統計類別失敗"])
            }

            // 從本地陣列中移除該統計
            await MainActor.run {
                if let index = statistics.firstIndex(where: { $0.id == statisticId }) {
                    statistics.remove(at: index)
                }
            }

            isLoading = false
            print("成功刪除統計類別 ID: \(statisticId)")
        } catch {
            await MainActor.run {
                errorMessage = "刪除統計類別失敗: \(error.localizedDescription)"
                isLoading = false
            }
            print("刪除統計類別錯誤: \(error)")
        }
    }
    
    // 獲取Token使用量
    func fetchTokenUsageStats() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("[StaticViewModel] fetchTokenUsageStats: 用戶未登入")
            return
        }

        print("[StaticViewModel] 開始獲取 Token 使用量，用戶ID: \(userId)")
        isLoading = true

        do {
            // 調用 Cloud Functions 獲取 Token 使用量
            let result = try await functions.httpsCallable("fetchTokenUsage").call()

            print("[StaticViewModel] 收到 fetchTokenUsage 回應: \(result.data)")

            guard let data = result.data as? [String: Any] else {
                print("[StaticViewModel] 錯誤: 無法解析 fetchTokenUsage 回應為字典")
                isLoading = false
                return
            }

            print("[StaticViewModel] fetchTokenUsage 回應數據鍵: \(data.keys)")

            guard let success = data["success"] as? Bool, success else {
                print("[StaticViewModel] fetchTokenUsage 返回失敗或沒有 success 字段")
                isLoading = false
                return
            }

            print("[StaticViewModel] fetchTokenUsage success 狀態: true")

            // 注意：Cloud Function 返回的是 "tokenUsage" 而不是 "usage"
            if let usageData = data["tokenUsage"] as? [String: Any] {
                print("[StaticViewModel] 找到 tokenUsage 數據，鍵: \(usageData.keys)")
                var modelUsage: [String: ModelTokenUsage] = [:]

                // 獲取模型使用量
                if let modelUsageData = usageData["modelUsage"] as? [String: Any] {
                    print("[StaticViewModel] 找到 modelUsage，模型數量: \(modelUsageData.count)")
                    for (model, usage) in modelUsageData {
                        if let usageDict = usage as? [String: Any] {
                            let totalTokens = usageDict["total"] as? Int ?? 0
                            let promptTokens = usageDict["prompt"] as? Int
                            let completionTokens = usageDict["completion"] as? Int

                            print("[StaticViewModel] 模型 \(model): total=\(totalTokens), prompt=\(promptTokens ?? 0), completion=\(completionTokens ?? 0)")

                            modelUsage[model] = ModelTokenUsage(
                                total: totalTokens,
                                prompt: promptTokens,
                                completion: completionTokens
                            )
                        } else if let totalTokens = usage as? Int {
                            // 處理舊數據格式，僅有總數沒有詳細分類
                            print("[StaticViewModel] 模型 \(model) (舊格式): total=\(totalTokens)")
                            modelUsage[model] = ModelTokenUsage(total: totalTokens)
                        }
                    }
                } else {
                    print("[StaticViewModel] 沒有找到 modelUsage 數據")
                }

                let totalTokens = usageData["totalTokens"] as? Int ?? 0
                print("[StaticViewModel] totalTokens: \(totalTokens)")

                // 轉換 lastUpdated（可能是 Timestamp 格式）
                let convertedUsageData = convertToTimestamps(usageData)
                let lastUpdated = (convertedUsageData["lastUpdated"] as? Timestamp)?.dateValue() ?? Date()
                print("[StaticViewModel] lastUpdated: \(lastUpdated)")

                // 構建完整的使用量統計
                let newTokenUsage = TokenUsageStats(
                    totalTokens: totalTokens,
                    modelUsage: modelUsage,
                    lastUpdated: lastUpdated
                )

                await MainActor.run {
                    self.tokenUsage = newTokenUsage
                    print("[StaticViewModel] Token 使用量已更新: \(newTokenUsage.totalTokens) tokens")
                }
            } else {
                print("[StaticViewModel] 沒有找到 usage 數據")
            }

            isLoading = false
        } catch {
            errorMessage = "載入Token使用量失敗: \(error.localizedDescription)"
            isLoading = false
            print("[StaticViewModel] Error fetching token usage: \(error)")
        }
    }
}

// 模型token使用量結構
struct ModelTokenUsage {
    var total: Int
    var prompt: Int?
    var completion: Int?
    
    init(total: Int, prompt: Int? = nil, completion: Int? = nil) {
        self.total = total
        self.prompt = prompt
        self.completion = completion
    }
}

// 定義Token使用量結構
struct TokenUsageStats {
    var totalTokens: Int
    var modelUsage: [String: ModelTokenUsage]
    var lastUpdated: Date
    
    init(totalTokens: Int = 0, modelUsage: [String: ModelTokenUsage] = [:], lastUpdated: Date = Date()) {
        self.totalTokens = totalTokens
        self.modelUsage = modelUsage
        self.lastUpdated = lastUpdated
    }
}

