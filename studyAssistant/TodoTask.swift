import SwiftUI

// 任務重複類型
enum RepeatType: Hashable {
    case none
    case daily
    case weekly([Int])   // 0=Sunday, 1=Monday, ...
    case monthly([Int])  // 幾號
    
    // 實現 Hashable
    func hash(into hasher: inout Hasher) {
        switch self {
        case .none:
            hasher.combine(0)
        case .daily:
            hasher.combine(1)
        case .weekly(let days):
            hasher.combine(2)
            hasher.combine(days)
        case .monthly(let days):
            hasher.combine(3)
            hasher.combine(days)
        }
    }
    
    // 實現 Equatable
    static func == (lhs: RepeatType, rhs: RepeatType) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none):
            return true
        case (.daily, .daily):
            return true
        case (.weekly(let lhsDays), .weekly(let rhsDays)):
            return lhsDays == rhsDays
        case (.monthly(let lhsDays), .monthly(let rhsDays)):
            return lhsDays == rhsDays
        default:
            return false
        }
    }
}

// Todo 任務資料結構
struct TodoTask: Identifiable {
    let id = UUID()                    // 唯一識別符
    var title: String                  // 任務標題
    var note: String                   // 任務備註
    var color: Color                   // 任務顏色
    var focusTime: Int                 // 專注時間（分鐘）
    var category: String               // 任務類別
    
    var isAllDay: Bool                 // 是否全天
    var isCompleted: Bool              // 是否完成
    var repeatType: RepeatType         // 重複類型
    var startDate: Date                // 任務開始日期（重複任務的起始日）
    var endDate: Date                  // 任務結束日期（重複任務的結束日）
    var createdAt: Date                // 任務建立時間
    
    // 格式化時間為字符串
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: startDate)
    }
} 