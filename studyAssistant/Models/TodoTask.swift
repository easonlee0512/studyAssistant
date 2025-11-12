import SwiftUI
import FirebaseFirestore
import FirebaseAuth

// 任務重複類型
public enum RepeatType: Hashable, Codable {
    case none
    case daily
    case weekly
    case monthly
    
    // 實現 Hashable
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .none:
            hasher.combine(0)
        case .daily:
            hasher.combine(1)
        case .weekly:
            hasher.combine(2)
        case .monthly:
            hasher.combine(3)
        }
    }
    
    // 實現 Equatable
    public static func == (lhs: RepeatType, rhs: RepeatType) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none):
            return true
        case (.daily, .daily):
            return true
        case (.weekly, .weekly):
            return true
        case (.monthly, .monthly):
            return true
        default:
            return false
        }
    }
}

// 任務實例資料結構
public struct TaskInstance: Identifiable, Codable, Equatable {
    public let id: String
    var date: Date
    var isCompleted: Bool
    var parentTaskId: String
    
    // 從 Firestore 資料建立實例
    init?(documentId: String, data: [String: Any]) {
        guard let date = (data["date"] as? Timestamp)?.dateValue(),
              let isCompleted = data["isCompleted"] as? Bool,
              let parentTaskId = data["parentTaskId"] as? String
        else { return nil }
        
        self.id = documentId
        self.date = date
        self.isCompleted = isCompleted
        self.parentTaskId = parentTaskId
    }
    
    // 轉換為 Firestore 資料
    var toFirestore: [String: Any] {
        return [
            "date": Timestamp(date: date),
            "isCompleted": isCompleted,
            "parentTaskId": parentTaskId
        ]
    }
    
    // 實現 Equatable
    public static func == (lhs: TaskInstance, rhs: TaskInstance) -> Bool {
        return lhs.id == rhs.id
    }
}

// Todo 任務資料結構
public struct TodoTask: Identifiable, Codable, Equatable {
    public let id: String                     // Firestore 文件 ID
    var title: String                  // 任務標題
    var note: String                   // 任務備註
    var color: Color                   // 任務顏色
    var focusTime: Int                 // 專注時間（分鐘）
    var category: String               // 任務類別
    
    var isAllDay: Bool                 // 是否全天
    var isCompleted: Bool              // 是否完成
    var repeatType: RepeatType         // 重複類型
    var startDate: Date                // 任務開始日期（重複任務的起始日）
    var endDate: Date                  // 任務結束日期
    var repeatEndDate: Date?           // 重複任務的結束日期
    var createdAt: Date                // 任務建立時間
    var userId: String                 // 使用者 ID

    var instances: [TaskInstance]

    // 通知相關欄位
    var notificationEnabled: Bool      // 是否啟用通知
    var notificationOffset: Int        // 提前多少分鐘提醒（0, 5, 10, 15, 30, 60）
    
    // 建立新任務的初始化方法
    init(title: String, note: String, color: Color, focusTime: Int = 0, category: String,
         isAllDay: Bool, isCompleted: Bool, repeatType: RepeatType,
         startDate: Date, endDate: Date, repeatEndDate: Date? = nil, userId: String = Auth.auth().currentUser?.uid ?? "",
         notificationEnabled: Bool = false, notificationOffset: Int = 10) {
        self.id = UUID().uuidString
        self.title = title
        self.note = note
        self.color = color
        self.focusTime = focusTime
        self.category = category
        self.isAllDay = isAllDay
        self.isCompleted = isCompleted
        self.repeatType = repeatType
        self.startDate = startDate
        self.endDate = endDate
        self.repeatEndDate = repeatEndDate
        self.createdAt = Date()
        self.userId = userId.isEmpty ? (Auth.auth().currentUser?.uid ?? "default") : userId
        self.instances = []
        self.notificationEnabled = notificationEnabled
        self.notificationOffset = notificationOffset
    }
    
