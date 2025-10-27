//
//  CalendarAssistantViewModel.swift
//  studyAssistant
//
//  日曆安排助手的 ViewModel
//  仿照 ChatViewModel 但不需要即時文字串流，只需要 function calling
//

import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import Foundation
import SwiftUI

@MainActor
final class CalendarAssistantViewModel: ObservableObject {
    // 單例模式 - 確保在背景執行不會被中斷
    static let shared = CalendarAssistantViewModel()

    private let proxyURL = URL(string: "https://asia-east1-studyassistant-f7172.cloudfunctions.net/chatProxy")!
    private let functions = Functions.functions(region: "asia-east1")

    @Published var staticViewModel: StaticViewModel?
    @Published var todoViewModel: TodoViewModel?

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // 自訂 URLSession，設定長時間 timeout（10 分鐘）以配合 Cloud Function
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 600   // 單次請求超時：10 分鐘（600 秒）
        config.timeoutIntervalForResource = 3600 // 整體資源超時：1 小時（3600 秒）
        return URLSession(configuration: config)
    }()
    private var currentUpdateTask: Task<Void, Never>?

    // 狀態追蹤
    @Published var isUpdating: Bool = false
    @Published var updateError: String?
    @Published var currentStatus: String = ""  // 當前狀態描述

    // 任務變動追蹤（當前更新）
    @Published var addedTasks: [PendingTask] = []
    @Published var deletedTasks: [TodoTask] = []
    @Published var updatedTasks: [(original: TodoTask, updated: PendingTask)] = []

    // 上一次更新的任務記錄（持久化）
    @Published var lastAddedTasks: [PendingTask] = []
    @Published var lastDeletedTasks: [TodoTask] = []
    @Published var lastUpdatedTasks: [(original: TodoTask, updated: PendingTask)] = []

    // UserDefaults keys
    private let lastUpdateStatusKey = "CalendarAssistant_LastUpdateStatus"
    private let lastUpdateDateKey = "CalendarAssistant_LastUpdateDate"
    private let autoUpdateEnabledKey = "CalendarAssistant_AutoUpdateEnabled"
    private let autoUpdateInputKey = "CalendarAssistant_AutoUpdateInput"

    // 每日自動更新設定
    @Published var autoUpdateEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(autoUpdateEnabled, forKey: autoUpdateEnabledKey)
        }
    }
    @Published var autoUpdateInput: String = "" {
        didSet {
            UserDefaults.standard.set(autoUpdateInput, forKey: autoUpdateInputKey)
        }
    }
    private var isAutoUpdateInProgress: Bool = false
    private var lastUpdateDate: Date? {
        get {
            UserDefaults.standard.object(forKey: lastUpdateDateKey) as? Date
        }
        set {
            UserDefaults.standard.set(newValue, forKey: lastUpdateDateKey)
        }
    }

    // Firestore 相關
    private let db = Firestore.firestore()
    private let studySettingsCollection = "studySettings"

    // 使用者讀書設定
    @Published var studySettings: StudySettings?
    @Published var isLoadingSettings: Bool = false
    @Published var settingsError: String?

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

    private init() {
        loadLastUpdateStatus()
        loadAutoUpdateSettings()
        Task {
            await loadStudySettingsFromFirestore()
        }
    }

    /// 載入自動更新設定
    private func loadAutoUpdateSettings() {
        autoUpdateEnabled = UserDefaults.standard.bool(forKey: autoUpdateEnabledKey)
        autoUpdateInput = UserDefaults.standard.string(forKey: autoUpdateInputKey) ?? ""
    }

    // MARK: - 每日自動更新

    /// 取得當前日期（支援測試模式）
    private func getCurrentDate() -> Date {
        // 檢查是否有設定測試用的日期
        if let fakeNowISO = ProcessInfo.processInfo.environment["FAKE_NOW_ISO8601"] {
            let formatter = ISO8601DateFormatter()
            if let fakeDate = formatter.date(from: fakeNowISO) {
                print("⚠️ 使用測試日期：\(fakeDate)")
                return fakeDate
            }
        }
        return Date()
    }

    /// 檢查今天是否已經更新過
    func hasUpdatedToday() -> Bool {
        guard let lastDate = lastUpdateDate else {
            return false
        }

        let calendar = Calendar.current
        let currentDate = getCurrentDate()

        // 檢查 lastDate 是否與當前日期在同一天
        return calendar.isDate(lastDate, inSameDayAs: currentDate)
    }

    /// 執行每日自動更新（如果需要）
    func performDailyAutoUpdateIfNeeded() async {
        // 檢查是否開啟自動更新
        guard autoUpdateEnabled else {
            print("每日自動更新未開啟")
            return
        }

        // 檢查是否有設定更新指令
        guard !autoUpdateInput.isEmpty else {
            print("每日自動更新：未設定更新指令")
            return
        }

        // 檢查今天是否已更新過
        if hasUpdatedToday() {
            print("今日已執行過自動更新，跳過")
            return
        }

        // 避免重複觸發
        guard !isAutoUpdateInProgress else {
            print("每日自動更新已在進行中，跳過")
            return
        }

        // 等待其他日曆相關操作完成
        let waitSucceeded = await waitForCalendarUpdateAvailability()
        guard waitSucceeded else {
            print("每日自動更新等待日曆更新完成時超過時間限制，取消此次自動更新")
            return
        }

        isAutoUpdateInProgress = true
        defer { isAutoUpdateInProgress = false }

        print("開始執行每日自動更新...")
        await startUpdate(userInput: autoUpdateInput)

        if updateError == nil {
            let currentDate = getCurrentDate()
            lastUpdateDate = currentDate
            print("每日自動更新完成，記錄時間：\(currentDate)")
        } else {
            print("每日自動更新失敗：\(updateError ?? "未知錯誤")")
        }
    }

    /// 等待日曆相關操作完成，避免自動更新與其他操作重疊
    private func waitForCalendarUpdateAvailability(
        timeout: TimeInterval = 30.0,
        pollInterval: TimeInterval = 0.5
    ) async -> Bool {
        var elapsed: TimeInterval = 0
        let pollNanoseconds = UInt64(pollInterval * 1_000_000_000)
        var hasLoggedWaitMessage = false

        while isUpdating || (todoViewModel?.isLoading ?? false) || !(todoViewModel?.hasLoadedInitialTasks ?? false) {
            if !hasLoggedWaitMessage {
                print("每日自動更新等待日曆資料載入/更新完成...")
                hasLoggedWaitMessage = true
            }

            if elapsed >= timeout {
                return false
            }

            try? await Task.sleep(nanoseconds: pollNanoseconds)
            elapsed += pollInterval
        }

        if hasLoggedWaitMessage {
            print("日曆更新已完成，自動更新即將開始")
        }

        return true
    }

    // MARK: - 持久化相關

    /// 載入上一次的更新記錄
    private func loadLastUpdateStatus() {
        guard let data = UserDefaults.standard.data(forKey: lastUpdateStatusKey),
              let decoded = try? JSONDecoder().decode(LastUpdateStatus.self, from: data) else {
            return
        }

        lastAddedTasks = decoded.addedTasks
        lastDeletedTasks = decoded.deletedTasks
        lastUpdatedTasks = decoded.updatedTasks
    }

    /// 儲存當前更新記錄到本地端
    private func saveLastUpdateStatus() {
        let status = LastUpdateStatus(
            addedTasks: addedTasks,
            deletedTasks: deletedTasks,
            updatedTasks: updatedTasks
        )

        if let encoded = try? JSONEncoder().encode(status) {
            UserDefaults.standard.set(encoded, forKey: lastUpdateStatusKey)
        }
    }

    /// 清除上一次的記錄（當開始新的更新時）
    private func clearLastUpdateStatus() {
        lastAddedTasks = []
        lastDeletedTasks = []
        lastUpdatedTasks = []
    }


    // MARK: - 主要更新方法

    /// 開始更新日曆任務
    func startUpdate(userInput: String) async {
        // 取消尚未完成的更新工作（若存在）
        currentUpdateTask?.cancel()

        let updateTask = Task { [weak self] in
            guard let self else { return }
            await self.runUpdate(userInput: userInput)
        }

        currentUpdateTask = updateTask
        await updateTask.value
        currentUpdateTask = nil
    }

    /// 使用者主動取消更新
    func cancelUpdate() {
        guard isUpdating else { return }
        currentStatus = "正在取消..."
        updateError = nil
        currentUpdateTask?.cancel()
    }

    // MARK: - 撤回功能

    /// 撤回上一次的更新操作
    func undoLastUpdate() async {
        guard !isUpdating else {
            print("⚠️ 正在更新中，無法執行撤回操作")
            return
        }

        guard !lastAddedTasks.isEmpty || !lastDeletedTasks.isEmpty || !lastUpdatedTasks.isEmpty else {
            print("⚠️ 沒有可以撤回的操作")
            updateError = "沒有可以撤回的操作"
            return
        }

        isUpdating = true
        currentStatus = "正在撤回上次更新..."
        updateError = nil

        print("\n" + String(repeating: "=", count: 80))
        print("🔙 開始撤回上次更新")
        print(String(repeating: "=", count: 80))

        var successCount = 0
        var failureCount = 0

        // 1. 撤回新增的任務（刪除它們）- 使用 Cloud Functions
        for pendingTask in lastAddedTasks {
            // 透過標題、開始時間、結束時間找到對應的任務
            if let taskToDelete = todoViewModel?.tasks.first(where: {
                $0.title == pendingTask.title &&
                $0.startDate == pendingTask.startDate &&
                $0.endDate == pendingTask.endDate
            }) {
                do {
                    let result = try await functions.httpsCallable("deleteTask").call([
                        "taskId": taskToDelete.id
                    ])

                    guard let data = result.data as? [String: Any],
                          let success = data["success"] as? Bool,
                          success else {
                        throw NSError(domain: "CalendarAssistant", code: -1,
                                    userInfo: [NSLocalizedDescriptionKey: "刪除任務失敗"])
                    }

                    successCount += 1
                    print("  ✅ 已刪除先前新增的任務：\(taskToDelete.title)")
                } catch {
                    failureCount += 1
                    print("  ❌ 刪除任務失敗：\(error)")
                }
            }
        }

        // 2. 撤回刪除的任務（重新添加它們）- 使用 Cloud Functions
        for deletedTask in lastDeletedTasks {
            do {
                // 重新創建任務
                let restoredTask = TodoTask(
                    title: deletedTask.title,
                    note: deletedTask.note,
                    color: deletedTask.color,
                    focusTime: deletedTask.focusTime,
                    category: deletedTask.category,
                    isAllDay: deletedTask.isAllDay,
                    isCompleted: deletedTask.isCompleted,
                    repeatType: deletedTask.repeatType,
                    startDate: deletedTask.startDate,
                    endDate: deletedTask.endDate,
                    userId: deletedTask.userId
                )

                var taskData = restoredTask.toFirestore
                let convertedData = convertTimestampsToStrings(taskData)

                let result = try await functions.httpsCallable("createTask").call([
                    "task": convertedData
                ])

                guard let data = result.data as? [String: Any],
                      let success = data["success"] as? Bool,
                      success else {
                    throw NSError(domain: "CalendarAssistant", code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "創建任務失敗"])
                }

                successCount += 1
                print("  ✅ 已恢復先前刪除的任務：\(restoredTask.title)")
            } catch {
                failureCount += 1
                print("  ❌ 恢復任務失敗：\(error)")
            }
        }

        // 3. 撤回修改的任務（恢復到原始狀態）- 使用 Cloud Functions
        for (original, _) in lastUpdatedTasks {
            // 找到當前的任務
            if let currentTask = todoViewModel?.tasks.first(where: { $0.id == original.id }) {
                do {
                    // 恢復為原始數據
                    var restoredTask = currentTask
                    restoredTask.title = original.title
                    restoredTask.note = original.note
                    restoredTask.category = original.category
                    restoredTask.startDate = original.startDate
                    restoredTask.endDate = original.endDate
                    restoredTask.isAllDay = original.isAllDay
                    restoredTask.isCompleted = original.isCompleted
                    restoredTask.color = original.color

                    var taskData = restoredTask.toFirestore
                    let convertedData = convertTimestampsToStrings(taskData)

                    let result = try await functions.httpsCallable("updateTask").call([
                        "taskId": original.id,
                        "task": convertedData
                    ])

                    guard let data = result.data as? [String: Any],
                          let success = data["success"] as? Bool,
                          success else {
                        throw NSError(domain: "CalendarAssistant", code: -1,
                                    userInfo: [NSLocalizedDescriptionKey: "更新任務失敗"])
                    }

                    successCount += 1
                    print("  ✅ 已恢復任務的原始狀態：\(restoredTask.title)")
                } catch {
                    failureCount += 1
                    print("  ❌ 恢復任務失敗：\(error)")
                }
            }
        }

        print(String(repeating: "=", count: 80))
        print("📊 撤回結果：成功 \(successCount) 個，失敗 \(failureCount) 個")
        print(String(repeating: "=", count: 80) + "\n")

        // 如果有成功的撤回操作，重新整理任務清單
        if successCount > 0 {
            do {
                try await todoViewModel?.forceReloadTasks()
            } catch {
                print("⚠️ 重新整理任務清單失敗: \(error)")
            }
        }

        if failureCount > 0 {
            currentStatus = "撤回完成，但有 \(failureCount) 個操作失敗"
            updateError = "部分撤回操作失敗"
        } else {
            currentStatus = "撤回完成"
            // 清除上次記錄
            clearLastUpdateStatus()
        }

        isUpdating = false
    }

    private func runUpdate(userInput: String) async {
        guard !Task.isCancelled else {
            completeCancellation()
            return
        }

        isUpdating = true
        updateError = nil
        currentStatus = "正在初始化..."

        // 清空當前更新的結果
        addedTasks = []
        deletedTasks = []
        updatedTasks = []

        // 清除上一次的記錄（開始新的更新）
        clearLastUpdateStatus()

        await performUpdate(userInput: userInput)
    }

    private func completeCancellation() {
        currentStatus = "已取消"
        isUpdating = false
    }

    /// 實際執行更新的方法（從 startUpdate 分離出來）
    private func performUpdate(userInput: String) async {
        guard !Task.isCancelled else {
            completeCancellation()
            return
        }

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
            if Task.isCancelled {
                completeCancellation()
                return
            }

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
                model: "gpt-5-mini",
                messages: messages,
                temperature: 1.0,
                stream: false,
                tools: [saveTaskFunction, deleteTaskFunction, updateTaskFunction, endConversationFunction],
                tool_choice: "required",  // 強制 GPT 必須調用函數，不允許純文字回應
                stream_options: nil,
                reasoning_effort: "low"
            )

            guard let data = try? encoder.encode(reqBody) else {
                updateError = "編碼請求失敗"
                isUpdating = false
                return
            }

            // 在終端機顯示完整的請求內容（易閱讀格式）
            print("\n" + String(repeating: "═", count: 80))
            print("📤 發送給 OpenAI 的請求內容（第 \(roundCount) 輪）")
            print(String(repeating: "═", count: 80))

            // 顯示摘要資訊
            print("📊 請求摘要：")
            print("   模型: \(reqBody.model)")
            print("   訊息數: \(reqBody.messages.count) 條")
            print("   工具數: \(reqBody.tools?.count ?? 0) 個")
            if let tools = reqBody.tools {
                let toolNames = tools.map { $0.function.name }
                print("   工具: [\(toolNames.joined(separator: ", "))]")
            }
            print("   Tool Choice: \(reqBody.tool_choice ?? "auto")")
            print("   Temperature: \(reqBody.temperature)")
            print("   Stream: \(reqBody.stream)")

            print("\n" + String(repeating: "-", count: 80))
            print("💬 訊息列表：")
            for (index, message) in reqBody.messages.enumerated() {
                let roleIcon = message.role == "system" ? "🤖" :
                               message.role == "user" ? "👤" :
                               message.role == "assistant" ? "🤖" : "🔧"

                print("\n   [\(index + 1)] \(roleIcon) \(message.role.uppercased())")

                if message.role == "system" {
                    // 系統訊息：只顯示前 300 字元和最後 150 字元
                    let content = message.content
                    if content.count > 500 {
                        print("      內容: \(content.prefix(300))...")
                        print("      ...")
                        print("      ...\(content.suffix(150))")
                        print("      (總長度: \(content.count) 字元)")
                    } else {
                        print("      內容: \(content)")
                    }
                } else if message.role == "tool" {
                    // Tool 回應訊息
                    print("      Tool Call ID: \(message.tool_call_id ?? "N/A")")
                    let content = message.content
                    if content.count > 200 {
                        print("      回應: \(content.prefix(200))... (總長度: \(content.count) 字元)")
                    } else {
                        print("      回應: \(content)")
                    }
                } else {
                    // User 或 Assistant 訊息
                    if !message.content.isEmpty {
                        print("      內容: \(message.content)")
                    }

                    // 顯示 tool_calls（如果有）
                    if let toolCalls = message.tool_calls, !toolCalls.isEmpty {
                        print("      🔧 Tool Calls: (\(toolCalls.count) 個)")
                        for (tcIndex, toolCall) in toolCalls.enumerated() {
                            print("         [\(tcIndex + 1)] \(toolCall.function.name)")
                            print("             ID: \(toolCall.id)")
                            let args = toolCall.function.arguments
                            if args.count > 150 {
                                print("             參數: \(args.prefix(150))... (總長度: \(args.count) 字元)")
                            } else {
                                print("             參數: \(args)")
                            }
                        }
                    }
                }
            }

            print("\n" + String(repeating: "-", count: 80))
            print("🛠️ 可用工具定義：")
            if let tools = reqBody.tools {
                for (index, tool) in tools.enumerated() {
                    print("\n   [\(index + 1)] \(tool.function.name)")
                    print("      描述: \(tool.function.description)")
                    print("      類型: \(tool.type)")
                }
            }

            print("\n" + String(repeating: "-", count: 80))
            print("📦 完整 JSON（美化格式）：")
            if let jsonObject = try? JSONSerialization.jsonObject(with: data),
               let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys]),
               let prettyString = String(data: prettyData, encoding: .utf8) {
                print(prettyString)
            } else if let requestString = String(data: data, encoding: .utf8) {
                print(requestString)
            } else {
                print("無法將請求轉換為字串")
            }

            print(String(repeating: "═", count: 80) + "\n")

            var req = URLRequest(url: proxyURL)
            req.httpMethod = "POST"
            req.addValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = data

            do {
                if Task.isCancelled {
                    throw CancellationError()
                }

                let (respData, resp) = try await retryOnError {
                    try await self.urlSession.data(for: req)
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

            } catch is CancellationError {
                print("\n⚠️ 更新已被取消")
                completeCancellation()
                return
            } catch let urlError as URLError {
                print("\n❌ 網路錯誤發生：\(urlError.localizedDescription)")
                if urlError.code == .timedOut {
                    updateError = "請求超時（已等待超過 10 分鐘），請檢查網路連線或稍後再試"
                } else {
                    updateError = "網路錯誤：\(urlError.localizedDescription)"
                }
                isUpdating = false
                return
            } catch let nsError as NSError where nsError.domain == "CalendarAssistant" && nsError.code == 429 {
                // 專門處理 429 錯誤
                print("\n❌ 請求過於頻繁：\(nsError.localizedDescription)")
                updateError = nsError.localizedDescription
                isUpdating = false
                return
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

            // 檢查是否有任何任務被更新
            let hasUpdates = !addedTasks.isEmpty || !deletedTasks.isEmpty || !updatedTasks.isEmpty

            if hasUpdates {
                // 有更新：保存當前記錄到本地端，並將其設為上一次記錄
                saveLastUpdateStatus()
                lastAddedTasks = addedTasks
                lastDeletedTasks = deletedTasks
                lastUpdatedTasks = updatedTasks
                currentStatus = "處理完成"

                // 記錄更新時間（用於每日自動更新檢查，支援測試模式）
                lastUpdateDate = getCurrentDate()
            } else {
                // 沒有更新：顯示「無任務被更新」，並保留上一次的記錄（如果有的話）
                currentStatus = "無任務被更新"
            }
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
                    print("    ❌ 日期解析失敗 - 任務: \(task.title)")
                    print("       開始時間: \(task.startDate)")
                    print("       結束時間: \(task.endDate)")
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

                // 使用 Cloud Functions 儲存任務
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

                    // 準備任務資料並轉換為 JSON 可序列化格式
                    var taskData = todoTask.toFirestore
                    let convertedData = convertTimestampsToStrings(taskData)

                    // 呼叫 Cloud Functions createTask
                    let result = try await functions.httpsCallable("createTask").call([
                        "task": convertedData
                    ])

                    // 解析回應
                    guard let data = result.data as? [String: Any],
                          let success = data["success"] as? Bool,
                          success else {
                        throw NSError(domain: "CalendarAssistant", code: -1,
                                    userInfo: [NSLocalizedDescriptionKey: "創建任務失敗"])
                    }

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

            // 如果有成功新增的任務，通知 TodoViewModel 重新整理
            if successCount > 0 {
                do {
                    try await todoViewModel?.forceReloadTasks()
                } catch {
                    print("⚠️ 重新整理任務清單失敗: \(error)")
                }
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
            var successCount = 0
            var failureCount = 0

            for taskId in args.taskIds {
                // 直接呼叫 Cloud Functions 刪除任務
                do {
                    let result = try await functions.httpsCallable("deleteTask").call([
                        "taskId": taskId
                    ])

                    // 解析回應
                    guard let data = result.data as? [String: Any],
                          let success = data["success"] as? Bool,
                          success else {
                        print("    ❌ Cloud Functions 刪除任務失敗: taskId = \(taskId)")
                        failureCount += 1
                        continue
                    }

                    successCount += 1

                    // 嘗試從本地快取中獲取任務資訊（用於顯示），但不強制要求
                    if let task = todoViewModel?.tasks.first(where: { $0.id == taskId }) {
                        tasksToDelete.append(task)
                        // 立即更新狀態
                        await MainActor.run {
                            self.deletedTasks.append(task)
                            self.updateCurrentStatus()
                        }
                        print("    ✅ 已刪除任務：\(task.title)")
                    } else {
                        print("    ✅ 已刪除任務：taskId = \(taskId)")
                    }
                } catch {
                    print("    ❌ 刪除任務失敗: taskId = \(taskId), error = \(error)")
                    failureCount += 1
                }
            }

            if successCount == 0 {
                return "任務刪除失敗" + (failureCount > 0 ? "（共 \(failureCount) 個任務）" : "")
            }

            // 注意：已在上面的迴圈中即時更新 deletedTasks，這裡不需要重複添加

            // 如果有成功刪除的任務，通知 TodoViewModel 重新整理
            if successCount > 0 {
                do {
                    try await todoViewModel?.forceReloadTasks()
                } catch {
                    print("⚠️ 重新整理任務清單失敗: \(error)")
                }
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
                return "成功更新，目前尚無任務需要更新"
            }

            var successCount = 0
            var failureCount = 0

            for taskArg in args.tasks {
                // 先從本地快取查找原任務
                var originalTask = todoViewModel?.tasks.first(where: { $0.id == taskArg.taskId })

                // 如果本地快取找不到，嘗試從 Firebase 重新載入
                if originalTask == nil {
                    print("本地快取找不到任務 \(taskArg.taskId)，從 Firebase 重新載入")
                    do {
                        let firebaseService = FirebaseService.shared
                        let allTasks = try await firebaseService.fetchTodoTasks()
                        originalTask = allTasks.first(where: { $0.id == taskArg.taskId })
                    } catch {
                        print("從 Firebase 載入任務失敗: \(error)")
                    }
                }

                // 如果還是找不到任務，跳過
                guard let originalTask = originalTask else {
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

                    // 準備任務資料並轉換為 JSON 可序列化格式
                    var taskData = updatedTodoTask.toFirestore
                    let convertedData = convertTimestampsToStrings(taskData)

                    // 使用 Cloud Functions 更新任務
                    let result = try await functions.httpsCallable("updateTask").call([
                        "taskId": taskArg.taskId,
                        "updates": convertedData
                    ])

                    // 解析回應
                    guard let data = result.data as? [String: Any],
                          let success = data["success"] as? Bool,
                          success else {
                        throw NSError(domain: "CalendarAssistant", code: -1,
                                    userInfo: [NSLocalizedDescriptionKey: "更新任務失敗"])
                    }

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

            // 如果有成功更新的任務，通知 TodoViewModel 重新整理
            if successCount > 0 {
                do {
                    try await todoViewModel?.forceReloadTasks()
                } catch {
                    print("⚠️ 重新整理任務清單失敗: \(error)")
                }
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

    /// 將 Firestore Timestamp 轉換為 ISO 8601 字串（用於 Cloud Functions）
    private func convertTimestampsToStrings(_ data: [String: Any]) -> [String: Any] {
        var result = data
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        for (key, value) in data {
            if let timestamp = value as? Timestamp {
                result[key] = dateFormatter.string(from: timestamp.dateValue())
            } else if let dict = value as? [String: Any] {
                result[key] = convertTimestampsToStrings(dict)
            } else if let array = value as? [[String: Any]] {
                result[key] = array.map { convertTimestampsToStrings($0) }
            }
        }

        return result
    }

    /// 將 Cloud Functions 返回的日期數據轉換為 Timestamp 對象
    private func convertToTimestamps(_ data: [String: Any]) -> [String: Any] {
        var result = data

        for (key, value) in data {
            // 檢查是否是 Firestore Timestamp 的序列化格式 {_seconds: ..., _nanoseconds: ...}
            if let dict = value as? [String: Any],
               let seconds = dict["_seconds"] as? Int64 ?? dict["_seconds"] as? Int as? Int64,
               let nanoseconds = dict["_nanoseconds"] as? Int32 ?? dict["_nanoseconds"] as? Int as? Int32 {
                result[key] = Timestamp(seconds: seconds, nanoseconds: nanoseconds)
            }
            // 檢查是否是 ISO 8601 字符串
            else if let dateString = value as? String {
                let dateFormatter = ISO8601DateFormatter()
                dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let date = dateFormatter.date(from: dateString) {
                    result[key] = Timestamp(date: date)
                }
            }
            // 遞歸處理嵌套字典
            else if let dict = value as? [String: Any] {
                result[key] = convertToTimestamps(dict)
            }
            // 遞歸處理數組
            else if let array = value as? [[String: Any]] {
                result[key] = array.map { convertToTimestamps($0) }
            }
        }

        return result
    }

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

        // 優先使用 ISO8601DateFormatter（最準確）
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso8601Formatter.date(from: dateString) {
            print("✅ 成功解析日期（ISO8601）：\(dateString) -> \(date)")
            return date
        }

        // 如果失敗，嘗試不帶毫秒的格式
        iso8601Formatter.formatOptions = [.withInternetDateTime]
        if let date = iso8601Formatter.date(from: dateString) {
            print("✅ 成功解析日期（ISO8601 無毫秒）：\(dateString) -> \(date)")
            return date
        }

        // 備用：使用 DateFormatter 嘗試多種格式
        let dateFormats = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSXXX",    // 2025-10-26T08:00:00.000+08:00
            "yyyy-MM-dd'T'HH:mm:ssXXX",        // 2025-10-26T08:00:00+08:00
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",      // 2025-10-26T08:00:00.000Z
            "yyyy-MM-dd'T'HH:mm:ssZ",          // 2025-10-26T08:00:00Z
            "yyyy-MM-dd'T'HH:mm:ss.SSS",       // 2025-10-26T08:00:00.000
            "yyyy-MM-dd'T'HH:mm:ss",           // 2025-10-26T08:00:00
            "yyyy-MM-dd'T'HH:mmXXX",           // 2025-10-26T08:00+08:00
            "yyyy-MM-dd'T'HH:mm",              // 2025-10-26T08:00
            "yyyy-MM-dd"                       // 2025-10-26
        ]

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone.current

        for format in dateFormats {
            dateFormatter.dateFormat = format
            if let date = dateFormatter.date(from: dateString) {
                print("✅ 成功解析日期（DateFormatter）：\(dateString) -> \(date) (格式: \(format))")
                return date
            }
        }

        print("❌ 無法解析日期：\(dateString)")
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
        let tone = studySettings?.tone ?? "冷靜且專業的專家"
        let currentTimeString = getCurrentDate()
        var prompt = """
            你是一個日曆安排助手，會根據使用者的需求自動調整日曆任務。你的語氣是：\(tone)

            \(formatStudySettings())

            當前系統時間：\(currentTimeString)

            你的目標：
            1. 根據需求新增、刪除或修改任務
            2. 完成所有操作後立即調用 end_conversation（如果沒有任務需要新增/刪除/更新，直接調用 end_conversation 結束對話）

            重要規則：
            1. 如果沒有任務需要新增/刪除/更新，直接調用 end_conversation 結束對話。
            2. 不要進行不必要的更新。使用常識判斷什麼是「不必要的」：
                - 沒有實際變化的任務不需要更新
                - 當使用者要求「更新任務到今天」時，只更新明顯過時的任務（例如昨天或更早的日期）
                - 今天排程的任務（即使過去幾分鐘或幾小時）通常不需要更新，除非明顯過時
                - 範例：如果現在時間是 14:30，任務排在今天 13:00，這不需要更新
                - 範例：如果現在時間是 14:30，任務排在昨天，這需要更新
                - 使用實際判斷：同一天內的輕微時間差異是可以接受的，不需要更新
            3. 如果使用者沒有指定特定時段，安排任務時必須遵循以下規則：
                - 任務只能在使用者設定的讀書日期和時間內安排
                - 每個任務的持續時間應該是設定的讀書時間（\(studySettings?.studyDuration ?? 60) 分鐘）
                - 不要在設定的時間範圍外安排任務
                - 不要與現有任務時間重疊
            4. 安排任務時，如果使用者要求很多任務（例如一兩百個任務），你必須滿足使用者的要求，一次全部安排。
            5. 如果沒有指定時間，表示現在。
            6. 如果沒有要求更改時間，不要修改時間（例如使用者沒有要求更改時間時）。
            7. 你必須完全遵循使用者的指示，不要添加額外的規則或假設。
            8. 使用使用者的語言回應（例如使用中文時用中文回應，使用英文時用英文回應）。
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

    // 執行 getTask 函數：優先使用本地快取，為空才用 Cloud Functions（與 ChatViewModel 保持一致）
    private func executeGetTask() async -> String {
        // 優先使用本地快取（避免超時），如果為空才用 Cloud Functions
        var tasks = todoViewModel?.tasks ?? []

        if tasks.isEmpty {
            let firebaseService = FirebaseService.shared
            do {
                tasks = try await firebaseService.fetchTodoTasks()
            } catch {
                print("從 Cloud Functions 載入任務失敗: \(error)")
                return "{\"error\":\"獲取任務時發生錯誤：\(error.localizedDescription)\"}"
            }
        }

        do {
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            isoFormatter.timeZone = TimeZone.current

            let formattedTasks: [[String: Any]] = tasks.map { task in
                var taskDict: [String: Any] = [
                    "taskId": task.id,
                    "title": task.title,
                    "category": task.category,
                    "isCompleted": task.isCompleted,
                    "isAllDay": task.isAllDay,
                    "startDate": isoFormatter.string(from: task.startDate),
                    "endDate": isoFormatter.string(from: task.endDate)
                ]

                if !task.note.isEmpty {
                    taskDict["note"] = task.note
                }

                return taskDict
            }

            let payload: [String: Any] = [
                "currentTime": isoFormatter.string(from: Date()),
                "existingTasks": formattedTasks
            ]

            let jsonData = try JSONSerialization.data(
                withJSONObject: payload,
                options: [.prettyPrinted, .sortedKeys]
            )
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                return jsonString
            } else {
                return "{\"error\":\"無法將任務轉換為 JSON 字串\"}"
            }
        } catch {
            print("獲取任務失敗: \(error)")
            return "{\"error\":\"獲取任務時發生錯誤：\(error.localizedDescription)\"}"
        }
    }

    private func formatExistingTasks() -> String {
        // 使用本地快取（避免超時問題）
        let tasks = todoViewModel?.tasks ?? []
        guard !tasks.isEmpty else { return "目前沒有任何現有任務。" }

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        isoFormatter.timeZone = TimeZone.current

        let formattedTasks: [[String: Any]] = tasks.map { task in
            var taskDict: [String: Any] = [
                "taskId": task.id,
                "title": task.title,
                "category": task.category,
                "isCompleted": task.isCompleted,
                "isAllDay": task.isAllDay,
                "startDate": isoFormatter.string(from: task.startDate),
                "endDate": isoFormatter.string(from: task.endDate)
            ]

            if !task.note.isEmpty {
                taskDict["note"] = task.note
            }

            return taskDict
        }

        do {
            let payload: [String: Any] = ["existingTasks": formattedTasks]
            let jsonData = try JSONSerialization.data(
                withJSONObject: payload,
                options: [.prettyPrinted, .sortedKeys]
            )
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                return "目前系統中的任務列表（JSON）：\n\(jsonString)"
            }
        } catch {
            print("formatExistingTasks JSON error: \(error)")
            return "目前系統中的任務列表（JSON）轉換失敗：\(error.localizedDescription)"
        }

        return "目前系統中的任務列表（JSON）轉換失敗。"
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
        maxAttempts: Int = 5,
        baseDelay: TimeInterval = 2.0,  // 基礎延遲時間（秒）
        operation: @escaping () async throws -> T
    ) async throws -> T {
        func backoffDelay(forRetry retry: Int, suggested: TimeInterval? = nil) -> TimeInterval {
            if let suggested, suggested > 0 {
                return min(suggested, 60.0)
            }
            let exponentialDelay = pow(2.0, Double(max(retry - 1, 0))) * baseDelay
            let jitter = Double.random(in: 0...1.0)
            return min(exponentialDelay + jitter, 60.0)
        }

        var lastError: Error?

        for attempt in 1...maxAttempts {
            do {
                let result = try await operation()

                if let (_, response) = result as? (Data, URLResponse),
                   let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 429 {
                    let retryAfterHeader = httpResponse.value(forHTTPHeaderField: "Retry-After")
                    let suggestedDelay = retryAfterHeader.flatMap { TimeInterval($0) }

                    lastError = NSError(
                        domain: "CalendarAssistant",
                        code: 429,
                        userInfo: [NSLocalizedDescriptionKey: "請求過於頻繁，請稍後再試"]
                    )

                    if attempt == maxAttempts {
                        print("❌ 已達到最大重試次數 (\(maxAttempts))")
                        break
                    }

                    let waitTime = backoffDelay(forRetry: attempt, suggested: suggestedDelay)
                    print("⚠️ 收到 429 狀態碼 (請求過於頻繁)，等待 \(String(format: "%.1f", waitTime)) 秒後重試...")
                    try await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
                    continue
                }

                return result
            } catch {
                if error is CancellationError {
                    throw error
                }

                lastError = error

                if attempt == maxAttempts {
                    break
                }

                let waitTime = backoffDelay(forRetry: attempt)
                print("⚠️ 發生錯誤（第 \(attempt) 次）：\(error.localizedDescription)，等待 \(String(format: "%.1f", waitTime)) 秒後重試...")
                try await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
            }
        }

        throw lastError ?? URLError(.timedOut)
    }

}

// MARK: - 持久化結構定義

/// 用於保存上一次更新狀態的結構
struct LastUpdateStatus: Codable {
    let addedTasks: [PendingTask]
    let deletedTasks: [TodoTask]
    let updatedTasks: [(original: TodoTask, updated: PendingTask)]

    enum CodingKeys: String, CodingKey {
        case addedTasks
        case deletedTasks
        case updatedTasks
    }

    init(addedTasks: [PendingTask], deletedTasks: [TodoTask], updatedTasks: [(original: TodoTask, updated: PendingTask)]) {
        self.addedTasks = addedTasks
        self.deletedTasks = deletedTasks
        self.updatedTasks = updatedTasks
    }

    // 自訂編碼，因為 tuple 不支援 Codable
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(addedTasks, forKey: .addedTasks)
        try container.encode(deletedTasks, forKey: .deletedTasks)

        // 將 tuple 轉換為可編碼的結構
        let updatedTaskPairs = updatedTasks.map { UpdatedTaskPair(original: $0.original, updated: $0.updated) }
        try container.encode(updatedTaskPairs, forKey: .updatedTasks)
    }

    // 自訂解碼
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        addedTasks = try container.decode([PendingTask].self, forKey: .addedTasks)
        deletedTasks = try container.decode([TodoTask].self, forKey: .deletedTasks)

        // 將可解碼的結構轉換回 tuple
        let updatedTaskPairs = try container.decode([UpdatedTaskPair].self, forKey: .updatedTasks)
        updatedTasks = updatedTaskPairs.map { (original: $0.original, updated: $0.updated) }
    }
}

/// 用於編碼 updatedTasks 的輔助結構
private struct UpdatedTaskPair: Codable {
    let original: TodoTask
    let updated: PendingTask
}
