import Foundation
// 移除 Firebase 依賴
// import FirebaseFirestore

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
}

// 本地存儲管理器
class TimerRecordManager {
    static let shared = TimerRecordManager()
    private let userDefaults = UserDefaults.standard
    private let recordsKey = "timerRecords"
    private var records: [TimerRecord] = []
    
    private init() {
        loadRecords()
    }
    
    // 從本地存儲加載記錄
    private func loadRecords() {
        if let data = userDefaults.data(forKey: recordsKey) {
            let decoder = JSONDecoder()
            do {
                records = try decoder.decode([TimerRecord].self, from: data)
            } catch {
                print("讀取計時記錄失敗: \(error.localizedDescription)")
                records = []
            }
        }
    }
    
    // 保存記錄到本地存儲
    private func saveRecords() {
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(records)
            userDefaults.set(data, forKey: recordsKey)
        } catch {
            print("保存計時記錄失敗: \(error.localizedDescription)")
        }
    }
    
    // 添加新記錄
    func addRecord(_ record: TimerRecord) {
        records.append(record)
        saveRecords()
    }
    
    // 獲取所有記錄
    func getAllRecords() -> [TimerRecord] {
        return records.filter { !$0.isDeleted }
    }
    
    // 獲取指定用戶的記錄
    func getRecords(userId: String) -> [TimerRecord] {
        return records.filter { !$0.isDeleted && $0.userId == userId }
    }
    
    // 獲取指定時間範圍的記錄
    func getRecords(userId: String, from: Date, to: Date) -> [TimerRecord] {
        return records.filter { 
            !$0.isDeleted && 
            $0.userId == userId && 
            $0.startTime >= from && 
            $0.startTime <= to 
        }
    }
    
    // 更新記錄
    func updateRecord(_ record: TimerRecord) {
        if let index = records.firstIndex(where: { $0.id == record.id }) {
            records[index] = record
            saveRecords()
        }
    }
    
    // 刪除記錄（標記為已刪除）
    func deleteRecord(id: String) {
        if let index = records.firstIndex(where: { $0.id == id }) {
            var record = records[index]
            record.isDeleted = true
            record.lastModifiedAt = Date()
            records[index] = record
            saveRecords()
        }
    }
    
    // 完全清除記錄
    func clearRecords() {
        records.removeAll()
        saveRecords()
    }
    
    // 獲取統計數據
    func getStatistics(userId: String) -> TimerStatistics {
        let userRecords = getRecords(userId: userId)
        return TimerStatistics.calculate(from: userRecords)
    }
    
    // 獲取指定時間範圍的統計數據
    func getStatistics(userId: String, from: Date, to: Date) -> TimerStatistics {
        let userRecords = getRecords(userId: userId, from: from, to: to)
        return TimerStatistics.calculate(from: userRecords)
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