//
//  CalendarAssistantViewModel.swift
//  studyAssistant
//
//  日曆安排助手的 ViewModel
//  仿照 ChatViewModel 但不需要即時文字串流，只需要 function calling
//

import FirebaseAuth
import FirebaseFirestore
import Foundation
import SwiftUI

@MainActor
final class CalendarAssistantViewModel: ObservableObject {
    private let proxyURL = URL(string: "https://asia-east1-studyassistant-f7172.cloudfunctions.net/chatProxy")!

    @Published var staticViewModel: StaticViewModel?
    @Published var todoViewModel = TodoViewModel()

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // 狀態追蹤
    @Published var isUpdating: Bool = false
    @Published var updateError: String?
    @Published var currentStatus: String = ""  // 當前狀態描述

    // 任務變動追蹤
    @Published var addedTasks: [PendingTask] = []
    @Published var deletedTasks: [TodoTask] = []
    @Published var updatedTasks: [(original: TodoTask, updated: PendingTask)] = []

    // Firestore 相關
    private let db = Firestore.firestore()
    private let studySettingsCollection = "studySettings"

    // 使用者讀書設定
    @Published var studySettings: StudySettings?
    @Published var isLoadingSettings: Bool = false
    @Published var settingsError: String?

    // 定義 getTask 函數
    private let getTaskFunction = Tool(
        type: "function",
        function: ToolFunction(
            name: "getTask",
            description: "Get all tasks from the system",
            parameters: ToolFunction.Parameters(
                type: "object",
                properties: [:],
                required: []
            )
        )
    )

    // 定義 getTime 函數
    private let getTimeFunction = Tool(
        type: "function",
        function: ToolFunction(
            name: "getTime",
            description: "Get current time from the system",
            parameters: ToolFunction.Parameters(
                type: "object",
                properties: [:],
                required: []
            )
        )
    )

    // 定義 saveTask 函數
    private let saveTaskFunction = Tool(
        type: "function",
        function: ToolFunction(
            name: "saveTask",
            description: "Save one or multiple tasks to the system. All fields are required for each task.",
            parameters: ToolFunction.Parameters(
                type: "object",
                properties: [
                    "tasks": .init(
                        type: "array",
                        description: "Array of tasks to save. Each task must include all required fields.",
                        items: .init(
                            type: "object",
                            properties: [
                                "title": .init(type: "string", description: "Task title (required)"),
                                "note": .init(type: "string", description: "Task note (required)"),
                                "category": .init(type: "string", description: "Task category (required), Based on these tasks, assign an overall category,based on the all task's title and note"),
                                "startDate": .init(type: "string", description: "Start date in ISO 8601 format (required)"),
                                "endDate": .init(type: "string", description: "End date in ISO 8601 format (required)"),
                                "isAllDay": .init(type: "string", description: "Whether the task is all day, must be 'true' or 'false' (required)"),
                                "isCompleted": .init(type: "string", description: "Whether the task is completed, must be 'true' or 'false' (required)"),
                                "color": .init(
                                    type: "string",
                                    description: """
                                        Task color must be one of these four options:
                                        - '0.7,0.16,0.13,0.4' (Red)
                                        - '0.7,0.56,0,0.4' (Yellow)
                                        - '0.18,0.7,0.31,0.4' (Green)
                                        - '0.29,0.28,0.7,0.4' (Blue)
                                        Choose a color based on the task category:
                                        - Red: Urgent or important tasks
                                        - Yellow: Medium priority tasks
                                        - Green: Learning or growth tasks
                                        - Blue: Routine or regular tasks
                                        """
                                )
                            ]
                        )
                    )
                ],
                required: ["tasks"]
            )
        )
    )

    // 定義 deleteTask 函數
    private let deleteTaskFunction = Tool(
        type: "function",
        function: ToolFunction(
            name: "deleteTask",
            description: "Delete one or multiple tasks by their IDs",
            parameters: ToolFunction.Parameters(
                type: "object",
                properties: [
                    "taskIds": .init(
                        type: "array",
                        description: "Array of task IDs to delete",
                        items: .init(type: "string")
                    )
                ],
                required: ["taskIds"]
            )
        )
    )

