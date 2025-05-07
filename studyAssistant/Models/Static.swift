//
//  Static.swift
//  studyAssistant
//
//  Created by 李翊辰 on 2025/5/7.
//

import Foundation
import Firebase
import FirebaseFirestore

struct LearningStatistic: Identifiable, Codable {
    var id: String?
    var userId: String
    var category: String        // 分類
    var progress: Double        // 進度百分比 (0-1)
    var taskcount: Int          // 任務總數
    var taskcompletecount: Int  // 已完成任務數
    var totalFocusTime: Int     // 總專注時間(分鐘)
    var date: Date              // 統計日期
    var updatedAt: Date
    var version: Int
    
    // 預設初始化
    init(id: String? = nil, 
         userId: String, 
         category: String, 
         progress: Double = 0.0, 
         taskcount: Int = 0, 
         taskcompletecount: Int = 0, 
         totalFocusTime: Int = 0, 
         date: Date = Date(), 
         updatedAt: Date = Date(), 
         version: Int = 1) {
        
        self.id = id
        self.userId = userId
        self.category = category
        self.progress = progress
        self.taskcount = taskcount
        self.taskcompletecount = taskcompletecount
        self.totalFocusTime = totalFocusTime
        self.date = date
        self.updatedAt = updatedAt
        self.version = version
    }
}

