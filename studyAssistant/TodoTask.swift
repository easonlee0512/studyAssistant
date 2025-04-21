import SwiftUI

struct TodoTask: Identifiable, Equatable {
    let id = UUID()
    var title: String
    var note: String
    var startDate: Date
    var color: Color
    var isCompleted: Bool
    
    // 实现Equatable协议的要求
    static func == (lhs: TodoTask, rhs: TodoTask) -> Bool {
        return lhs.id == rhs.id &&
               lhs.title == rhs.title &&
               lhs.note == rhs.note &&
               lhs.startDate == rhs.startDate &&
               lhs.isCompleted == rhs.isCompleted
    }
} 