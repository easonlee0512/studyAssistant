//
//  StaticViewModel.swift
//  studyAssistant
//
//  Created by 李翊辰 on 2025/5/7.
//

import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAuth

@MainActor
class StaticViewModel: ObservableObject {
    @Published var statistics: [LearningStatistic] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    @Published var tokenUsage = TokenUsageStats()
    
    private let db = Firestore.firestore()
    
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
        
        // 忽略未分類或空類別
        if category.isEmpty || category == "未分類" { return }
        
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
    
    // 從Firestore獲取統計數據
    func fetchStatistics() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            self.statistics = []
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let querySnapshot = try await db.collection("userStatistics")
                .document(userId)
                .collection("statistics")
                .getDocuments()
            
            var newStatistics: [LearningStatistic] = []
            
            for document in querySnapshot.documents {
                let data = document.data()
                
                // 手動解析文檔數據
                let id = document.documentID
                let userId = data["userId"] as? String ?? ""
                let category = data["category"] as? String ?? ""
                let progress = data["progress"] as? Double ?? 0.0
                let taskcount = data["taskcount"] as? Int ?? 0
                let taskcompletecount = data["taskcompletecount"] as? Int ?? 0
                let totalFocusTime = data["totalFocusTime"] as? Int ?? 0
                let version = data["version"] as? Int ?? 1
                
                let dateTimestamp = data["date"] as? Timestamp
                let date = dateTimestamp?.dateValue() ?? Date()
                
                let updatedAtTimestamp = data["updatedAt"] as? Timestamp
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
            
            // 新增：獲取Token使用量
            await fetchTokenUsageStats()
        } catch {
            self.errorMessage = "載入統計數據失敗: \(error.localizedDescription)"
            self.isLoading = false
            print("Error fetching statistics: \(error)")
        }
    }
    
    // 保存或更新統計數據
    func saveStatistic(_ statistic: LearningStatistic) async -> Bool {
        guard let userId = Auth.auth().currentUser?.uid else {
            return false
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            var updatedStatistic = statistic
            updatedStatistic.userId = userId
            updatedStatistic.updatedAt = Date()
            
            let docRef = updatedStatistic.id == nil ? 
                db.collection("userStatistics").document(userId).collection("statistics").document() :
                db.collection("userStatistics").document(userId).collection("statistics").document(updatedStatistic.id!)
            
            // 手動將 LearningStatistic 轉換為字典
            let data: [String: Any] = [
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
            
            try await docRef.setData(data)
            
            // 如果是新創建的文檔，更新 ID
            if updatedStatistic.id == nil {
                updatedStatistic.id = docRef.documentID
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
        guard let userId = Auth.auth().currentUser?.uid else {
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // 從 Firestore 刪除統計數據
            try await db.collection("userStatistics")
                .document(userId)
                .collection("statistics")
                .document(statisticId)
                .delete()
            
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
            return
        }
        
        isLoading = true
        
        do {
            let docRef = db.collection("userStatistics").document(userId)
            let document = try await docRef.getDocument()
            
            if document.exists, let data = document.data() {
                var modelUsage: [String: ModelTokenUsage] = [:]
                
                // 獲取模型使用量
                if let usageData = data["modelUsage"] as? [String: Any] {
                    for (model, usage) in usageData {
                        if let usageDict = usage as? [String: Any] {
                            let totalTokens = usageDict["total"] as? Int ?? 0
                            let promptTokens = usageDict["prompt"] as? Int
                            let completionTokens = usageDict["completion"] as? Int
                            
                            modelUsage[model] = ModelTokenUsage(
                                total: totalTokens,
                                prompt: promptTokens,
                                completion: completionTokens
                            )
                        } else if let totalTokens = usage as? Int {
                            // 處理舊數據格式，僅有總數沒有詳細分類
                            modelUsage[model] = ModelTokenUsage(total: totalTokens)
                        }
                    }
                }
                
                // 構建完整的使用量統計
                let newTokenUsage = TokenUsageStats(
                    totalTokens: data["totalTokens"] as? Int ?? 0,
                    modelUsage: modelUsage,
                    lastUpdated: (data["lastUpdated"] as? Timestamp)?.dateValue() ?? Date()
                )
                
                await MainActor.run {
                    self.tokenUsage = newTokenUsage
                }
            }
            
            isLoading = false
        } catch {
            errorMessage = "載入Token使用量失敗: \(error.localizedDescription)"
            isLoading = false
            print("Error fetching token usage: \(error)")
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

