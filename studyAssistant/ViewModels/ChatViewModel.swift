import FirebaseAuth
import FirebaseFirestore
import Foundation
import SwiftUI

// MARK: - OpenAI API 資料結構
struct OpenAIMessage: Codable {
    let role: String
    let content: String
    let name: String?
    let tool_calls: [ToolCall]?

    init(role: String, content: String, name: String? = nil, tool_calls: [ToolCall]? = nil) {
        self.role = role
        self.content = content
        self.name = name
        self.tool_calls = tool_calls
    }
}

// Function calling 相關結構
struct OpenAIFunction: Codable {
    let name: String
    let description: String
    let parameters: Parameters

    struct Parameters: Codable {
        let type: String
        let properties: [String: Property]

        struct Property: Codable {
            let type: String
            let description: String?

            // 用於陣列類型的額外屬性
            private let itemsObject: PropertyObject?

            var items: PropertyObject? {
                return itemsObject
            }

            init(type: String, description: String? = nil, items: PropertyObject? = nil) {
                self.type = type
                self.description = description
                self.itemsObject = items
            }

            enum CodingKeys: String, CodingKey {
                case type, description
                case itemsObject = "items"
            }
        }

        struct PropertyObject: Codable {
            let type: String
            let properties: [String: Property]?

            init(type: String, properties: [String: Property]? = nil) {
                self.type = type
                self.properties = properties
            }
        }
    }
}

struct OpenAIFunctionCall: Codable {
    let name: String

    init(name: String) {
        self.name = name
    }

    init(from decoder: Decoder) throws {
        if let container = try? decoder.singleValueContainer(),
            let stringValue = try? container.decode(String.self)
        {
            self.name = stringValue
        } else {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.name = try container.decode(String.self, forKey: .name)
        }
    }

    enum CodingKeys: String, CodingKey {
        case name
    }
}

// Tool calling 相關結構
struct Tool: Codable {
    let type: String
    let function: ToolFunction
}

struct ToolFunction: Codable {
    let name: String
    let description: String
    let parameters: Parameters

    struct Parameters: Codable {
        let type: String
        let properties: [String: Property]
        let required: [String]?

        struct Property: Codable {
            let type: String
            let description: String?

            // 用於陣列類型的額外屬性
            private let itemsObject: PropertyObject?

            var items: PropertyObject? {
                return itemsObject
            }

            init(type: String, description: String? = nil, items: PropertyObject? = nil) {
                self.type = type
                self.description = description
                self.itemsObject = items
            }

            enum CodingKeys: String, CodingKey {
                case type, description
                case itemsObject = "items"
            }
        }

        struct PropertyObject: Codable {
            let type: String
            let properties: [String: Property]?

            init(type: String, properties: [String: Property]? = nil) {
                self.type = type
                self.properties = properties
            }
        }
    }
}

struct ToolCall: Codable {
    let id: String
    let type: String
    let function: ToolCallFunction
}

struct ToolCallFunction: Codable {
    let name: String
    let arguments: String
}

struct OpenAIRequest: Codable {
    let model: String
    let messages: [OpenAIMessage]
    let temperature: Float
    let stream: Bool
    let tools: [Tool]?
    let tool_choice: String?
    let stream_options: [String: Bool]?  // 新增: 支援stream_options參數
}

// 非串流回傳格式（給 generateTitle 用）
struct OpenAIResponseChoice: Decodable {
    let index: Int
    let message: OpenAIMessage
    let finishReason: String?

    enum CodingKeys: String, CodingKey {
        case index, message
        case finishReason = "finish_reason"
    }
}

// 更新OpenAIResponse結構體，添加usage欄位
struct OpenAIResponse: Decodable {
    let id: String
    let choices: [OpenAIResponseChoice]
    let usage: OpenAIUsage?  // 新增usage欄位
}

// 串流 chunk 格式
struct OpenAIStreamDelta: Decodable {
    let role: String?
    let content: String?
    let tool_calls: [ToolCallDelta]?

    struct ToolCallDelta: Decodable {
        let index: Int
        let id: String?
        let type: String?
        let function: FunctionDelta?

        struct FunctionDelta: Decodable {
            let name: String?
            let arguments: String?
        }
    }
}

struct OpenAIStreamChoice: Decodable {
    let index: Int
    let delta: OpenAIStreamDelta
    let finishReason: String?

    enum CodingKeys: String, CodingKey {
        case index, delta
        case finishReason = "finish_reason"
    }
}

// 新增: Token使用量結構
struct OpenAIUsage: Decodable {
    let prompt_tokens: Int
    let completion_tokens: Int
    let total_tokens: Int
}

struct OpenAIStreamChunk: Decodable {
    let id: String
    let choices: [OpenAIStreamChoice]
    let usage: OpenAIUsage?  // 新增: 使用量欄位
}

// MARK: - 基本聊天資料結構
struct ChatMessage: Identifiable, Codable {
    let id = UUID()
    var text: String
    let isMe: Bool
    var pendingTasks: [PendingTask]?
    var pendingDeleteTasks: [TodoTask]?  // 新增：待刪除的任務
    
    // 修改為陣列以支援批量修改
    var pendingUpdateTasksOriginal: [TodoTask]?
    var pendingUpdateTasksUpdated: [PendingTask]?
    
    var isTaskConfirmed: Bool
    var isDeleteConfirmed: Bool  // 新增：是否確認刪除
    var isUpdateConfirmed: Bool  // 新增：是否確認修改
    var isProcessing: Bool
    var successCount: Int
    var failureCount: Int
    var isWaitingFunction: Bool  // 新增：等待函數執行的標記
    var currentExecutingFunction: String?
    var executingFunctions: [String]?  // 新增：追踪多個正在執行的函數名稱

    // 計算屬性，返回元組陣列
    var pendingUpdateTasks: [(original: TodoTask, updated: PendingTask)]? {
        get {
            if let originals = pendingUpdateTasksOriginal, let updateds = pendingUpdateTasksUpdated,
               originals.count == updateds.count, !originals.isEmpty {
                return zip(originals, updateds).map { (original: $0.0, updated: $0.1) }
            }
            return nil
        }
        set {
            if let newValue = newValue, !newValue.isEmpty {
                pendingUpdateTasksOriginal = newValue.map { $0.original }
                pendingUpdateTasksUpdated = newValue.map { $0.updated }
            } else {
                pendingUpdateTasksOriginal = nil
                pendingUpdateTasksUpdated = nil
            }
        }
    }

    // 為了向後兼容，保留單一任務修改的介面
    var pendingUpdateTask: (original: TodoTask, updated: PendingTask)? {
        get {
            if let tasks = pendingUpdateTasks, !tasks.isEmpty {
                return tasks.first
            }
            return nil
        }
        set {
            if let newValue = newValue {
                pendingUpdateTasks = [newValue]
            } else {
                pendingUpdateTasks = nil
            }
        }
    }

    init(
        text: String, isMe: Bool, pendingTasks: [PendingTask]? = nil,
        pendingDeleteTasks: [TodoTask]? = nil,  // 新增參數
        pendingUpdateTasks: [(original: TodoTask, updated: PendingTask)]? = nil,  // 修改為多個任務
        isTaskConfirmed: Bool = false,
        isDeleteConfirmed: Bool = false,  // 新增參數
        isUpdateConfirmed: Bool = false,  // 新增參數
        isProcessing: Bool = false,
        successCount: Int = 0,
        failureCount: Int = 0,
        isWaitingFunction: Bool = false,
        currentExecutingFunction: String? = nil,
        executingFunctions: [String]? = nil  // 新增參數
    ) {
        self.text = text
        self.isMe = isMe
        self.pendingTasks = pendingTasks
        self.pendingDeleteTasks = pendingDeleteTasks
        self.pendingUpdateTasksOriginal = pendingUpdateTasks?.map { $0.original }
        self.pendingUpdateTasksUpdated = pendingUpdateTasks?.map { $0.updated }
        self.isTaskConfirmed = isTaskConfirmed
        self.isDeleteConfirmed = isDeleteConfirmed
        self.isUpdateConfirmed = isUpdateConfirmed
        self.isProcessing = isProcessing
        self.successCount = successCount
        self.failureCount = failureCount
        self.isWaitingFunction = isWaitingFunction
        self.currentExecutingFunction = currentExecutingFunction
        self.executingFunctions = executingFunctions
    }

