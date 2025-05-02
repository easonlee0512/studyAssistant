import Foundation

// Date 擴充方法
extension Date {
    /// 取得當天 00:00:00
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }
    
    /// 取得當天的結束時間 23:59:59
    var endOfDay: Date {
        let cal = Calendar.current
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return cal.date(byAdding: components, to: startOfDay)!
    }
    
    /// 格式化為 "HH:mm" 形式
    var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: self)
    }
    
    /// 格式化為本地化日期
    var localizedDateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }
} 