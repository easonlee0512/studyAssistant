import Foundation
import FirebaseFirestore

struct AppSettings: Codable {
    var id: String
    var isDarkMode: Bool
    var notificationsEnabled: Bool
    var isShockEnabled: Bool
    var lastModified: Date
    
    // 預設值初始化
    static func defaultSettings() -> AppSettings {
        AppSettings(
            id: UUID().uuidString,
            isDarkMode: false,
            notificationsEnabled: true,
            isShockEnabled: true,
            lastModified: Date()
        )
    }
    
    // Firestore 初始化方法
    init?(documentId: String, data: [String: Any]) {
        guard let isDarkMode = data["isDarkMode"] as? Bool,
              let notificationsEnabled = data["notificationsEnabled"] as? Bool,
              let isShockEnabled = data["isShockEnabled"] as? Bool,
              let lastModified = (data["lastModified"] as? Timestamp)?.dateValue() else {
            return nil
        }
        
        self.id = documentId
        self.isDarkMode = isDarkMode
        self.notificationsEnabled = notificationsEnabled
        self.isShockEnabled = isShockEnabled
        self.lastModified = lastModified
    }
    
    // 普通初始化方法
    init(id: String, isDarkMode: Bool, notificationsEnabled: Bool, isShockEnabled: Bool, lastModified: Date) {
        self.id = id
        self.isDarkMode = isDarkMode
        self.notificationsEnabled = notificationsEnabled
        self.isShockEnabled = isShockEnabled
        self.lastModified = lastModified
    }
    
    // Firestore 資料轉換
    var toFirestore: [String: Any] {
        return [
            "isDarkMode": isDarkMode,
            "notificationsEnabled": notificationsEnabled,
            "isShockEnabled": isShockEnabled,
            "lastModified": Timestamp(date: lastModified)
        ]
    }
} 