    // 自定義編碼解碼邏輯
    enum CodingKeys: String, CodingKey {
        case id, text, isMe, pendingTasks, pendingDeleteTasks
        case pendingUpdateTasksOriginal, pendingUpdateTasksUpdated
        case isTaskConfirmed, isDeleteConfirmed, isUpdateConfirmed
        case isProcessing, successCount, failureCount
        case isWaitingFunction, currentExecutingFunction, executingFunctions
    }
}

struct ChatRoom: Identifiable, Codable {
    let id = UUID()
    var name: String
    var messages: [ChatMessage]
}

// MARK: - 待確認的任務結構
struct PendingTask: Identifiable, Codable {
    let id: UUID
    let title: String
    let note: String
    let category: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let isCompleted: Bool
    let color: Color

    enum CodingKeys: String, CodingKey {
        case id, title, note, category, startDate, endDate, isAllDay, isCompleted, color
    }

    init(
        title: String, note: String, category: String, startDate: Date, endDate: Date,
        isAllDay: Bool, isCompleted: Bool, color: Color
    ) {
        self.id = UUID()
        self.title = title
        self.note = note
        self.category = category
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.isCompleted = isCompleted
        self.color = color
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        note = try container.decode(String.self, forKey: .note)
        category = try container.decode(String.self, forKey: .category)
        startDate = try container.decode(Date.self, forKey: .startDate)
        endDate = try container.decode(Date.self, forKey: .endDate)
        isAllDay = try container.decode(Bool.self, forKey: .isAllDay)
        isCompleted = try container.decode(Bool.self, forKey: .isCompleted)

        // 解碼顏色
        let colorData = try container.decode(Data.self, forKey: .color)
        if let uiColor = try NSKeyedUnarchiver.unarchivedObject(
            ofClass: UIColor.self, from: colorData)
        {
            color = Color(uiColor)
        } else {
            color = Color(red: 0.7, green: 0.16, blue: 0.13).opacity(0.4)  // 預設顏色
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(note, forKey: .note)
        try container.encode(category, forKey: .category)
        try container.encode(startDate, forKey: .startDate)
        try container.encode(endDate, forKey: .endDate)
        try container.encode(isAllDay, forKey: .isAllDay)
        try container.encode(isCompleted, forKey: .isCompleted)

        // 編碼顏色
        let uiColor = UIColor(color)
        let colorData = try NSKeyedArchiver.archivedData(
            withRootObject: uiColor, requiringSecureCoding: false)
        try container.encode(colorData, forKey: .color)
    }
}

// MARK: - 與 GPT 通訊的 View-Model
@MainActor
final class ChatViewModel: ObservableObject {
    private let proxyURL = URL(string: "https://gpt-proxy-api.studyassistant.workers.dev")!
    private let proxyToken = "my-secret-token"
    private let chatRoomsKey = "local_chat_rooms"
    
    @Published var staticViewModel: StaticViewModel?
    @Published var todoViewModel = TodoViewModel()
    
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // 當前的 GPT 對話任務
    private var currentTask: Task<String?, Never>?

    // 追蹤當前使用的函數
    @Published var currentFunction: String?
    @Published var isLoading: Bool = false
    @Published var conversationEndedSignal = UUID()  // 用於發送對話結束的信號

    // Firestore 相關
    private let db = Firestore.firestore()
    private let studySettingsCollection = "studySettings"

    // 使用者讀書設定
    @Published var studySettings: StudySettings?
    @Published var isLoadingSettings: Bool = false
    @Published var settingsError: String?

    // 聊天室資料
    @Published var chatRooms: [ChatRoom] = [
        ChatRoom(
            name: "新聊天室",
            messages: [
                ChatMessage(text: "我是讀書助手，有什麼可以幫您安排的讀書計劃嗎？", isMe: false)
            ])
    ] {
        willSet {
            // 在值改變之前儲存
            if let data = try? JSONEncoder().encode(chatRooms) {
                UserDefaults.standard.set(data, forKey: chatRoomsKey)
            }
        }
        
        didSet {
            // 限制最多 15 個聊天室，超過時自動刪除最舊的
            while chatRooms.count > 15 {
                chatRooms.removeFirst()
                // 調整 selectedRoomIndex，避免越界
                if selectedRoomIndex > 0 {
                    selectedRoomIndex -= 1
                }
            }
            
            // 限制每個聊天室最多 300 則訊息，超過時自動刪除最舊的
            for i in chatRooms.indices {
                if chatRooms[i].messages.count > 300 {
                    chatRooms[i].messages.removeFirst(chatRooms[i].messages.count - 300)
                }
            }
            
            // 儲存更新後的資料
            if let data = try? JSONEncoder().encode(chatRooms) {
                UserDefaults.standard.set(data, forKey: chatRoomsKey)
            }
        }
    }
    @Published var selectedRoomIndex: Int = 0  // 預設為 0，稍後在 init 設置為最新聊天室

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
            description:
                "Save one or multiple tasks to the system. All fields are required for each task.",
            parameters: ToolFunction.Parameters(
                type: "object",
                properties: [
                    "tasks": .init(
                        type: "array",
                        description:
                            "Array of tasks to save. Each task must include all required fields.",
                        items: .init(
                            type: "object",
                            properties: [
                                "title": .init(
                                    type: "string", description: "Task title (required)"),
                                "note": .init(type: "string", description: "Task note (required)"),
                                "category": .init(
                                    type: "string",
                                    description:
                                        "Task category (required), Based on these tasks, assign an overall category,based on the all task's title and note"
                                ),
                                "startDate": .init(
                                    type: "string",
                                    description: "Start date in ISO 8601 format (required)"),
                                "endDate": .init(
                                    type: "string",
                                    description: "End date in ISO 8601 format (required)"),
                                "isAllDay": .init(
                                    type: "string",
                                    description:
                                        "Whether the task is all day, must be 'true' or 'false' (required)"
                                ),
                                "isCompleted": .init(
                                    type: "string",
                                    description:
                                        "Whether the task is completed, must be 'true' or 'false' (required)"
                                ),
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
                                ),
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
            description: "End the current conversation and let the assistant say goodbye.",
            parameters: ToolFunction.Parameters(
                type: "object",
                properties: [:],
                required: []
            )
        )
    )

    // 在 tools 定義區域添加 deleteTask 函數
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
                                "taskId": .init(
                                    type: "string",
                                    description: "ID of the task to update (required)"
                                ),
                                "title": .init(
                                    type: "string",
                                    description: "New task title"
                                ),
                                "note": .init(
                                    type: "string",
                                    description: "New task note"
                                ),
                                "category": .init(
                                    type: "string",
                                    description: "New task category"
                                ),
                                "startDate": .init(
                                    type: "string",
                                    description: "New start date in ISO 8601 format"
                                ),
                                "endDate": .init(
                                    type: "string",
                                    description: "New end date in ISO 8601 format"
                                ),
                                "isAllDay": .init(
                                    type: "string",
                                    description: "Whether the task is all day, must be 'true' or 'false'"
                                ),
                                "isCompleted": .init(
                                    type: "string",
                                    description: "Whether the task is completed, must be 'true' or 'false'"
                                ),
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

    // 計算本次使用者發送後的 sendMessageToGPT 次數
    private var sendToGPTCount: Int = 0

    // 重設 sendToGPTCount
    public func resetSendToGPTCount() {
        sendToGPTCount = 0
    }

    // 檢查是否可以新增聊天室
    var canCreateNewChatRoom: Bool {
        let currentRoom = chatRooms[selectedRoomIndex]
        if currentRoom.name == "新聊天室" && currentRoom.messages.count <= 1 {
            return false
        }
        return true
    }

    // 新增聊天室
    func createNewChatRoom() {
        withAnimation {
            chatRooms.append(
                ChatRoom(
                    name: "新聊天室",
                    messages: [
                        ChatMessage(text: "我是讀書助手，有什麼可以幫您安排的讀書計劃嗎？", isMe: false)
                    ]))
            selectedRoomIndex = chatRooms.count - 1
        }
    }

    // 執行 getTime 函數並將結果添加到聊天記錄
    private func executeGetTime() -> String {
        currentFunction = "getTime"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        let currentTime = formatter.string(from: Date())
        currentFunction = nil
        return "現在時間是：\(currentTime)"
    }

    // 執行 getTask 函數並將結果添加到聊天記錄
    private func executeGetTask() async -> String {
        currentFunction = "getTask"
        let firebaseService = FirebaseService.shared
        do {
            // 從 Firebase 獲取任務
            let tasks = try await firebaseService.fetchTodoTasks()

            var taskString: String
            if tasks.isEmpty {
                taskString = "目前沒有任何任務。"
            } else {
                // 加入今日時間
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
                print("taskString: \(taskString)")
            }
            currentFunction = nil
            return taskString
        } catch {
            currentFunction = nil
            return "抱歉，無法獲取任務列表。請確保您已登入並且網路連接正常。"
        }
    }

    // 格式化日期
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: date)
    }