    // 從 Firestore 資料建立任務
    init?(documentId: String, data: [String: Any]) {
        guard let title = data["title"] as? String,
              let note = data["note"] as? String,
              let colorComponents = data["color"] as? [String: CGFloat],
              let focusTime = data["focusTime"] as? Int,
              let category = data["category"] as? String,
              let isAllDay = data["isAllDay"] as? Bool,
              let isCompleted = data["isCompleted"] as? Bool,
              let repeatTypeRaw = data["repeatType"] as? [String: Any],
              let startDate = (data["startDate"] as? Timestamp)?.dateValue(),
              let endDate = (data["endDate"] as? Timestamp)?.dateValue(),
              let createdAt = (data["createdAt"] as? Timestamp)?.dateValue(),
              let userId = data["userId"] as? String
        else { return nil }
        
        self.id = documentId
        self.title = title
        self.note = note
        self.color = Color(
            red: colorComponents["red"] ?? 0,
            green: colorComponents["green"] ?? 0,
            blue: colorComponents["blue"] ?? 0,
            opacity: colorComponents["opacity"] ?? 1
        )
        self.focusTime = focusTime
        self.category = category
        self.isAllDay = isAllDay
        self.isCompleted = isCompleted
        self.startDate = startDate
        self.endDate = endDate
        self.repeatEndDate = (data["repeatEndDate"] as? Timestamp)?.dateValue()
        self.createdAt = createdAt
        self.userId = userId
        self.instances = []

        // 解析通知相關欄位（可選，預設值）
        self.notificationEnabled = data["notificationEnabled"] as? Bool ?? false
        self.notificationOffset = data["notificationOffset"] as? Int ?? 10

        // 解析 RepeatType
        if let type = repeatTypeRaw["type"] as? String {
            switch type {
            case "daily":
                self.repeatType = .daily
            case "weekly":
                self.repeatType = .weekly
            case "monthly":
                self.repeatType = .monthly
            default:
                self.repeatType = .none
            }
        } else {
            self.repeatType = .none
        }
    }
    
    // 轉換為 Firestore 資料
    var toFirestore: [String: Any] {
        let colorComponents = UIColor(color).cgColor.components ?? [0, 0, 0, 1]
        let colorData: [String: CGFloat] = [
            "red": CGFloat(colorComponents[0]),
            "green": CGFloat(colorComponents[1]),
            "blue": CGFloat(colorComponents[2]),
            "opacity": CGFloat(colorComponents[3])
        ]
        
        var repeatTypeData: [String: Any] = ["type": "none"]
        switch repeatType {
        case .daily:
            repeatTypeData = ["type": "daily"]
        case .weekly:
            repeatTypeData = ["type": "weekly"]
        case .monthly:
            repeatTypeData = ["type": "monthly"]
        case .none:
            break
        }
        
        var data: [String: Any] = [
            "title": title,
            "note": note,
            "color": colorData,
            "focusTime": focusTime,
            "category": category,
            "isAllDay": isAllDay,
            "isCompleted": isCompleted,
            "repeatType": repeatTypeData,
            "startDate": Timestamp(date: startDate),
            "endDate": Timestamp(date: endDate),
            "createdAt": Timestamp(date: createdAt),
            "userId": userId,
            "notificationEnabled": notificationEnabled,
            "notificationOffset": notificationOffset
        ]
        
        // 如果有重複結束日期，加入資料中
        if let repeatEndDate = repeatEndDate {
            data["repeatEndDate"] = Timestamp(date: repeatEndDate)
        }
        
        return data
    }
    
