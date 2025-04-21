// import SwiftUI
// import SwiftUICore

// // MARK: - 任務數據模型
// /// 待辦事項數據模型，包含任務的基本信息
// struct TodoItem: Identifiable {
//     let id = UUID()                // 唯一標識符
//     var title: String              // 任務標題
//     var date: Date                 // 任務日期
//     var startTime: Date            // 開始時間
//     var durationHours: Int         // 持續時間（小時）
//     var isCompleted: Bool          // 完成狀態
//     var color: Color = Color.blue.opacity(0.4) // 任務顏色
//     var shortName: String? {
//         let words = title.split(separator: " ")
//         if words.count > 1 {
//             return String(words[0])
//         }
//         return title.count > 3 ? String(title.prefix(3)) : title
//     }
    
//     // 转换为TodoTask格式
//     func toTodoTask() -> TodoTask {
//         return TodoTask(
//             title: title,
//             note: "持续时间: \(durationHours)小时",
//             startDate: startTime,
//             color: color,
//             isCompleted: isCompleted
//         )
//     }
// }

// // MARK: - 任務列表項視圖
// /// 顯示單個任務的行視圖
// struct TodoItemRow: View {
//     let todo: TodoItem  // 要顯示的任務
    
//     var body: some View {
//         HStack {
//             // 顏色指示器
//             Rectangle()
//                 .fill(todo.color)
//                 .frame(width: 5, height: 40)
//                 .cornerRadius(3)
            
//             VStack(alignment: .leading) {
//                 // 任務標題
//                 Text(todo.title)
//                     .font(.title3)
//                     .bold()
                
//                 // 任務時間信息
//                 Text("\(todo.startTime.formatted(date: .omitted, time: .shortened)) - \(durationText)")
//                     .font(.caption)
//                     .foregroundColor(.gray)
//             }
//             .padding(.leading, 8)
            
//             Spacer()
//         }
//         .padding(.vertical, 5)
//         .padding(.horizontal, 8)
//         .background(todo.color.opacity(0.1))
//         .cornerRadius(8)
//     }
    
//     /// 計算結束時間文本
//     private var durationText: String {
//         let calendar = Calendar.current
//         if let endTime = calendar.date(byAdding: .hour, value: todo.durationHours, to: todo.startTime) {
//             return endTime.formatted(date: .omitted, time: .shortened)
//         }
//         return ""
//     }
// } 