    // 定義 updateTask 函數
    private let updateTaskFunction = Tool(
        type: "function",
        function: ToolFunction(
            name: "updateTask",
            description: "Update one or multiple existing tasks with new information",
            parameters: ToolFunction.Parameters(
                type: "object",
                properties: [
                    "tasks": .init(
                        type: "array",
                        description: "Array of tasks to update",
                        items: .init(
                            type: "object",
                            properties: [
                                "taskId": .init(type: "string", description: "ID of the task to update (required)"),
                                "title": .init(type: "string", description: "New task title"),
                                "note": .init(type: "string", description: "New task note"),
                                "category": .init(type: "string", description: "New task category"),
                                "startDate": .init(type: "string", description: "New start date in ISO 8601 format"),
                                "endDate": .init(type: "string", description: "New end date in ISO 8601 format"),
                                "isAllDay": .init(type: "string", description: "Whether the task is all day, must be 'true' or 'false'"),
                                "isCompleted": .init(type: "string", description: "Whether the task is completed, must be 'true' or 'false'"),
                                "color": .init(
                                    type: "string",
                                    description: """
                                        Task color must be one of these four options:
                                        - '0.7,0.16,0.13,0.4' (Red)
                                        - '0.7,0.56,0,0.4' (Yellow)
                                        - '0.18,0.7,0.31,0.4' (Green)
                                        - '0.29,0.28,0.7,0.4' (Blue)
                                        """
                                )
                            ]
                        )
                    )
                ],
                required: ["tasks"]
            )
        )
    )

    // 定義 endConversation 函數
    private let endConversationFunction = Tool(
        type: "function",
        function: ToolFunction(
            name: "end_conversation",
            description: "End the current conversation after completing all task operations.",
            parameters: ToolFunction.Parameters(
                type: "object",
                properties: [:],
                required: []
            )
        )
    )

    init() {
        Task {
            await loadStudySettingsFromFirestore()
        }
    }

    // MARK: - 主要更新方法