    // 格式化時間為字符串
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: startDate)
    }
    
    func shouldDisplay(on date: Date) -> Bool {
        let calendar = Calendar.current
        let startOfDate      = calendar.startOfDay(for: date)
        let startOfStartDate = calendar.startOfDay(for: startDate)
        let startOfEndDate   = calendar.startOfDay(for: endDate)
        
        // 檢查是否有該日期的已完成實例
        if hasCompletedInstance(on: date) {
            return true
        }
        
        // 如果日期早於起始日，一律不顯示
        guard startOfDate >= startOfStartDate else { return false }
        
        // 如果是重複任務且有結束日期，檢查是否超過結束日期
        if repeatType != .none, let repeatEndDate = repeatEndDate {
            let startOfRepeatEndDate = calendar.startOfDay(for: repeatEndDate)
            if startOfDate > startOfRepeatEndDate {
                return false
            }
        }
        
        switch repeatType {
        case .daily:
            // 每天重複，只要日期不早於起始日且不晚於結束日即可
            return true
            
        case .weekly:
            // ① 這週的「起日」「迄日」各落在星期幾
            let startW = (calendar.component(.weekday, from: startDate) - 1 + 7) % 7
            let span   = calendar.dateComponents([.day],
                            from: startDate.startOfDay,
                            to:   endDate.startOfDay).day! + 1
            
            // ② 目標日期是星期幾？距離「起日」幾天？
            let weekday     = (calendar.component(.weekday, from: date) - 1 + 7) % 7
            let shiftInWeek = (weekday - startW + 7) % 7
            
            // ③ 「有指定 days」→ 直接比對；否則就用 span 判斷連續區段
            return shiftInWeek < span
            
        case .monthly:
            // ① 取得目標日期是幾號
            let dayOfMonth = calendar.component(.day, from: date)
            
            // ② 計算每月重複區段的持續天數
            let span = calendar.dateComponents([.day],
                        from: startDate.startOfDay,
                        to:   endDate.startOfDay).day! + 1
            
            // ③ 計算與當月起始日的偏移量
            let startDay = calendar.component(.day, from: startDate)
            let shift = ((dayOfMonth - startDay + 31) % 31)
            
            // ④ 「有指定日期」→ 直接比對；否則就用 span 判斷連續區段
            return shift < span
            
        case .none:
            // 不重複：仍只顯示在原始區段內
            return startOfDate >= startOfStartDate && startOfDate <= startOfEndDate
        }
    }
    
    // 檢查特定日期是否有已完成的實例
    func hasCompletedInstance(on date: Date) -> Bool {
        let calendar = Calendar.current
        
        // 檢查所有實例
        for instance in instances {
            if instance.isCompleted && calendar.isDate(instance.date, inSameDayAs: date) {
                return true
            }
        }
        
        return false
    }
    
    // 實現 Equatable
    public static func == (lhs: TodoTask, rhs: TodoTask) -> Bool {
        return lhs.id == rhs.id
    }
    
    // 為 Codable 添加 CodingKeys
    enum CodingKeys: String, CodingKey {
        case id, title, note, focusTime, category, isAllDay, isCompleted, repeatType, startDate, endDate, createdAt, userId, instances
        case color // 特別處理
        case notificationEnabled, notificationOffset // 通知欄位
    }
    
    // 編碼
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(note, forKey: .note)
        try container.encode(focusTime, forKey: .focusTime)
        try container.encode(category, forKey: .category)
        try container.encode(isAllDay, forKey: .isAllDay)
        try container.encode(isCompleted, forKey: .isCompleted)
        try container.encode(repeatType, forKey: .repeatType)
        try container.encode(startDate, forKey: .startDate)
        try container.encode(endDate, forKey: .endDate)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(userId, forKey: .userId)
        try container.encode(instances, forKey: .instances)
        try container.encode(notificationEnabled, forKey: .notificationEnabled)
        try container.encode(notificationOffset, forKey: .notificationOffset)

        // 編碼顏色
        let colorComponents = UIColor(color).cgColor.components ?? [0, 0, 0, 1]
        let colorData: [String: CGFloat] = [
            "red": CGFloat(colorComponents[0]),
            "green": CGFloat(colorComponents[1]),
            "blue": CGFloat(colorComponents[2]),
            "opacity": CGFloat(colorComponents[3])
        ]
        try container.encode(colorData, forKey: .color)
    }
    
    // 解碼
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        note = try container.decode(String.self, forKey: .note)
        focusTime = try container.decode(Int.self, forKey: .focusTime)
        category = try container.decode(String.self, forKey: .category)
        isAllDay = try container.decode(Bool.self, forKey: .isAllDay)
        isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
        repeatType = try container.decode(RepeatType.self, forKey: .repeatType)
        startDate = try container.decode(Date.self, forKey: .startDate)
        endDate = try container.decode(Date.self, forKey: .endDate)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        userId = try container.decode(String.self, forKey: .userId)
        instances = try container.decode([TaskInstance].self, forKey: .instances)
        notificationEnabled = try container.decodeIfPresent(Bool.self, forKey: .notificationEnabled) ?? false
        notificationOffset = try container.decodeIfPresent(Int.self, forKey: .notificationOffset) ?? 10

        // 解碼顏色
        let colorData = try container.decode([String: CGFloat].self, forKey: .color)
        color = Color(
            red: colorData["red"] ?? 0,
            green: colorData["green"] ?? 0,
            blue: colorData["blue"] ?? 0,
            opacity: colorData["opacity"] ?? 1
        )
    }
}

//// Date 擴充，取得當天 00:00:00
//extension Date {
//    var startOfDay: Date {
//        Calendar.current.startOfDay(for: self)
//    }
//} 
