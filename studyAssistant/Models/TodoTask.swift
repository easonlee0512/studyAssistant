import SwiftUI
import FirebaseFirestore
import FirebaseAuth

// 任務重複類型
public enum RepeatType: Hashable, Codable {
    case none
    case daily
    case weekly([Int])   // 0=Sunday, 1=Monday, ...
    case monthly([Int])  // 幾號
    
    // 實現 Hashable
    public func hash(into hasher: inout Hasher) {
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
    public static func == (lhs: RepeatType, rhs: RepeatType) -> Bool {
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
    var endDate: Date                  // 任務結束日期（重複任務的結束日）
    var createdAt: Date                // 任務建立時間
    var userId: String                 // 使用者 ID
    
    // 建立新任務的初始化方法
    init(title: String, note: String, color: Color, focusTime: Int, category: String,
         isAllDay: Bool, isCompleted: Bool, repeatType: RepeatType,
         startDate: Date, endDate: Date, userId: String = Auth.auth().currentUser?.uid ?? "") {
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
        self.createdAt = Date()
        self.userId = userId.isEmpty ? (Auth.auth().currentUser?.uid ?? "default") : userId
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
        self.createdAt = createdAt
        self.userId = userId
        
        // 解析 RepeatType
        if let type = repeatTypeRaw["type"] as? String {
            switch type {
            case "daily":
                self.repeatType = .daily
            case "weekly":
                if let days = repeatTypeRaw["days"] as? [Int] {
                    self.repeatType = .weekly(days)
                } else {
                    self.repeatType = .none
                }
            case "monthly":
                if let days = repeatTypeRaw["days"] as? [Int] {
                    self.repeatType = .monthly(days)
                } else {
                    self.repeatType = .none
                }
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
        case .weekly(let days):
            repeatTypeData = [
                "type": "weekly",
                "days": days
            ]
        case .monthly(let days):
            repeatTypeData = [
                "type": "monthly",
                "days": days
            ]
        case .none:
            break
        }
        
        return [
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
            "userId": userId
        ]
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
        
        switch repeatType {
        case .daily:
            // 每天無限重複，只要日期不早於起始日
            return startOfDate >= startOfStartDate
            
        case .weekly(let days):
            guard startOfDate >= startOfStartDate else { return false }
            
            // ① 這週的「起日」「迄日」各落在星期幾
            let startW = (calendar.component(.weekday, from: startDate) - 1 + 7) % 7
            let span   = calendar.dateComponents([.day],
                            from: startDate.startOfDay,
                            to:   endDate.startOfDay).day! + 1
            
            // ② 目標日期是星期幾？距離「起日」幾天？
            let weekday     = (calendar.component(.weekday, from: date) - 1 + 7) % 7
            let shiftInWeek = (weekday - startW + 7) % 7
            
            // ③ 「有指定 days」→ 直接比對；否則就用 span 判斷連續區段
            if !days.isEmpty {
                return days.contains(weekday)
            } else {
                return shiftInWeek < span
            }
            
        case .monthly(let days):
            guard startOfDate >= startOfStartDate else { return false }
            
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
            if !days.isEmpty {
                return days.contains(dayOfMonth)
            } else {
                return shift < span
            }
            
        case .none:
            // 不重複：仍只顯示在原始區段內
            return startOfDate >= startOfStartDate && startOfDate <= startOfEndDate
        }
    }
    
    // 實現 Equatable
    public static func == (lhs: TodoTask, rhs: TodoTask) -> Bool {
        return lhs.id == rhs.id
    }
    
    // 為 Codable 添加 CodingKeys
    enum CodingKeys: String, CodingKey {
        case id, title, note, focusTime, category, isAllDay, isCompleted, repeatType, startDate, endDate, createdAt, userId
        case color // 特別處理
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

// Date 擴充，取得當天 00:00:00
// extension Date {
//     var startOfDay: Date {
//         Calendar.current.startOfDay(for: self)
//     }
// } 
