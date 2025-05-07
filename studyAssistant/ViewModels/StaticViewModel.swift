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
    
    private let db = Firestore.firestore()
    
    // 初始化並設置監聽器
    init() {
        setupAuthListener()
    }
    
    // 設置驗證狀態監聽
    private func setupAuthListener() {
        Auth.auth().addStateDidChangeListener { [weak self] (auth, user) in
            if user != nil {
                // 使用者登入，載入數據
                Task {
                    await self?.fetchStatistics()
                }
            } else {
                // 使用者登出，清空數據
                self?.statistics = []
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
    
    // 計算類別數量
    func categoryCount() -> Int {
        return Set(statistics.map { $0.category }).count
    }
}

