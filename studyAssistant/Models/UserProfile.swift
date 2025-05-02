import Foundation
import FirebaseFirestore

struct UserProfile: Codable, Identifiable {
    var id: String
    var email: String
    var username: String
    var motivationalQuote: String
    var targetDate: Date
    var userGoal: String
    var learningStage: String
    var isVIP: Bool
    var lastLoginAt: Date
    var version: Int
    var lastSyncedAt: Date?
    var isDeleted: Bool
    
    // 標準初始化方法
    init(id: String, email: String, username: String, motivationalQuote: String, 
         targetDate: Date, userGoal: String, learningStage: String, isVIP: Bool, 
         lastLoginAt: Date, version: Int, lastSyncedAt: Date?, isDeleted: Bool) {
        self.id = id
        self.email = email
        self.username = username
        self.motivationalQuote = motivationalQuote
        self.targetDate = targetDate
        self.userGoal = userGoal
        self.learningStage = learningStage
        self.isVIP = isVIP
        self.lastLoginAt = lastLoginAt
        self.version = version
        self.lastSyncedAt = lastSyncedAt
        self.isDeleted = isDeleted
    }
    
    // 預設值初始化
    static func defaultProfile() -> UserProfile {
        UserProfile(
            id: UUID().uuidString,
            email: "",
            username: "新用戶",
            motivationalQuote: "開始你的學習之旅吧！",
            targetDate: Date().addingTimeInterval(180 * 24 * 60 * 60), // 180天後
            userGoal: "",
            learningStage: "大學",
            isVIP: false,
            lastLoginAt: Date(),
            version: 1,
            lastSyncedAt: nil,
            isDeleted: false
        )
    }
    
    // Firestore 初始化方法
    init?(documentId: String, data: [String: Any]) {
        guard let email = data["email"] as? String,
              let username = data["username"] as? String,
              let motivationalQuote = data["motivationalQuote"] as? String,
              let targetDate = (data["targetDate"] as? Timestamp)?.dateValue(),
              let userGoal = data["userGoal"] as? String,
              let learningStage = data["learningStage"] as? String,
              let isVIP = data["isVIP"] as? Bool,
              let lastLoginAt = (data["lastLoginAt"] as? Timestamp)?.dateValue(),
              let version = data["version"] as? Int else {
            return nil
        }
        
        self.id = documentId
        self.email = email
        self.username = username
        self.motivationalQuote = motivationalQuote
        self.targetDate = targetDate
        self.userGoal = userGoal
        self.learningStage = learningStage
        self.isVIP = isVIP
        self.lastLoginAt = lastLoginAt
        self.version = version
        self.lastSyncedAt = (data["lastSyncedAt"] as? Timestamp)?.dateValue()
        self.isDeleted = data["isDeleted"] as? Bool ?? false
    }
    
    // Firestore 資料轉換
    var toFirestore: [String: Any] {
        var data: [String: Any] = [
            "email": email,
            "username": username,
            "motivationalQuote": motivationalQuote,
            "targetDate": Timestamp(date: targetDate),
            "userGoal": userGoal,
            "learningStage": learningStage,
            "isVIP": isVIP,
            "lastLoginAt": Timestamp(date: lastLoginAt),
            "version": version,
            "isDeleted": isDeleted
        ]
        
        if let lastSyncedAt = lastSyncedAt {
            data["lastSyncedAt"] = Timestamp(date: lastSyncedAt)
        }
        
        return data
    }
} 