    /// 開始更新日曆任務
    func startUpdate(userInput: String) async {
        isUpdating = true
        updateError = nil
        currentStatus = "正在初始化..."

        // 清空之前的結果
        addedTasks = []
        deletedTasks = []
        updatedTasks = []

        // 建構系統提示
        let systemPrompt = buildSystemPrompt()

        // 建構初始訊息
        let systemMessage = OpenAIMessage(role: "system", content: systemPrompt)
        let userMessage = OpenAIMessage(role: "user", content: userInput)
        var messages = [systemMessage, userMessage]

        var roundCount = 0
        let maxRounds = 15
        var endConversationReached = false

        print("\n" + String(repeating: "=", count: 80))
        print("📅 日曆助手開始處理")
        print(String(repeating: "=", count: 80))
        print("👤 使用者輸入：\(userInput)")
        print(String(repeating: "-", count: 80))
        print("🤖 系統提示（前500字元）：\(systemPrompt.prefix(500))...")
        print(String(repeating: "=", count: 80) + "\n")

        currentStatus = "正在分析您的需求..."

        while !endConversationReached && roundCount < maxRounds {
            roundCount += 1
            print("\n" + String(repeating: "─", count: 80))
            print("🔄 第 \(roundCount)/\(maxRounds) 輪對話")
            print(String(repeating: "─", count: 80))

            // 更新狀態顯示當前處理的任務變動數量
            var statusParts: [String] = []
            if addedTasks.count > 0 {
                statusParts.append("新增 \(addedTasks.count)")
            }
            if deletedTasks.count > 0 {
                statusParts.append("刪除 \(deletedTasks.count)")
            }
            if updatedTasks.count > 0 {
                statusParts.append("修改 \(updatedTasks.count)")
            }

            if statusParts.isEmpty {
                currentStatus = "正在分析任務... (\(roundCount)/\(maxRounds))"
            } else {
                currentStatus = "已\(statusParts.joined(separator: "、"))個任務 (\(roundCount)/\(maxRounds))"
            }
            print("📊 目前狀態：\(currentStatus)")

            // 呼叫 GPT
            let reqBody = OpenAIRequest(
                model: "gpt-4.1",
                messages: messages,
                temperature: 0.7,
                stream: false,
                tools: [getTaskFunction, getTimeFunction, saveTaskFunction, deleteTaskFunction, updateTaskFunction, endConversationFunction],
                tool_choice: roundCount == 1 ? "required" : "auto",
                stream_options: nil
            )

            guard let data = try? encoder.encode(reqBody) else {
                updateError = "編碼請求失敗"
                isUpdating = false
                return
            }

            var req = URLRequest(url: proxyURL)
            req.httpMethod = "POST"
            req.addValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = data

            do {
                let (respData, resp) = try await retryOnError {
                    try await URLSession.shared.data(for: req)
                }

                guard let httpResponse = resp as? HTTPURLResponse else {
                    updateError = "無效的回應"
                    isUpdating = false
                    return
                }

                if httpResponse.statusCode != 200 {
                    // 嘗試解析錯誤回應
                    if let errorString = String(data: respData, encoding: .utf8) {
                        print("伺服器錯誤回應：\(errorString)")
                    }
                    updateError = "伺服器錯誤：\(httpResponse.statusCode)"
                    isUpdating = false
                    return
                }

                // 列印回應內容以便除錯（僅在開發模式）
                #if DEBUG
                if let responseString = String(data: respData, encoding: .utf8) {
                    print("API回應：\(responseString)")
                }
                #endif

                // 解析回應
                guard let response = try? decoder.decode(OpenAIResponse.self, from: respData) else {
                    print("解析回應失敗，原始資料長度：\(respData.count) bytes")
                    if let responseString = String(data: respData, encoding: .utf8) {
                        print("回應內容：\(responseString)")
                    }
                    updateError = "解析回應失敗，請檢查網路連線"
                    isUpdating = false
                    return
                }

                guard let choice = response.choices.first else {
                    print("回應中沒有 choices")
                    updateError = "回應格式錯誤"
                    isUpdating = false
                    return
                }

                // 處理 tool calls
                if let toolCalls = choice.message.tool_calls, !toolCalls.isEmpty {
                    print("\n🔧 收到 \(toolCalls.count) 個函數呼叫")

                    // 將助手訊息加入對話歷史
                    messages.append(choice.message)

                    // 執行每個函數呼叫
                    for (index, toolCall) in toolCalls.enumerated() {
                        let functionName = toolCall.function.name
                        let arguments = toolCall.function.arguments

                        print("\n  [\(index + 1)/\(toolCalls.count)] 🛠️  函數名稱：\(functionName)")
                        if !arguments.isEmpty && arguments != "{}" {
                            print("  📝 參數：\(arguments.prefix(200))\(arguments.count > 200 ? "..." : "")")
                        }

                        // 執行函數
                        let result = await handleToolCall(functionName: functionName, arguments: arguments)

                        // 檢查是否結束對話
                        if functionName == "end_conversation" {
                            endConversationReached = true
                            print("  ✅ 對話結束")
                        }

                        // 將函數結果加入訊息歷史
                        let toolMessage = OpenAIMessage(
                            role: "tool",
                            content: result,
                            name: nil,
                            tool_calls: nil,
                            tool_call_id: toolCall.id
                        )
                        messages.append(toolMessage)

                        print("  📤 函數結果：\(result.prefix(200))\(result.count > 200 ? "..." : "")")
                    }
                } else {
                    // 若沒有 tool calls，只有文字回覆，繼續下一輪
                    let content = choice.message.content
                    if !content.isEmpty {
                        print("\n💬 GPT 回覆：\(content)")
                    }
                    messages.append(choice.message)
                }

            } catch {
                print("\n❌ 錯誤發生：\(error.localizedDescription)")
                updateError = "請求失敗：\(error.localizedDescription)"
                isUpdating = false
                return
            }
        }

        print("\n" + String(repeating: "=", count: 80))
        if roundCount >= maxRounds && !endConversationReached {
            print("⚠️  警告：已達到最大輪次限制（15輪）")
            currentStatus = "已達到最大處理輪次"
        } else {
            print("✅ 處理完成")
            currentStatus = "處理完成"
        }

        print(String(repeating: "=", count: 80))
        print("📊 最終結果統計：")
        print("   ➕ 新增任務：\(addedTasks.count) 個")
        print("   ➖ 刪除任務：\(deletedTasks.count) 個")
        print("   ✏️  修改任務：\(updatedTasks.count) 個")
        print("   🔄 總輪次：\(roundCount) 輪")
        print(String(repeating: "=", count: 80) + "\n")

        isUpdating = false
    }

