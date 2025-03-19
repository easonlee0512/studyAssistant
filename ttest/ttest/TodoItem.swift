import Foundation

struct TodoItem: Identifiable {
    let id = UUID()
    let title: String
    let date: Date
    let startTime: Date
    let durationHours: Double
    var isCompleted: Bool
    
    init(title: String, date: Date, startTime: Date, durationHours: Double, isCompleted: Bool = false) {
        self.title = title
        self.date = date
        self.startTime = startTime
        self.durationHours = durationHours
        self.isCompleted = isCompleted
    }
} 