    // 檢查並創建類別統計
    private func checkAndCreateStatisticsForCategory(_ category: String) async {
        guard let staticViewModel = staticViewModel else { return }

        // 如果類別為空或為「未分類」，則不創建統計
        guard !category.isEmpty && category != "未分類" else {
            return
        }

        // 檢查此類別是否已存在於統計中
        let existingCategories = staticViewModel.statistics.map { $0.category }

        // 如果此類別不存在，建立新的統計記錄
        if !existingCategories.contains(category) {
            print("正在為新類別 \(category) 創建統計記錄")

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
                print("已成功為新類別 \(category) 創建統計記錄")
            } else {
                print("創建統計記錄失敗：\(staticViewModel.errorMessage ?? "未知錯誤")")
            }
        }
    }

    // 預定義的顏色選項
    private let colorOptions: [Color] = [
        Color(red: 0.7, green: 0.16, blue: 0.13).opacity(0.4),
        Color(red: 0.7, green: 0.56, blue: 0).opacity(0.4),
        Color(red: 0.18, green: 0.7, blue: 0.31).opacity(0.4),
        Color(red: 0.29, green: 0.28, blue: 0.7).opacity(0.4),
    ]

    // 執行保存任務函數
    private func executeSaveTask(arguments: String) async -> String {
        currentFunction = "saveTask"
        defer { currentFunction = nil }

        // 檢查當前訊息是否已有待確認的任務
        let currentMessageIndex = chatRooms[selectedRoomIndex].messages.count - 1
        if chatRooms[selectedRoomIndex].messages[currentMessageIndex].pendingTasks != nil {
            return "任務已經安排好了"
        }

        // 解析參數
        struct TaskArgs: Codable {
            let title: String
            let note: String
            let startDate: String
            let endDate: String
            let category: String?
            let isAllDay: String?
            let isCompleted: String?
            let color: String?

            // 為可選欄位提供預設值
            var resolvedCategory: String {
                return category ?? "未分類"
            }

            var resolvedIsAllDay: String {
                return isAllDay ?? "false"
            }

            var resolvedIsCompleted: String {
                return isCompleted ?? "false"
            }

            // 解析顏色字串為 Color
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

                return Color(red: components[0], green: components[1], blue: components[2]).opacity(
                    components[3])
            }
        }

        struct SaveTasksArgs: Codable {
            let tasks: [TaskArgs]
        }

        do {
            guard let jsonData = arguments.data(using: .utf8) else {
                print("無法將參數轉換為 JSON 數據")
                return "無法解析任務參數"
            }

            let args = try JSONDecoder().decode(SaveTasksArgs.self, from: jsonData)
            print("成功解析參數，共 \(args.tasks.count) 個任務")

            // 定義多種可能的日期格式
            let dateFormats = [
                "yyyy-MM-dd'T'HH:mm:ssXXX",  // 帶時區和秒
                "yyyy-MM-dd'T'HH:mm:ss",  // 帶秒，不帶時區
                "yyyy-MM-dd'T'HH:mmXXX",  // 帶時區，不帶秒
                "yyyy-MM-dd'T'HH:mm",  // 不帶時區和秒
            ]

            func parseDate(_ dateString: String) -> Date? {
                let dateFormatter = DateFormatter()
                dateFormatter.locale = Locale(identifier: "en_US_POSIX")
                dateFormatter.timeZone = TimeZone.current

                // 嘗試所有可能的格式
                for format in dateFormats {
                    dateFormatter.dateFormat = format
                    if let date = dateFormatter.date(from: dateString) {
                        return date
                    }
                }

                // 如果包含時區信息，嘗試移除時區後再解析
                if dateString.contains("+") || dateString.contains("-") {
                    let components = dateString.components(
                        separatedBy: CharacterSet(charactersIn: "+-"))
                    if let basicString = components.first {
                        return parseDate(basicString)
                    }
                }

                print("無法解析日期：\(dateString)")
                return nil
            }

            // 解析所有任務
            var pendingTasks: [PendingTask] = []

            for task in args.tasks {
                guard let startDate = parseDate(task.startDate),
                    let endDate = parseDate(task.endDate)
                else {
                    print("日期格式無效：startDate=\(task.startDate), endDate=\(task.endDate)")
                    return "日期格式無效"
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

                // 檢查並創建類別統計
                await checkAndCreateStatisticsForCategory(task.resolvedCategory)

                pendingTasks.append(pendingTask)
            }

            // 將待確認的任務存儲到當前訊息中
            chatRooms[selectedRoomIndex].messages[currentMessageIndex].pendingTasks = pendingTasks

            // 返回確認消息
            let taskCount = pendingTasks.count
            return "已創建 \(taskCount) 個待確認任務，描述安排的任務後，等待用戶確認中..."

        } catch {
            print("解析參數時發生錯誤：\(error)")
            return "解析任務參數時發生錯誤：\(error.localizedDescription)"
        }
    }

    // 確認並保存任務
    func confirmAndSaveTask(for messageId: UUID) async {
        guard
            let messageIndex = chatRooms[selectedRoomIndex].messages.firstIndex(where: {
                $0.id == messageId
            }),
            let tasks = chatRooms[selectedRoomIndex].messages[messageIndex].pendingTasks,
            !chatRooms[selectedRoomIndex].messages[messageIndex].isTaskConfirmed
        else {
            return
        }

        // 標記任務為處理中
        chatRooms[selectedRoomIndex].messages[messageIndex].isProcessing = true

        var successCount = 0
        var failureCount = 0

        // 保存每個任務
        for task in tasks {
            do {
                let todoTask = TodoTask(
                    title: task.title,
                    note: task.note,
                    color: task.color,  // 使用任務的顏色
                    focusTime: 0,
                    category: task.category,
                    isAllDay: task.isAllDay,
                    isCompleted: task.isCompleted,
                    repeatType: .none,
                    startDate: task.startDate,
                    endDate: task.endDate,
                    userId: ""
                )

                // 檢查並創建類別統計
                await checkAndCreateStatisticsForCategory(task.category)

                // 保存任務
                await todoViewModel.addTask(todoTask)
                successCount += 1
            } catch {
                print("Error saving task: \(error)")
                failureCount += 1
            }
        }

        // 更新成功/失敗計數
        chatRooms[selectedRoomIndex].messages[messageIndex].successCount = successCount
        chatRooms[selectedRoomIndex].messages[messageIndex].failureCount = failureCount

        // 完成處理並標記為已確認
        chatRooms[selectedRoomIndex].messages[messageIndex].isProcessing = false
        chatRooms[selectedRoomIndex].messages[messageIndex].isTaskConfirmed = true
    }

    // 拒絕任務
    func rejectTask(for messageId: UUID) {
        guard
            let messageIndex = chatRooms[selectedRoomIndex].messages.firstIndex(where: {
                $0.id == messageId
            })
        else { return }

        // 標記訊息為已確認，並設置失敗狀態
        chatRooms[selectedRoomIndex].messages[messageIndex].isTaskConfirmed = true
        chatRooms[selectedRoomIndex].messages[messageIndex].successCount = 0
        chatRooms[selectedRoomIndex].messages[messageIndex].failureCount =
            chatRooms[selectedRoomIndex].messages[messageIndex].pendingTasks?.count ?? 0

        // 不清除待確認任務，保留顯示
        // chatRooms[selectedRoomIndex].messages[messageIndex].pendingTasks = nil
    }

    // 執行 end_conversation 函數
    private func executeEndConversation() -> String {
        currentFunction = "end_conversation"
        defer {
            currentFunction = nil
            // 發送對話結束信號
            DispatchQueue.main.async {
                self.conversationEndedSignal = UUID()
            }
        }
        return "感謝您的使用，祝您學習順利！如果需要再次規劃，隨時歡迎找我聊天。"
    }

    // 追蹤上一次 tool_choice 與回覆型態
    private var lastToolChoice: String? = nil
    private var lastReplyType: String? = nil  // "text" or "function"

