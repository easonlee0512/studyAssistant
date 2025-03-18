import SwiftUI
import Charts

struct StatisticsView: View {
    var todos: [Date: [(task: String, isCompleted: Bool)]]
    
    var totalTasks: Int {
        todos.values.flatMap { $0 }.count
    }
    
    var completedTasks: Int {
        todos.values.flatMap { $0 }.filter { $0.isCompleted }.count
    }
    
    var remainingTasks: Int {
        totalTasks - completedTasks
    }
    
    var dailyStats: [(date: Date, count: Int)] {
        todos.map { (date: Calendar.current.startOfDay(for: $0.key), count: $0.value.count) }
            .sorted { $0.date < $1.date }
    }

    var body: some View {
        NavigationStack {
            VStack {
                Text("待辦事項統計")
                    .font(.title)
                    .padding()
                
                HStack {
                    VStack {
                        Text("總數")
                            .font(.headline)
                        Text("\(totalTasks)")
                            .font(.largeTitle)
                    }
                    .frame(maxWidth: .infinity)
                    
                    VStack {
                        Text("已完成")
                            .font(.headline)
                        Text("\(completedTasks)")
                            .font(.largeTitle)
                            .foregroundColor(.green)
                    }
                    .frame(maxWidth: .infinity)
                    
                    VStack {
                        Text("未完成")
                            .font(.headline)
                        Text("\(remainingTasks)")
                            .font(.largeTitle)
                            .foregroundColor(.red)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding()
                
                // Chart 顯示每日待辦數量
                Chart(dailyStats, id: \.date) { data in
                    LineMark(
                        x: .value("日期", data.date),
                        y: .value("待辦數量", data.count)
                    )
                    .foregroundStyle(.blue)
                }
                .frame(height: 300)
                .padding()
                
                Spacer()
            }
            .padding()
            .navigationTitle("統計資料")
        }
    }
}

// MARK: - 預覽數據
#Preview {
    let calendar = Calendar.current
    let mockTodos: [Date: [(task: String, isCompleted: Bool)]] = [
        calendar.startOfDay(for: calendar.date(from: DateComponents(year: 2025, month: 3, day: 15))!): [
            ("買牛奶", false), ("運動", true)
        ],
        calendar.startOfDay(for: calendar.date(from: DateComponents(year: 2025, month: 3, day: 16))!): [
            ("完成 Swift 專案", false)
        ],
        calendar.startOfDay(for: calendar.date(from: DateComponents(year: 2025, month: 3, day: 17))!): [
            ("讀書", true), ("跑步", false), ("整理房間", false)
        ]
    ]
    
    return StatisticsView(todos: mockTodos)
}
