import Foundation
import FirebaseFirestore

struct TimerRecord: Identifiable, Codable {
    var id: String
    var userId: String
    var subject: String
    var startTime: Date
    var endTime: Date
    var duration: Int // 持續時間，以秒為單位
    var isCompleted: Bool
    var createdAt: Date
    var lastModifiedAt: Date
    var isDeleted: Bool = false
    
    // 計算屬性
    var durationInMinutes: Double {
        return Double(duration) / 60.0
    }
    
    // 創建新記錄的初始化方法
    init(userId: String, subject: String, startTime: Date, endTime: Date, isCompleted: Bool) {
        self.id = UUID().uuidString
        self.userId = userId
        self.subject = subject
        self.startTime = startTime
        self.endTime = endTime
        self.duration = Int(endTime.timeIntervalSince(startTime))
        self.isCompleted = isCompleted
        self.createdAt = Date()
        self.lastModifiedAt = Date()
    }
    
    // Firestore 初始化方法
    init?(documentId: String, data: [String: Any]) {
        guard let userId = data["userId"] as? String,
              let subject = data["subject"] as? String,
              let startTime = (data["startTime"] as? Timestamp)?.dateValue(),
              let endTime = (data["endTime"] as? Timestamp)?.dateValue(),
              let isCompleted = data["isCompleted"] as? Bool,
              let createdAt = (data["createdAt"] as? Timestamp)?.dateValue(),
              let lastModifiedAt = (data["lastModifiedAt"] as? Timestamp)?.dateValue() else {
            return nil
        }
        
        self.id = documentId
        self.userId = userId
        self.subject = subject
        self.startTime = startTime
        self.endTime = endTime
        self.duration = Int(endTime.timeIntervalSince(startTime))
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.lastModifiedAt = lastModifiedAt
        self.isDeleted = data["isDeleted"] as? Bool ?? false
    }
    
    // Firestore 資料轉換
    var toFirestore: [String: Any] {
        return [
            "userId": userId,
            "subject": subject,
            "startTime": Timestamp(date: startTime),
            "endTime": Timestamp(date: endTime),
            "duration": duration,
            "isCompleted": isCompleted,
            "createdAt": Timestamp(date: createdAt),
            "lastModifiedAt": Timestamp(date: lastModifiedAt),
            "isDeleted": isDeleted
        ]
    }
}

// 分類統計的輔助類型
struct TimerStatistics {
    // 按科目統計
    var subjectStats: [String: SubjectStats] = [:]
    // 按日期統計
    var dailyStats: [Date: DailyStats] = [:]
    // 總計
    var totalDuration: Int = 0
    var totalSessions: Int = 0
    var completedSessions: Int = 0
    var incompleteSessions: Int = 0
    var totalTime: TimeInterval = 0
    var averageSessionTime: TimeInterval = 0
    
    // 科目統計
    struct SubjectStats {
        var totalDuration: Int = 0
        var sessionCount: Int = 0
        var completedCount: Int = 0
    }
    
    // 日期統計
    struct DailyStats {
        var totalDuration: Int = 0
        var sessionCount: Int = 0
        var subjects: Set<String> = []
    }
    
    // 根據記錄計算統計數據
    static func calculate(from records: [TimerRecord]) -> TimerStatistics {
        var stats = TimerStatistics()
        
        for record in records.filter({ !$0.isDeleted }) {
            // 總計
            stats.totalDuration += record.duration
            stats.totalSessions += 1
            if record.isCompleted {
                stats.completedSessions += 1
            } else {
                stats.incompleteSessions += 1
            }
            
            // 按科目統計
            let subject = record.subject
            var subjectStat = stats.subjectStats[subject] ?? SubjectStats()
            subjectStat.totalDuration += record.duration
            subjectStat.sessionCount += 1
            if record.isCompleted {
                subjectStat.completedCount += 1
            }
            stats.subjectStats[subject] = subjectStat
            
            // 按日期統計 (只使用日期部分)
            let calendar = Calendar.current
            let dateComponents = calendar.dateComponents([.year, .month, .day], from: record.startTime)
            let dateKey = calendar.date(from: dateComponents)!
            
            var dailyStat = stats.dailyStats[dateKey] ?? DailyStats()
            dailyStat.totalDuration += record.duration
            dailyStat.sessionCount += 1
            dailyStat.subjects.insert(record.subject)
            stats.dailyStats[dateKey] = dailyStat
        }
        
        // 計算平均時間
        if stats.totalSessions > 0 {
            stats.totalTime = TimeInterval(stats.totalDuration)
            stats.averageSessionTime = stats.totalTime / Double(stats.totalSessions)
        }
        
        return stats
    }
} 