import Foundation
import FirebaseFirestore

struct AppSettings: Codable {
    var id: String
    var notificationsEnabled: Bool
    var lastModified: Date
    
    // 預設值初始化
    static func defaultSettings() -> AppSettings {
        AppSettings(
            id: UUID().uuidString,
            notificationsEnabled: true,
            lastModified: Date()
        )
    }
    
    // Firestore 初始化方法
    init?(documentId: String, data: [String: Any]) {
        guard let notificationsEnabled = data["notificationsEnabled"] as? Bool,
              let lastModified = (data["lastModified"] as? Timestamp)?.dateValue() else {
            return nil
        }
        
        self.id = documentId
        self.notificationsEnabled = notificationsEnabled
        self.lastModified = lastModified
    }
    
    // 普通初始化方法
    init(id: String, notificationsEnabled: Bool, lastModified: Date) {
        self.id = id
        self.notificationsEnabled = notificationsEnabled
        self.lastModified = lastModified
    }
    
    // Firestore 資料轉換
    var toFirestore: [String: Any] {
        return [
            "notificationsEnabled": notificationsEnabled,
            "lastModified": Timestamp(date: lastModified)
        ]
    }
} 