    // 在類的屬性部分添加新的變量來追踪多個函數調用
    private var functionCalls: [(name: String, arguments: String)] = []
    // 保留原有變量作為兼容，但將逐步替換為使用數組
    private var currentFunctionCall: String?
    private var currentArguments: String = ""

    // 在類的屬性部分替換原有的token計數相關變數
    @Published var totalTokensUsed: Int = 0
    private var lastRequestTokens: (prompt: Int, completion: Int, total: Int) = (0, 0, 0)

    @Published var keyboardHeight: CGFloat = 0  // 追蹤鍵盤高度

    // ----------------------------- 串流 GPT -----------------------------
    /// 對 GPT 串流，邊收到邊透過 onToken 回呼；結束後回傳完整內容
    func sendMessageToGPT(
        messages: [ChatMessage],
        onToken: ((String) -> Void)? = nil
    ) async -> String? {
        isLoading = true
        defer {
            // 只有在任務未被取消的情況下才關閉載入狀態
            if !Task.isCancelled {
                isLoading = false
            }
        }

        // 取消之前的任務（如果有的話）
        currentTask?.cancel()
        currentTask = nil

        // 清空之前的函數調用
        functionCalls = []
        currentFunctionCall = nil
        currentArguments = ""

        // 創建新任務
        let task = Task<String?, Never> {
        print("開始發送訊息到 GPT")
        let apiMsgs =
            messages
            .filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map { OpenAIMessage(role: $0.isMe ? "user" : "assistant", content: $0.text) }

        let tone = studySettings?.tone ?? "沉著穩重的專家"
        // 添加 system message 來指導 GPT 使用 function
        let systemMsg = OpenAIMessage(
            role: "system",
            content: """
                你可以安排計劃，目標是用最少的提問，為使用者排出具體且可執行的時間表。語氣為：\(tone)
                
                \(formatStudySettings())

                可用工具：
                getTask()      ：取得使用者現有任務與目前時間
                getTime()      ：取得目前時間
                saveTask({...}): 儲存新任務，所有欄位皆必填  
                end_conversation()：結束對話

                特別注意：
                1. **如果你要結束對話，請務必呼叫 end_conversation function，不要只用文字說再見。**
                2. 在以下情況要主動結束對話：
                    - 使用者明確表示要結束對話
                    - 使用者的需求已完整處理完畢
                    - 對話已經沒有明確目標或進展
                3. 講話講重點就好了。
                4. 不要重複呼叫同一個 function，除非有新需求或新資訊。
                5. 不要在文字裡打出要用的function。
                6. 詢問後不要使用任何function(除了end_conversation)，請詢問完後馬上使用end_conversation函式。
                7. 如有疑問需要向使用者請教，那先等使用者回答之後再使用除end_conversation外的function。
                8. 如果使用者沒有指定特別時段，那安排任務時間時必須遵守以下規則：
                    - 只能在使用者設定的可讀書日期和時間內安排任務
                    - 每個任務的持續時間應為設定的讀書時間（\(studySettings?.studyDuration ?? 60)分鐘）
                    - 不要在設定的時間範圍外安排任務
                    - 不要與原有的任務時間重疊
                9. 新增刪除修改任務前，務必特別再確認現在時間是什麼時候，並確認使用者已經有的任務。
                10. 新增、刪除、修改任務後要跟使用者解釋做了什麼改變。
                11. 安排任務時如果使用者要求安排很多任務（例如一兩百個任務），必須要遵從使用者的安排一次安排好一兩百個任務，不要先安排幾個然後再問使用者是否要安排更多。
                12. 使用者提到要幹嘛，請直接依照現在時間安排任務。
                13. 沒有指定時間就是現在。
                14. 不要叫使用者等待gpt安排任務。
                """
        )
        var allMessages = [systemMsg] + apiMsgs
        var full = ""
        var hasFunctionCall = false
        var endConversationReached = false

        while !endConversationReached {
                // 檢查任務是否被取消
                if Task.isCancelled {
                    print("任務被使用者取消")
                    return "任務已取消"  // 改為返回字符串而不是 nil
                }

            // 決定本次 tool_choice
            var toolChoice: String? = nil
            if sendToGPTCount == 0 {
                toolChoice = "none"
            } else if sendToGPTCount == 1 {
                toolChoice = "required"
            } else if let last = lastToolChoice {
                if last == "required" {
                    toolChoice = "auto"
                } else if last == "auto" {
                    if lastReplyType == "text" {
                        toolChoice = "required"
                    } else if lastReplyType == "function" {
                        toolChoice = "auto"
                    }
                }
            }

            let reqBody = OpenAIRequest(
                model: "gpt-4.1",
                messages: allMessages,
                temperature: 0.7,
                stream: true,
                tools: [
                        getTaskFunction, getTimeFunction, saveTaskFunction, deleteTaskFunction, updateTaskFunction, endConversationFunction,
                ],
                tool_choice: toolChoice,
                stream_options: ["include_usage": true]  // 啟用token計數
            )

            print("請求內容：\(String(describing: try? JSONEncoder().encode(reqBody)))")

            guard let data = try? encoder.encode(reqBody) else {
                print("編碼請求失敗")
                return nil
            }

            var req = URLRequest(url: proxyURL)
            req.httpMethod = "POST"
            req.addValue(proxyToken, forHTTPHeaderField: "x-api-token")
            req.addValue("application/json", forHTTPHeaderField: "Content-Type")
            req.addValue("text/event-stream", forHTTPHeaderField: "Accept")
            req.httpBody = data

            do {
                sendToGPTCount += 1
                print("開始發送請求（第 \(sendToGPTCount) 次）")
                print("本次 tool_choice: \(toolChoice ?? "nil")")
                print("傳送給 GPT 的訊息：")
                for msg in allMessages {
                    print("[\(msg.role)] \(msg.content)")
                }
                print("開始發送請求")
                let (bytes, resp) = try await retryOnError {
                    try await URLSession.shared.bytes(for: req, delegate: nil)
                }
                guard let httpResponse = resp as? HTTPURLResponse else {
                    print("回應不是 HTTP 回應")
                    return "無法連接到伺服器，請稍後再試"
                }
                print("收到回應，狀態碼：\(httpResponse.statusCode)")
                if httpResponse.statusCode != 200 {
                    return "伺服器回應錯誤（狀態碼：\(httpResponse.statusCode)），請稍後再試"
                }

                for try await line: AsyncLineSequence<URLSession.AsyncBytes>.AsyncIterator.Element
                    in bytes.lines
                {
                    // 檢查任務是否被取消
                        if Task.isCancelled {
                            print("在處理回應時任務被取消")
                            return "任務已取消"  // 改為返回字符串而不是 nil
                        }

                    guard line.hasPrefix("data: ") else {
                        print("跳過非資料行：\(line)")
                        continue
                    }
                    let payload = String(line.dropFirst(6))
                    print("收到資料：\(payload)")

                    if payload == "[DONE]" {
                        print("收到完成標記")

                            // 處理多個函數調用的情況
                            if !functionCalls.isEmpty {
                                print("準備執行多個函數，數量：\(functionCalls.count)")
                                    
                                for (index, functionCall) in functionCalls.enumerated() {
                                    let functionName = functionCall.name
                                    let arguments = functionCall.arguments
                                        
                                    print("執行函數(\(index+1)/\(functionCalls.count))：\(functionName)，參數：\(arguments)")
                                    var functionResult = ""
                                        
                                    if functionName == "getTask" {
                                        print("執行 getTask 函數")
                                        functionResult = await executeGetTask()
                                    } else if functionName == "getTime" {
                                        print("執行 getTime 函數")
                                        functionResult = executeGetTime()
                                    } else if functionName == "saveTask" {
                                        print("執行 saveTask 函數")
                                        functionResult = await executeSaveTask(arguments: arguments)
                                    } else if functionName == "end_conversation" {
                                        print("執行 end_conversation 函數")
                                        functionResult = executeEndConversation()
                                        endConversationReached = true
                                    } else if functionName == "deleteTask" {
                                        print("執行 deleteTask 函數")
                                        functionResult = await executeDeleteTask(arguments: arguments)
                                    } else if functionName == "updateTask" {
                                        print("執行 updateTask 函數")
                                        functionResult = await executeUpdateTask(arguments: arguments)
                                    }
                                        
                                    print("函數執行結果(\(index+1)/\(functionCalls.count))：\(functionResult)")
                                        
                                    // 只有 functionResult 非空時才 append function 回覆
                                    if !functionResult.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        // 重置等待函數執行狀態
                                        if let lastIndex = chatRooms[selectedRoomIndex].messages.indices.last {
                                            var updatedMessage = chatRooms[selectedRoomIndex].messages[lastIndex]
                                            updatedMessage.isWaitingFunction = false
                                            updatedMessage.currentExecutingFunction = nil
                                            updatedMessage.executingFunctions = nil
                                            chatRooms[selectedRoomIndex].messages[lastIndex] = updatedMessage
                                        }
                                            
                                        // 如果是 saveTask，將 function 的 arguments 也以 assistant 角色加入 allMessages
                                        if functionName == "saveTask" && !arguments.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                            allMessages.append(
                                                OpenAIMessage(
                                                    role: "assistant",
                                                    content: "執行函數: \(functionName)\n" + arguments,
                                                    name: nil,
                                                    tool_calls: nil
                                                )
                                            )
                                        }
                                        
                                        // 如果是 deleteTask，將 function 的 arguments 也以 assistant 角色加入 allMessages
                                        if functionName == "deleteTask" && !arguments.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                            allMessages.append(
                                                OpenAIMessage(
                                                    role: "assistant",
                                                    content: "執行函數: \(functionName)\n" + arguments,
                                                    name: nil,
                                                    tool_calls: nil
                                                )
                                            )
                                        }
                                        
                                        // 如果是 updateTask，將 function 的 arguments 也以 assistant 角色加入 allMessages
                                        if functionName == "updateTask" && !arguments.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                            allMessages.append(
                                                OpenAIMessage(
                                                    role: "assistant",
                                                    content: "執行函數: \(functionName)\n" + arguments,
                                                    name: nil,
                                                    tool_calls: nil
                                                )
                                            )
                                        }
                                            
                                        allMessages.append(
                                            OpenAIMessage(
                                                role: "function",
                                                content: functionResult,
                                                name: functionName
                                            ))
                                    }
                                }
                                    
                                // 標記本次回覆型態為 function
                                lastReplyType = "function"
                                lastToolChoice = toolChoice
                                    
                                // 重置 function calls 相關變量
                                functionCalls = []
                                currentFunctionCall = nil
                                currentArguments = ""
                                hasFunctionCall = true  // 標記已執行過 function，之後的文字要換行
                                    
                                break
                            }
                            // 保留原有的單一函數調用處理邏輯，作為兼容，未來可移除
                            else if let functionName: String = currentFunctionCall {
                            print("準備執行函數：\(functionName)，參數：\(currentArguments)")
                            var functionResult = ""

                            if functionName == "getTask" {
                                print("執行 getTask 函數")
                                functionResult = await executeGetTask()
                            } else if functionName == "getTime" {
                                print("執行 getTime 函數")
                                functionResult = executeGetTime()
                            } else if functionName == "saveTask" {
                                print("執行 saveTask 函數")
                                functionResult = await executeSaveTask(arguments: currentArguments)
                            } else if functionName == "end_conversation" {
                                print("執行 end_conversation 函數")
                                functionResult = executeEndConversation()
                                endConversationReached = true
                            } else if functionName == "deleteTask" {
                                print("執行 deleteTask 函數")
                                functionResult = await executeDeleteTask(arguments: currentArguments)
                                } else if functionName == "updateTask" {
                                    print("執行 updateTask 函數")
                                    functionResult = await executeUpdateTask(arguments: currentArguments)
                            }

                            print("函數執行結果：\(functionResult)")

                            // 只有 functionResult 非空時才 append function 回覆
                                if !functionResult.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                // 重置等待函數執行狀態
                                    if let lastIndex = chatRooms[selectedRoomIndex].messages.indices.last {
                                        var updatedMessage = chatRooms[selectedRoomIndex].messages[lastIndex]
                                    updatedMessage.isWaitingFunction = false
                                    updatedMessage.currentExecutingFunction = nil
                                        updatedMessage.executingFunctions = nil
                                        chatRooms[selectedRoomIndex].messages[lastIndex] = updatedMessage
                                }

                                // 如果是 saveTask，將 function 的 arguments 也以 assistant 角色加入 allMessages
                                    if functionName == "saveTask" && !currentArguments.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    allMessages.append(
                                        OpenAIMessage(
                                            role: "assistant",
                                                content: "執行函數: \(functionName)\n" + currentArguments,
                                                name: nil,
                                                tool_calls: nil
                                            )
                                        )
                                    }
                                        
                                    // 如果是 deleteTask，將 function 的 arguments 也以 assistant 角色加入 allMessages
                                    if functionName == "deleteTask" && !currentArguments.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        allMessages.append(
                                            OpenAIMessage(
                                                role: "assistant",
                                                content: "執行函數: \(functionName)\n" + currentArguments,
                                                name: nil,
                                                tool_calls: nil
                                            )
                                        )
                                    }
                                        
                                    // 如果是 updateTask，將 function 的 arguments 也以 assistant 角色加入 allMessages
                                    if functionName == "updateTask" && !currentArguments.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        allMessages.append(
                                            OpenAIMessage(
                                                role: "assistant",
                                                content: "執行函數: \(functionName)\n" + currentArguments,
                                            name: nil,
                                            tool_calls: nil
                                        )
                                    )
                                }

