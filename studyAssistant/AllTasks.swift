import SwiftUI

class AllTasks: ObservableObject {
    @Published var tasks: [TodoTask]

    init() {
        let now = Date()
        self.tasks = [
            TodoTask(
                title: "線性代數",
                note: "備註",
                color: Color(red: 0.7, green: 0.16, blue: 0.13).opacity(0.4),
                focusTime: 30,
                category: "學習",
                isAllDay: false,
                isCompleted: false,
                repeatType: .none,
                startDate: now,
                endDate: Calendar.current.date(byAdding: .hour, value: 1, to: now)!,
                createdAt: now
            ),
            TodoTask(
                title: "離散數學",
                note: "備註",
                color: Color(red: 0.7, green: 0.56, blue: 0).opacity(0.4),
                focusTime: 45,
                category: "學習",
                isAllDay: false,
                isCompleted: false,
                repeatType: .none,
                startDate: now,
                endDate: Calendar.current.date(byAdding: .hour, value: 1, to: now)!,
                createdAt: now
            ),
            TodoTask(
                title: "資料結構",
                note: "復習第四章",
                color: Color(red: 0.18, green: 0.7, blue: 0.31).opacity(0.4),
                focusTime: 60,
                category: "學習",
                isAllDay: false,
                isCompleted: false,
                repeatType: .none,
                startDate: now,
                endDate: Calendar.current.date(byAdding: .hour, value: 2, to: now)!,
                createdAt: now
            ),
            TodoTask(
                title: "計算機結構",
                note: "準備期中考",
                color: Color(red: 0.29, green: 0.28, blue: 0.7).opacity(0.4),
                focusTime: 90,
                category: "學習",
                isAllDay: false,
                isCompleted: true,
                repeatType: .none,
                startDate: now,
                endDate: Calendar.current.date(byAdding: .hour, value: 2, to: now)!,
                createdAt: now
            )
        ]
    }
} 