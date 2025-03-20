import Foundation
import SwiftUI

// 全局數據存儲，用於在不同視圖間共享數據
class AppDataStore: ObservableObject {
    @Published var todoItems: [TodoItem] = []
    
    // 添加新的待辦事項
    func addTodoItems(_ items: [TodoItem]) {
        // 合併新項目，避免重複
        for item in items {
            if !todoItems.contains(where: { $0.id == item.id }) {
                todoItems.append(item)
            }
        }
    }
    
    // 清除所有待辦事項
    func clearTodoItems() {
        todoItems.removeAll()
    }
} 