                                allMessages.append(
                                    OpenAIMessage(
                                        role: "function",
                                        content: functionResult,
                                        name: functionName
                                    ))
                            }

                            // 標記本次回覆型態為 function
                            lastReplyType = "function"
                            lastToolChoice = toolChoice

                            // 重置 function call 相關變量
                            currentFunctionCall = nil
                            currentArguments = ""
                            hasFunctionCall = true  // 標記已執行過 function，之後的文字要換行

                            break
                        }
                        // 在 [DONE] 處理完整回覆
                        if !full.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            allMessages.append(
                                OpenAIMessage(
                                    role: "assistant", content: full, name: nil, tool_calls: nil))
                        }
                        break
                    }

                    if let json = payload.data(using: .utf8),
                        let chunk = try? decoder.decode(OpenAIStreamChunk.self, from: json)
                    {
                            if let usage = chunk.usage {
                                print("Token使用量 - 提示詞: \(usage.prompt_tokens), 回應: \(usage.completion_tokens), 總計: \(usage.total_tokens)")
                                
                                // 儲存本次請求的token使用量
                                lastRequestTokens = (usage.prompt_tokens, usage.completion_tokens, usage.total_tokens)
                                totalTokensUsed += usage.total_tokens
                                
                                // 寫入Firebase
                                Task {
                                    await updateTokenUsageInFirebase(
                                        tokenCount: usage.total_tokens,
                                        promptTokens: usage.prompt_tokens,
                                        completionTokens: usage.completion_tokens,
                                        model: reqBody.model  // 使用請求體中的模型
                                    )
                                }
                            } else if let toolCalls = chunk.choices.first?.delta.tool_calls {
                                // 處理每個工具調用
                                for toolCall in toolCalls {
                            hasFunctionCall = true

                                    let callIndex = toolCall.index
                                    
                                    if let name = toolCall.function?.name {
                                        print("收到函數名稱（索引\(callIndex)）：\(name)")
                                        
                                        // 無論是哪個索引的函數調用，都更新currentExecutingFunction
                                currentFunctionCall = name
                                        
                                        // 添加到函數調用數組或更新現有函數調用
                                        if functionCalls.count <= callIndex {
                                            // 擴展數組以容納新索引
                                            while functionCalls.count <= callIndex {
                                                functionCalls.append((name: "", arguments: ""))
                                            }
                                            // 設置函數名稱
                                            functionCalls[callIndex].name = name
                                        } else {
                                            // 更新已有函數調用的名稱
                                            functionCalls[callIndex].name = name
                                        }
                                        
                                // 批量更新最後一條消息的狀態，但 end_conversation 不顯示載入動畫
                                        if let lastIndex = chatRooms[selectedRoomIndex].messages.indices.last {
                                            var updatedMessage = chatRooms[selectedRoomIndex].messages[lastIndex]
                                    // 只有在不是 end_conversation 時才顯示載入動畫
                                    if name != "end_conversation" {
                                        updatedMessage.isWaitingFunction = true
                                                
                                            // 始終更新currentExecutingFunction為最新的函數名稱
                                        updatedMessage.currentExecutingFunction = name
                                                
                                            // 不再使用executingFunctions數組
                                            updatedMessage.executingFunctions = nil
                                    }
                                            chatRooms[selectedRoomIndex].messages[lastIndex] = updatedMessage
                                }
                            }
                                    
                                    if let args = toolCall.function?.arguments {
                                        print("收到函數參數（索引\(callIndex)）：\(args)")
                                        
                                        // 更新對應函數調用的參數
                                        if callIndex < functionCalls.count {
                                            functionCalls[callIndex].arguments += args
                                        } else {
                                            // 擴展數組以容納新索引，並設置參數
                                            while functionCalls.count <= callIndex {
                                                functionCalls.append((name: "", arguments: ""))
                                            }
                                            functionCalls[callIndex].arguments = args
                                        }
                                        
                                        // 保留原有兼容
                                        if callIndex == 0 {
                                currentArguments += args
                                        }
                                    }
                            }
                        } else if let piece = chunk.choices.first?.delta.content {
                            print("hasFunctionCall: \(hasFunctionCall)")
                            print("收到文字：\(piece)")
                            // 如果是 function 執行完後的第一段文字，加入換行
                            if hasFunctionCall {
                                // 不保留之前的文字，直接從函數調用後的回覆開始
                                full = ""
                                hasFunctionCall = false  // 重置標記
                                print("收到函數調用後的第一段文字：\(piece)")
                                // 批量更新消息狀態
                                    if let lastIndex = chatRooms[selectedRoomIndex].messages.indices.last {
                                        var updatedMessage = chatRooms[selectedRoomIndex].messages[lastIndex]
                                    updatedMessage.isWaitingFunction = false
                                    updatedMessage.currentExecutingFunction = nil
                                        updatedMessage.executingFunctions = nil
                                        chatRooms[selectedRoomIndex].messages[lastIndex] = updatedMessage
                                }
                                await onToken?("\n")
                            } else if full.isEmpty {
                                // 如果是第一段文字（不是函數調用後），正常添加
                                full = piece
                                await onToken?(piece)
                            } else {
                                // 否則正常累加文字
                                full += piece
                                await onToken?(piece)
                            }

                            // 標記本次回覆型態為 text
                            lastReplyType = "text"
                            lastToolChoice = toolChoice
                        }
                    }
                }
            } catch is CancellationError {
                print("任務被取消")
                return nil
            } catch {
                print("發生錯誤：\(error.localizedDescription)")
                if let urlError = error as? URLError {
                    return "網路錯誤：\(urlError.localizedDescription)"
                }
                return "發生錯誤：\(error.localizedDescription)"
            }
        }

        print("對話結束，hasFunctionCall: \(hasFunctionCall), full: \(full)")
        
        // 不需要在這裡計算token使用量，因為已經在接收到usage時處理了
        
        return full
        }
        
        // 保存任務引用
        currentTask = task
        
        // 等待任務完成
        return await task.value
    }

    // ----------------------------- 產生標題（非串流） -----------------------------
    // 更新generateTitle方法以處理token使用量
    func generateTitle(from firstUserMessage: String) async -> String? {
        let sys = OpenAIMessage(
            role: "system", content: "你是一個摘要大師，請根據使用者的第一句話，生成最多8個字的摘要。直接輸出名稱不要有簡體字。")
        let usr = OpenAIMessage(role: "user", content: firstUserMessage)
        let body = OpenAIRequest(
            model: "gpt-4.1-mini",
            messages: [sys, usr],
            temperature: 0.2,
            stream: false,
            tools: nil,
            tool_choice: nil,
            stream_options: nil
        )
        let result = await callOpenAIOnce(with: body)
        
        // 不需要再計算token用量，因為API回應已包含實際使用量
        
        return result
    }

    // ----------------------------- Helper (一次回整段) -----------------------------
    private func callOpenAIOnce(with body: OpenAIRequest) async -> String? {
        guard let data = try? encoder.encode(body) else { return nil }
        var req = URLRequest(url: proxyURL)
        req.httpMethod = "POST"
        req.addValue(proxyToken, forHTTPHeaderField: "x-api-token")
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = data
        do {
            let (respData, resp) = try await retryOnError {
                try await URLSession.shared.data(for: req)
            }
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            if let res = try? decoder.decode(OpenAIResponse.self, from: respData),
                let choice = res.choices.first
            {
                // 處理token使用量
                if let usage = res.usage {
                    print("非串流請求 - Token使用量：提示詞 \(usage.prompt_tokens)，回應 \(usage.completion_tokens)，總計 \(usage.total_tokens)")
                    totalTokensUsed += usage.total_tokens
                    
                    // 寫入Firebase
                    Task {
                        await updateTokenUsageInFirebase(
                            tokenCount: usage.total_tokens,
                            promptTokens: usage.prompt_tokens,
                            completionTokens: usage.completion_tokens,
                            model: body.model
                        )
                    }
                }
                
                return choice.message.content.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } catch {}
        return nil
    }

    // MARK: - 聊天室管理
    func deleteChatRoom(at index: Int) {
        guard chatRooms.count > 1 else { return }  // 確保至少保留一個聊天室

        // 如果要刪除的是當前選中的聊天室
        if index == selectedRoomIndex {
            // 如果刪除的是最後一個聊天室，選中前一個
            if index == chatRooms.count - 1 {
                selectedRoomIndex = index - 1
            }
            // 否則保持當前索引（會自動顯示下一個聊天室）
        }
        // 如果刪除的聊天室在當前選中的聊天室之前，需要調整選中索引
        else if index < selectedRoomIndex {
            selectedRoomIndex -= 1
        }

        // 刪除聊天室
        chatRooms.remove(at: index)

        // 如果刪除後沒有聊天室了，創建一個新的
        if chatRooms.isEmpty {
            chatRooms.append(
                ChatRoom(
                    name: "新聊天室",
                    messages: [
                        ChatMessage(text: "我是讀書助手，有什麼可以幫您安排的讀書計劃嗎？", isMe: false)
                    ]))
            selectedRoomIndex = 0
        }
    }

    private func saveChatRoomsToLocal() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async { [weak self] in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                
                do {
                    let data = try JSONEncoder().encode(self.chatRooms)
                    UserDefaults.standard.set(data, forKey: self.chatRoomsKey)
                } catch {
                    print("儲存本地聊天記錄失敗: \(error)")
                }
                
                continuation.resume()
            }
        }
    }

    func loadChatRoomsFromLocal() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            if let data = UserDefaults.standard.data(forKey: self.chatRoomsKey) {
                do {
                    let decoded = try JSONDecoder().decode([ChatRoom].self, from: data)
                    DispatchQueue.main.async {
                        self.chatRooms = decoded
                    }
                } catch {
                    print("載入本地聊天記錄失敗: \(error)")
                }
            }
        }
    }

    // MARK: - 讀書設定相關方法

    // 從Firestore載入讀書設定
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
                // 文件不存在，建立預設設定
                print("無現有讀書設定，建立預設值")
                let newSettings = StudySettings(userId: userId)
                self.studySettings = newSettings

                // 儲存新建立的預設設定到Firestore
                try await saveStudySettingsToFirestore(settings: newSettings)
            }
        } catch {
            settingsError = "載入讀書設定失敗: \(error.localizedDescription)"
            print("載入讀書設定錯誤: \(error)")
        }

        isLoadingSettings = false
    }

    // 儲存讀書設定到Firestore
    private func saveStudySettingsToFirestore(settings: StudySettings) async throws {
        guard !settings.userId.isEmpty else {
            throw NSError(
                domain: "app.studyAssistant", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "未指定使用者ID"])
        }

        let docRef = db.collection(studySettingsCollection).document(settings.userId)

        // 更新時間戳
        var settingsToSave = settings
        settingsToSave.updatedAt = Timestamp()

        try await docRef.setData(settingsToSave.toFirestoreData())
        print("成功儲存讀書設定到Firestore")
    }

    // 更新讀書設定
    func updateStudySettings(_ newSettings: StudySettings) async {
        guard let userId = Auth.auth().currentUser?.uid else {
            settingsError = "尚未登入，無法更新讀書設定"
            return
        }

        isLoadingSettings = true
        settingsError = nil
        currentFunction = "updateStudySettings"

        do {
            var settingsToUpdate = newSettings
            settingsToUpdate.userId = userId
            try await saveStudySettingsToFirestore(settings: settingsToUpdate)
            self.studySettings = settingsToUpdate
        } catch {
            settingsError = "更新讀書設定失敗: \(error.localizedDescription)"
            print("更新讀書設定錯誤: \(error)")
        }

        isLoadingSettings = false
        currentFunction = nil
    }

    // 添加格式化讀書設定的輔助函數
    private func formatStudySettings() -> String {
        guard let settings = studySettings else {
            return "尚未設定讀書習慣"
        }

        var result = "使用者的讀書習慣設定：\n讀書時段如下：\n"

        for day in settings.selectedDays.sorted() {
            let dayString = String(day)
            
            if let startHour = settings.dailyStartHours[dayString],
                let startMinute = settings.dailyStartMinutes[dayString],
                let endHour = settings.dailyEndHours[dayString],
                let endMinute = settings.dailyEndMinutes[dayString]
            {

                let weekday =
                    switch day {
                    case 1: "星期一"
                    case 2: "星期二"
                    case 3: "星期三"
                    case 4: "星期四"
                    case 5: "星期五"
                    case 6: "星期六"
                    case 7: "星期日"
                    default: "未知"
                    }

                result +=
                    "\(weekday)：\(String(format: "%02d:%02d", startHour, startMinute)) - \(String(format: "%02d:%02d", endHour, endMinute))\n"
            }
        }
        result += "每次讀書時間：\(Int(settings.studyDuration))分鐘\n"

        return result
    }

    // 修改重試機制
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
                
                // 嘗試執行操作
                let result = try await operation()
                
                // 檢查不同類型的結果，處理 HTTP 429 狀態碼
                if let (_, response) = result as? (Data, URLResponse),
                   let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 429 {
                    print("收到 Data 請求的 429 狀態碼")
                    attempts += 1
                    continue
                }
                
                if let (_, response) = result as? (URLSession.AsyncBytes, URLResponse),
                   let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 429 {
                    print("收到串流請求的 429 狀態碼")
                    attempts += 1
                    continue
                }
                
                // 如果沒有 429 錯誤，返回結果
                return result
                
            } catch let urlError as URLError {
                print("捕獲到 URLError: \(urlError.localizedDescription), code: \(urlError.code.rawValue)")
                lastError = urlError
                
                // 檢查是否是因為伺服器負載過重的錯誤
                if urlError.code == .networkConnectionLost ||
                   urlError.code == .timedOut ||
                   urlError.code == .notConnectedToInternet {
                    attempts += 1
                    print("網絡錯誤: \(urlError.localizedDescription)，進行第 \(attempts) 次重試")
                    continue
                }
                
                // 伺服器過載通常也會造成這些錯誤，嘗試重試
                attempts += 1
                if attempts >= maxAttempts {
                    print("已達到最大重試次數")
                    throw urlError
                }
                print("URLError，正在進行第 \(attempts) 次重試")
                continue
                
            } catch {
                print("捕獲到其他錯誤: \(error.localizedDescription)")
                lastError = error
                attempts += 1
                if attempts >= maxAttempts {
                    print("已達到最大重試次數，最後一次錯誤: \(error.localizedDescription)")
                    throw error
                }
                print("發生錯誤，正在進行第 \(attempts) 次重試")
                continue
            }
        }
        
        throw lastError ?? URLError(.timedOut)
    }

    // 修改執行刪除任務的函數
    private func executeDeleteTask(arguments: String) async -> String {
        currentFunction = "deleteTask"
        defer { currentFunction = nil }

        // 檢查當前訊息是否已有待確認的刪除任務
        let currentMessageIndex = chatRooms[selectedRoomIndex].messages.count - 1
        if chatRooms[selectedRoomIndex].messages[currentMessageIndex].pendingDeleteTasks != nil {
            return "已有待確認的刪除任務，請等待用戶處理。"
        }

        // 解析參數
        struct DeleteTaskArgs: Codable {
            let taskIds: [String]
        }

        do {
            guard let jsonData = arguments.data(using: .utf8) else {
                print("無法將參數轉換為 JSON 數據")
                return "無法解析任務參數"
            }

            let args = try JSONDecoder().decode(DeleteTaskArgs.self, from: jsonData)
            print("成功解析參數，準備刪除 \(args.taskIds.count) 個任務")

            // 獲取要刪除的任務資訊
            var tasksToDelete: [TodoTask] = []
            let allTasks = todoViewModel.tasks  // 直接使用 tasks 屬性
            
            for taskId in args.taskIds {
                if let task = allTasks.first(where: { $0.id == taskId }) {
                    tasksToDelete.append(task)
                }
            }

            if tasksToDelete.isEmpty {
                return "找不到指定的任務"
            }

            // 將待刪除的任務存儲到當前訊息中
            chatRooms[selectedRoomIndex].messages[currentMessageIndex].pendingDeleteTasks = tasksToDelete

            // 返回確認消息
            return "已找到 \(tasksToDelete.count) 個待刪除任務，等待用戶確認中..."

        } catch {
            print("解析參數時發生錯誤：\(error)")
            return "解析任務參數時發生錯誤：\(error.localizedDescription)"
        }
    }

    // 執行更新任務函數
    private func executeUpdateTask(arguments: String) async -> String {
        currentFunction = "updateTask"
        defer { currentFunction = nil }

        // 檢查當前訊息是否已有待更新的任務
        let currentMessageIndex = chatRooms[selectedRoomIndex].messages.count - 1
        if chatRooms[selectedRoomIndex].messages[currentMessageIndex].pendingUpdateTasks != nil {
            return "已有待確認的任務更新，請等待用戶處理。"
        }

        // 解析參數
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
                print("無法將參數轉換為 JSON 數據")
                return "無法解析任務參數"
            }

            let args = try JSONDecoder().decode(UpdateTasksArgs.self, from: jsonData)
            print("成功解析參數，準備更新 \(args.tasks.count) 個任務")
            
            if args.tasks.isEmpty {
                return "未提供任何要更新的任務"
            }

            // 獲取所有任務
            let allTasks = todoViewModel.tasks
            
            // 儲存待更新的任務
            var tasksToUpdate: [(original: TodoTask, updated: PendingTask)] = []
            
            for taskArg in args.tasks {
                // 查找原任務
                guard let originalTask = allTasks.first(where: { $0.id == taskArg.taskId }) else {
                    return "找不到 ID 為 \(taskArg.taskId) 的任務"
                }
                
                // 創建新的 PendingTask，保留未修改的值
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
                
                tasksToUpdate.append((original: originalTask, updated: updatedTask))
            }
            
            // 儲存待更新的任務到當前訊息
            chatRooms[selectedRoomIndex].messages[currentMessageIndex].pendingUpdateTasks = tasksToUpdate

            return "已準備好 \(tasksToUpdate.count) 個任務更新，等待用戶確認中..."

        } catch {
            print("解析參數時發生錯誤：\(error)")
            return "解析任務參數時發生錯誤：\(error.localizedDescription)"
        }
    }

    // 解析日期字串的輔助函數
    private func parseDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }
        
        let dateFormats = [
            "yyyy-MM-dd'T'HH:mm:ssXXX",  // 帶時區和秒
            "yyyy-MM-dd'T'HH:mm:ss",  // 帶秒，不帶時區
            "yyyy-MM-dd'T'HH:mmXXX",  // 帶時區，不帶秒
            "yyyy-MM-dd'T'HH:mm",  // 不帶時區和秒
        ]

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone.current

        // 嘗試所有可能的格式
        for format in dateFormats {
            dateFormatter.dateFormat = format
            if let date = dateFormatter.date(from: dateString) {
                return date
            }
        }

        // 如果包含時區信息，嘗試移除時區後再解析
        if dateString.contains("+") || dateString.contains("-") {
            let components = dateString.components(separatedBy: CharacterSet(charactersIn: "+-"))
            if let basicString = components.first {
                return parseDate(basicString)
            }
        }

        print("無法解析日期：\(dateString)")
        return nil
    }

    // 解析顏色字串的輔助函數
    private func parseColor(_ colorString: String?) -> Color? {
        guard let colorStr = colorString else { return nil }

        let components = colorStr.split(separator: ",").compactMap {
            Double($0.trimmingCharacters(in: .whitespaces))
        }
        guard components.count == 4 else { return nil }

        return Color(red: components[0], green: components[1], blue: components[2]).opacity(components[3])
    }

    // 確認並更新任務
    func confirmAndUpdateTask(for messageId: UUID) async {
        guard
            let messageIndex = chatRooms[selectedRoomIndex].messages.firstIndex(where: { $0.id == messageId }),
            let updateDataList = chatRooms[selectedRoomIndex].messages[messageIndex].pendingUpdateTasks,
            !chatRooms[selectedRoomIndex].messages[messageIndex].isUpdateConfirmed
        else {
            return
        }

        // 標記為處理中
        chatRooms[selectedRoomIndex].messages[messageIndex].isProcessing = true

        var successCount = 0
        var failureCount = 0
        
        // 逐一處理每個任務更新
        for updateData in updateDataList {
            do {
                // 創建更新後的 TodoTask
                var updatedTask = updateData.original
                updatedTask.title = updateData.updated.title
                updatedTask.note = updateData.updated.note
                updatedTask.color = updateData.updated.color
                updatedTask.category = updateData.updated.category
                updatedTask.isAllDay = updateData.updated.isAllDay
                updatedTask.isCompleted = updateData.updated.isCompleted
                updatedTask.startDate = updateData.updated.startDate
                updatedTask.endDate = updateData.updated.endDate

                // 檢查並創建類別統計（如果類別已更改）
                if updateData.original.category != updatedTask.category {
                    await checkAndCreateStatisticsForCategory(updatedTask.category)
                }

                // 保存更新的任務
                try await todoViewModel.updateTask(updatedTask)
                successCount += 1
            } catch {
                print("Error updating task: \(error)")
                failureCount += 1
            }
        }

        // 更新成功/失敗計數
        chatRooms[selectedRoomIndex].messages[messageIndex].successCount = successCount
        chatRooms[selectedRoomIndex].messages[messageIndex].failureCount = failureCount

        // 完成處理並標記為已確認
        chatRooms[selectedRoomIndex].messages[messageIndex].isProcessing = false
        chatRooms[selectedRoomIndex].messages[messageIndex].isUpdateConfirmed = true
    }

    // 拒絕更新任務
    func rejectUpdateTask(for messageId: UUID) {
        guard let messageIndex = chatRooms[selectedRoomIndex].messages.firstIndex(where: { $0.id == messageId })
        else { return }

        // 標記訊息為已確認，並設置失敗狀態
        chatRooms[selectedRoomIndex].messages[messageIndex].isUpdateConfirmed = true
        chatRooms[selectedRoomIndex].messages[messageIndex].successCount = 0
        chatRooms[selectedRoomIndex].messages[messageIndex].failureCount = 1
    }

    // 確認刪除任務的函數
    func confirmAndDeleteTask(for messageId: UUID) async {
        guard
            let messageIndex = chatRooms[selectedRoomIndex].messages.firstIndex(where: { $0.id == messageId }),
            let tasks = chatRooms[selectedRoomIndex].messages[messageIndex].pendingDeleteTasks,
            !chatRooms[selectedRoomIndex].messages[messageIndex].isDeleteConfirmed
        else {
            return
        }

        // 標記為處理中
        chatRooms[selectedRoomIndex].messages[messageIndex].isProcessing = true

        var successCount = 0
        var failureCount = 0

        // 按類別分組任務，用於後續更新統計
        var tasksByCategory: [String: [TodoTask]] = [:]

        // 刪除每個任務
        for task in tasks {
            do {
                // 收集任務的類別信息
                if !task.category.isEmpty && task.category != "未分類" {
                    tasksByCategory[task.category, default: []].append(task)
                }
                
                try await todoViewModel.deleteTask(task)  // 直接傳遞 TodoTask 物件
                successCount += 1
            } catch {
                print("Error deleting task: \(error)")
                failureCount += 1
            }
        }
        
        // 更新統計類別
        if let staticViewModel = staticViewModel {
            for (category, categoryTasks) in tasksByCategory {
                // 查找是否還有該類別的任務
                let remainingTasksCount = todoViewModel.tasks.filter { $0.category == category }.count - categoryTasks.count
                
                if remainingTasksCount <= 0 {
                    // 如果沒有剩餘任務，刪除該統計類別
                    if let statistic = staticViewModel.statistics.first(where: { $0.category == category }),
                       let statisticId = statistic.id {
                        // 使用 id 刪除該統計類別
                        await staticViewModel.deleteStatistic(statisticId)
                    }
                } else {
                    // 更新該類別的任務計數
                    let completedCount = todoViewModel.tasks.filter { $0.category == category && $0.isCompleted }.count - categoryTasks.filter { $0.isCompleted }.count
                    await staticViewModel.updateCategoryTaskStats(category: category, completedCount: completedCount, totalCount: remainingTasksCount)
                }
            }
        }

        // 更新成功/失敗計數
        chatRooms[selectedRoomIndex].messages[messageIndex].successCount = successCount
        chatRooms[selectedRoomIndex].messages[messageIndex].failureCount = failureCount

        // 完成處理並標記為已確認
        chatRooms[selectedRoomIndex].messages[messageIndex].isProcessing = false
        chatRooms[selectedRoomIndex].messages[messageIndex].isDeleteConfirmed = true
    }

    // 拒絕刪除任務的函數
    func rejectDeleteTask(for messageId: UUID) {
        guard let messageIndex = chatRooms[selectedRoomIndex].messages.firstIndex(where: { $0.id == messageId })
        else { return }

        // 標記訊息為已確認，並設置失敗狀態
        chatRooms[selectedRoomIndex].messages[messageIndex].isDeleteConfirmed = true
        chatRooms[selectedRoomIndex].messages[messageIndex].successCount = 0
        chatRooms[selectedRoomIndex].messages[messageIndex].failureCount =
            chatRooms[selectedRoomIndex].messages[messageIndex].pendingDeleteTasks?.count ?? 0
    }

    // 添加到 cases 中
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
            return executeEndConversation()
        default:
            return "未知函數：\(functionName)"
        }
    }

    init() {
        loadChatRoomsFromLocal()
        if !chatRooms.isEmpty {
            selectedRoomIndex = chatRooms.count - 1
        }
        Task {
            await loadStudySettingsFromFirestore()
        }
    }

    // 取消當前任務
    func cancelCurrentTask() {
        currentTask?.cancel()
        currentTask = nil
        isLoading = false
        currentFunction = nil
        functionCalls = []
        currentFunctionCall = nil
        currentArguments = ""
        
        // 取消時重置當前请求的token計數
        lastRequestTokens = (0, 0, 0)
    }

    // 將token使用量更新到Firebase
    private func updateTokenUsageInFirebase(tokenCount: Int, promptTokens: Int? = nil, completionTokens: Int? = nil, model: String) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let userTokensRef = db.collection("userStatistics").document(userId)
        
        do {
            // 先檢查文件是否存在
            let docSnapshot = try await userTokensRef.getDocument()
            
            // 準備要更新的數據
            var updateData: [String: Any] = [
                "totalTokens": FieldValue.increment(Int64(tokenCount)),
                "lastUpdated": Timestamp(date: Date())
            ]
            
            // 更新模型使用量
            let modelKey = model.replacingOccurrences(of: ".", with: "-")  // 將 4.1 改為 4-1
            updateData["modelUsage.\(modelKey).total"] = FieldValue.increment(Int64(tokenCount))
            
            if let promptTokens = promptTokens {
                updateData["modelUsage.\(modelKey).prompt"] = FieldValue.increment(Int64(promptTokens))
            }
            
            if let completionTokens = completionTokens {
                updateData["modelUsage.\(modelKey).completion"] = FieldValue.increment(Int64(completionTokens))
            }
            
            if docSnapshot.exists {
                // 更新現有文件
                try await userTokensRef.updateData(updateData)
            } else {
                // 建立新文件
                var modelData: [String: Int] = ["total": tokenCount]
                if let promptTokens = promptTokens {
                    modelData["prompt"] = promptTokens
                }
                if let completionTokens = completionTokens {
                    modelData["completion"] = completionTokens
                }
                
                let initialData: [String: Any] = [
                    "totalTokens": tokenCount,
                    "lastUpdated": Timestamp(date: Date()),
                    "modelUsage": [
                        modelKey: modelData
                    ]
                ]
                
                try await userTokensRef.setData(initialData)
            }
            
            print("成功更新token使用量：\(tokenCount) tokens，模型：\(model)")
        } catch {
            print("更新token使用量失敗：\(error.localizedDescription)")
        }
    }

    // 新增一個用於最終儲存的方法
    private func finalSave() {
        let chatRoomsData = try? JSONEncoder().encode(chatRooms)
        if let data = chatRoomsData {
            UserDefaults.standard.set(data, forKey: chatRoomsKey)
        }
    }
}