    // MARK: - Function Execution

    private func handleToolCall(functionName: String, arguments: String) async -> String {
        switch functionName {
        case "getTask":
            return await executeGetTask()
        case "getTime":
            return executeGetTime()
        case "saveTask":
            return await executeSaveTask(arguments: arguments)
        case "deleteTask":
            return await executeDeleteTask(arguments: arguments)
        case "updateTask":
            return await executeUpdateTask(arguments: arguments)
        case "end_conversation":
            return "對話結束"
        default:
            return "未知函數：\(functionName)"
        }
    }

    // 執行 getTime 函數
    private func executeGetTime() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        let currentTime = formatter.string(from: Date())
        return "現在時間是：\(currentTime)"
    }

    // 執行 getTask 函數
    private func executeGetTask() async -> String {
        let firebaseService = FirebaseService.shared
        do {
            let tasks = try await firebaseService.fetchTodoTasks()

            var taskString: String
            if tasks.isEmpty {
                taskString = "目前沒有任何任務。"
            } else {
                let today = Date()
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy/MM/dd HH:mm"
                let todayString = formatter.string(from: today)
                taskString = "今日日期: \(todayString)\n"
                taskString += "allTasks:\n"
                for task in tasks {
                    taskString += "-------\n"
                    taskString += "id:\(task.id) "
                    taskString += "title:\(task.title) "
                    taskString += "isCompleted:\(task.isCompleted) "
                    if !task.note.isEmpty {
                        taskString += "note:\(task.note) "
                    }
                    taskString += "startTime:\(formatDate(task.startDate)) "
                    taskString += "endTime:\(formatDate(task.endDate))\n\n"
                }
            }
            return taskString
        } catch {
            return "抱歉，無法取得任務列表。請確保您已登入並且網路連線正常。"
        }
    }

    // 執行儲存任務函數
    private func executeSaveTask(arguments: String) async -> String {
        struct TaskArgs: Codable {
            let title: String
            let note: String
            let startDate: String
            let endDate: String
            let category: String?
            let isAllDay: String?
            let isCompleted: String?
            let color: String?

            var resolvedCategory: String { category ?? "未分類" }
            var resolvedIsAllDay: String { isAllDay ?? "false" }
            var resolvedIsCompleted: String { isCompleted ?? "false" }

            func resolveColor() -> Color {
                guard let colorStr = color else {
                    return Color(red: 0.7, green: 0.16, blue: 0.13).opacity(0.4)
                }
                let components = colorStr.split(separator: ",").compactMap {
                    Double($0.trimmingCharacters(in: .whitespaces))
                }
                guard components.count == 4 else {
                    return Color(red: 0.7, green: 0.16, blue: 0.13).opacity(0.4)
                }
                return Color(red: components[0], green: components[1], blue: components[2]).opacity(components[3])
            }
        }

        struct SaveTasksArgs: Codable {
            let tasks: [TaskArgs]
        }

        do {
            guard let jsonData = arguments.data(using: .utf8) else {
                return "無法解析任務參數"
            }

            let args = try JSONDecoder().decode(SaveTasksArgs.self, from: jsonData)
            var successCount = 0
            var failureCount = 0

            for task in args.tasks {
                guard let startDate = parseDate(task.startDate),
                      let endDate = parseDate(task.endDate) else {
                    failureCount += 1
                    continue
                }

                let isAllDayBool = task.resolvedIsAllDay.lowercased() == "true"
                let isCompletedBool = task.resolvedIsCompleted.lowercased() == "true"
                let taskColor = task.resolveColor()

                let pendingTask = PendingTask(
                    title: task.title,
                    note: task.note,
                    category: task.resolvedCategory,
                    startDate: startDate,
                    endDate: endDate,
                    isAllDay: isAllDayBool,
                    isCompleted: isCompletedBool,
                    color: taskColor
                )

                // 檢查並建立類別統計
                await checkAndCreateStatisticsForCategory(task.resolvedCategory)

                // 直接儲存任務
                do {
                    let todoTask = TodoTask(
                        title: task.title,
                        note: task.note,
                        color: taskColor,
                        focusTime: 0,
                        category: task.resolvedCategory,
                        isAllDay: isAllDayBool,
                        isCompleted: isCompletedBool,
                        repeatType: .none,
                        startDate: startDate,
                        endDate: endDate,
                        userId: ""
                    )

                    await todoViewModel.addTask(todoTask)

                    // 立即更新追蹤列表並觸發 UI 更新
                    await MainActor.run {
                        self.addedTasks.append(pendingTask)
                        self.updateCurrentStatus()
                    }

                    successCount += 1
                    print("    ✅ 已新增任務：\(task.title)")
                } catch {
                    print("    ❌ 儲存任務失敗: \(error)")
                    failureCount += 1
                }
            }

            if successCount > 0 {
                return "已成功新增 \(successCount) 個任務" + (failureCount > 0 ? "，\(failureCount) 個任務新增失敗" : "")
            } else {
                return "任務新增失敗"
            }
        } catch {
            print("解析參數時發生錯誤：\(error)")
            return "解析任務參數時發生錯誤：\(error.localizedDescription)"
        }
    }

    // 執行刪除任務函數
    private func executeDeleteTask(arguments: String) async -> String {
        struct DeleteTaskArgs: Codable {
            let taskIds: [String]
        }

        do {
            guard let jsonData = arguments.data(using: .utf8) else {
                return "無法解析任務參數"
            }

            let args = try JSONDecoder().decode(DeleteTaskArgs.self, from: jsonData)
            var tasksToDelete: [TodoTask] = []
            let allTasks = todoViewModel.tasks
            var successCount = 0
            var failureCount = 0

            for taskId in args.taskIds {
                if let task = allTasks.first(where: { $0.id == taskId }) {
                    tasksToDelete.append(task)
                    do {
                        try await todoViewModel.deleteTask(task)

                        // 立即更新狀態
                        await MainActor.run {
                            self.deletedTasks.append(task)
                            self.updateCurrentStatus()
                        }

                        successCount += 1
                        print("    ✅ 已刪除任務：\(task.title)")
                    } catch {
                        print("    ❌ 刪除任務失敗: \(error)")
                        failureCount += 1
                    }
                }
            }

            if tasksToDelete.isEmpty {
                return "找不到指定的任務"
            }

            // 注意：已在上面的迴圈中即時更新 deletedTasks，這裡不需要重複添加

            if successCount > 0 {
                return "已成功刪除 \(successCount) 個任務" + (failureCount > 0 ? "，\(failureCount) 個任務刪除失敗" : "")
            } else {
                return "任務刪除失敗"
            }
        } catch {
            print("解析參數時發生錯誤：\(error)")
            return "解析任務參數時發生錯誤：\(error.localizedDescription)"
        }
    }

    // 執行更新任務函數
    private func executeUpdateTask(arguments: String) async -> String {
        struct UpdateTaskArg: Codable {
            let taskId: String
            let title: String?
            let note: String?
            let category: String?
            let startDate: String?
            let endDate: String?
            let isAllDay: String?
            let isCompleted: String?
            let color: String?
        }

        struct UpdateTasksArgs: Codable {
            let tasks: [UpdateTaskArg]
        }

        do {
            guard let jsonData = arguments.data(using: .utf8) else {
                return "無法解析任務參數"
            }

            let args = try JSONDecoder().decode(UpdateTasksArgs.self, from: jsonData)
            if args.tasks.isEmpty {
                return "未提供任何要更新的任務"
            }

            let allTasks = todoViewModel.tasks
            var successCount = 0
            var failureCount = 0

            for taskArg in args.tasks {
                guard let originalTask = allTasks.first(where: { $0.id == taskArg.taskId }) else {
                    print("找不到 ID 為 \(taskArg.taskId) 的任務")
                    failureCount += 1
                    continue
                }

                let updatedTask = PendingTask(
                    title: taskArg.title ?? originalTask.title,
                    note: taskArg.note ?? originalTask.note,
                    category: taskArg.category ?? originalTask.category,
                    startDate: parseDate(taskArg.startDate) ?? originalTask.startDate,
                    endDate: parseDate(taskArg.endDate) ?? originalTask.endDate,
                    isAllDay: taskArg.isAllDay?.lowercased() == "true" ? true :
                             (taskArg.isAllDay?.lowercased() == "false" ? false : originalTask.isAllDay),
                    isCompleted: taskArg.isCompleted?.lowercased() == "true" ? true :
                               (taskArg.isCompleted?.lowercased() == "false" ? false : originalTask.isCompleted),
                    color: parseColor(taskArg.color) ?? originalTask.color
                )

                do {
                    var updatedTodoTask = originalTask
                    updatedTodoTask.title = updatedTask.title
                    updatedTodoTask.note = updatedTask.note
                    updatedTodoTask.category = updatedTask.category
                    updatedTodoTask.startDate = updatedTask.startDate
                    updatedTodoTask.endDate = updatedTask.endDate
                    updatedTodoTask.isAllDay = updatedTask.isAllDay
                    updatedTodoTask.isCompleted = updatedTask.isCompleted
                    updatedTodoTask.color = updatedTask.color

                    try await todoViewModel.updateTask(updatedTodoTask)

                    // 立即更新狀態
                    await MainActor.run {
                        self.updatedTasks.append((original: originalTask, updated: updatedTask))
                        self.updateCurrentStatus()
                    }

                    successCount += 1
                    print("    ✅ 已更新任務：\(updatedTask.title)")
                } catch {
                    print("    ❌ 更新任務失敗: \(error)")
                    failureCount += 1
                }
            }

            if successCount > 0 {
                return "已成功更新 \(successCount) 個任務" + (failureCount > 0 ? "，\(failureCount) 個任務更新失敗" : "")
            } else {
                return "任務更新失敗"
            }
        } catch {
            print("解析參數時發生錯誤：\(error)")
            return "解析任務參數時發生錯誤：\(error.localizedDescription)"
        }
    }

    // MARK: - Helper Methods

    /// 更新當前狀態顯示
    private func updateCurrentStatus() {
        var statusParts: [String] = []
        if addedTasks.count > 0 {
            statusParts.append("新增 \(addedTasks.count)")
        }
        if deletedTasks.count > 0 {
            statusParts.append("刪除 \(deletedTasks.count)")
        }
        if updatedTasks.count > 0 {
            statusParts.append("修改 \(updatedTasks.count)")
        }

        if statusParts.isEmpty {
            currentStatus = "正在處理中..."
        } else {
            currentStatus = "已\(statusParts.joined(separator: "、"))個任務"
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: date)
    }

    private func parseDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }

        let dateFormats = [
            "yyyy-MM-dd'T'HH:mm:ssXXX",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd'T'HH:mmXXX",
            "yyyy-MM-dd'T'HH:mm"
        ]

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone.current

        for format in dateFormats {
            dateFormatter.dateFormat = format
            if let date = dateFormatter.date(from: dateString) {
                return date
            }
        }

        if dateString.contains("+") || dateString.contains("-") {
            let components = dateString.components(separatedBy: CharacterSet(charactersIn: "+-"))
            if let basicString = components.first {
                return parseDate(basicString)
            }
        }

        return nil
    }

    private func parseColor(_ colorString: String?) -> Color? {
        guard let colorStr = colorString else { return nil }
        let components = colorStr.split(separator: ",").compactMap {
            Double($0.trimmingCharacters(in: .whitespaces))
        }
        guard components.count == 4 else { return nil }
        return Color(red: components[0], green: components[1], blue: components[2]).opacity(components[3])
    }

    private func checkAndCreateStatisticsForCategory(_ category: String) async {
        guard let staticViewModel = staticViewModel else { return }
        guard !category.isEmpty && category != "未分類" else { return }

        let existingCategories = staticViewModel.statistics.map { $0.category }
        if !existingCategories.contains(category) {
            print("正在為新類別 \(category) 建立統計紀錄")
            let newStatistic = LearningStatistic(
                userId: Auth.auth().currentUser?.uid ?? "default",
                category: category,
                progress: 0.0,
                taskcount: 1,
                taskcompletecount: 0,
                totalFocusTime: 0,
                date: Date(),
                updatedAt: Date(),
                version: 1
            )
            let result = await staticViewModel.saveStatistic(newStatistic)
            if result {
                print("已成功為新類別 \(category) 建立統計紀錄")
            } else {
                print("建立統計紀錄失敗：\(staticViewModel.errorMessage ?? "未知錯誤")")
            }
        }
    }

    private func buildSystemPrompt() -> String {
        let tone = studySettings?.tone ?? "沉著穩重的專家"
        let currentTimeString = formatCurrentTime()
        var prompt = """
            你是一位日曆安排助手，會根據使用者的需求自動調整日曆任務。語氣為：\(tone)

            \(formatStudySettings())

            目前系統時間：\(currentTimeString)

            你的目標是：
            1. 根據需求新增、刪除或修改任務
            2. 完成所有操作後立即呼叫 end_conversation

            重要規則：
            1. **最多執行 15 輪操作**
            2. 如果使用者沒有指定特別時段，安排任務時間時必須遵守以下規則：
                - 只能在使用者設定的可讀書日期和時間內安排任務
                - 每個任務的持續時間應為設定的讀書時間（\(studySettings?.studyDuration ?? 60)分鐘）
                - 不要在設定的時間範圍外安排任務
                - 不要與原有的任務時間重疊
            3. 安排任務時如果使用者要求安排很多任務（例如一兩百個任務），必須遵從使用者的需求一次安排完成。
            4. 沒有指定時間即為現在。
            """

        let existingTasksInfo = formatExistingTasks()
        if !existingTasksInfo.isEmpty {
            prompt += "\n\(existingTasksInfo)"
        }

        return prompt
    }

    private func formatStudySettings() -> String {
        guard let settings = studySettings else { return "" }
        var result = ""

        if settings.isStudyDatePreferenceEnabled {
            result += "使用者的讀書習慣設定：\n讀書時段如下：\n"
            if settings.selectedDays.isEmpty {
                result += "未設定可讀書的日期。\n"
            } else {
                for day in settings.selectedDays.sorted() {
                    let dayString = String(day)
                    if let startHour = settings.dailyStartHours[dayString],
                       let startMinute = settings.dailyStartMinutes[dayString],
                       let endHour = settings.dailyEndHours[dayString],
                       let endMinute = settings.dailyEndMinutes[dayString] {
                        let weekday = switch day {
                            case 1: "星期一"
                            case 2: "星期二"
                            case 3: "星期三"
                            case 4: "星期四"
                            case 5: "星期五"
                            case 6: "星期六"
                            case 7: "星期日"
                            default: "未知"
                        }
                        result += "\(weekday)：\(String(format: "%02d:%02d", startHour, startMinute)) - \(String(format: "%02d:%02d", endHour, endMinute))\n"
                    }
                }
            }
        }

        if settings.isStudyTimePreferenceEnabled {
            if result.isEmpty {
                result += "使用者的讀書習慣設定：\n"
            }
            result += "每次讀書時間：\(Int(settings.studyDuration))分鐘\n"
        }

        if result.isEmpty {
            return ""
        } else {
            if result.hasSuffix("\n") {
                result.removeLast()
            }
        }

        return result
    }

    private func formatCurrentTime() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: Date())
    }

    private func formatExistingTasks() -> String {
        let tasks = todoViewModel.tasks
        guard !tasks.isEmpty else { return "目前沒有任何既有任務。" }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"

        var result = "目前系統中的任務列表：\n"
        for task in tasks {
            result += "- 任務ID：\(task.id)\n"
            result += "  標題：\(task.title)\n"
            if !task.note.isEmpty {
                result += "  備註：\(task.note)\n"
            }
            result += "  類別：\(task.category)\n"
            result += "  完成狀態：\(task.isCompleted ? "已完成" : "未完成")\n"
            result += "  全天：\(task.isAllDay ? "是" : "否")\n"
            result += "  開始時間：\(formatter.string(from: task.startDate))\n"
            result += "  結束時間：\(formatter.string(from: task.endDate))\n"
            result += "-------\n"
        }

        if result.hasSuffix("\n") {
            result.removeLast()
        }

        return result
    }

    // MARK: - Study Settings

    func loadStudySettingsFromFirestore() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            settingsError = "尚未登入，無法載入讀書設定"
            return
        }

        isLoadingSettings = true
        settingsError = nil

        do {
            let docRef = db.collection(studySettingsCollection).document(userId)
            let document = try await docRef.getDocument()

            if document.exists, let settings = StudySettings(document: document) {
                self.studySettings = settings
                print("成功從Firestore載入讀書設定")
            } else {
                print("無現有讀書設定，建立預設值")
                let newSettings = StudySettings(userId: userId)
                self.studySettings = newSettings
                try await saveStudySettingsToFirestore(settings: newSettings)
            }
        } catch {
            settingsError = "載入讀書設定失敗: \(error.localizedDescription)"
            print("載入讀書設定錯誤: \(error)")
        }

        isLoadingSettings = false
    }

    private func saveStudySettingsToFirestore(settings: StudySettings) async throws {
        guard !settings.userId.isEmpty else {
            throw NSError(domain: "app.studyAssistant", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "未指定使用者ID"])
        }

        let docRef = db.collection(studySettingsCollection).document(settings.userId)
        var settingsToSave = settings
        settingsToSave.updatedAt = Timestamp()
        try await docRef.setData(settingsToSave.toFirestoreData())
        print("成功儲存讀書設定到Firestore")
    }

    // MARK: - Retry Logic

    private func retryOnError<T>(
        maxAttempts: Int = 3,
        delay: TimeInterval = 1.5,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var attempts = 0
        var lastError: Error?

        while attempts < maxAttempts {
            do {
                if attempts > 0 {
                    let waitTime = delay * Double(attempts)
                    print("等待 \(waitTime) 秒後重試...")
                    try await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
                }

                let result = try await operation()

                if let (_, response) = result as? (Data, URLResponse),
                   let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 429 {
                    print("收到 429 狀態碼")
                    attempts += 1
                    continue
                }

                return result
            } catch let urlError as URLError {
                print("捕獲到 URLError: \(urlError.localizedDescription)")
                lastError = urlError
                attempts += 1
                if attempts >= maxAttempts {
                    throw urlError
                }
                continue
            } catch {
                print("捕獲到其他錯誤: \(error.localizedDescription)")
                lastError = error
                attempts += 1
                if attempts >= maxAttempts {
                    throw error
                }
                continue
            }
        }

        throw lastError ?? URLError(.timedOut)
    }
}
