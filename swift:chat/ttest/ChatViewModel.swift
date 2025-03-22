class ChatViewModel: ObservableObject {
    @Published var messages: [String] = []
    @Published var planTitle: String = "" // 新增計畫標題
    @Published var subjectRange: String = "" // 新增科目範圍
    @Published var deadline: Date = Date() // 改為 Date 類型
    @Published var preferredTime: String = "" // 新增讀書偏好時間
    @Published var note: String = "" // 新增備注
    @Published var todoItems: [TodoItem] = []//日曆item
    
    // 添加對 AppDataStore 的引用
    private var dataStore: AppDataStore
    
    @Published var isPlanTitleEmpty: Bool = false
    @Published var isSubjectRangeEmpty: Bool = false
    
    // 初始化方法
    init(dataStore: AppDataStore) {
        self.dataStore = dataStore
    }
    
    // 同時提供一個無參數的初始化方法，用於測試或預覽
    convenience init() {
        self.init(dataStore: AppDataStore())
    }
    
    func sendMessage() {
        // 檢查必填欄位
        isPlanTitleEmpty = planTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        isSubjectRangeEmpty = subjectRange.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        
        // 如果有必填欄位未填寫，不發送消息
        if isPlanTitleEmpty || isSubjectRangeEmpty {
            return
        }

        // ... existing code ...
        
        OpenAIService.fetchGPTResponse(prompt: prompt) { response in
            DispatchQueue.main.async {
                if let response = response {
                    self.messages.append(response)
                    
                    // 解析回應並轉換為 TodoItem
                    self.todoItems = self.parseGPTResponse(response)
                    
                    // 將解析後的 todoItems 添加到共享數據存儲中
                    self.dataStore.addTodoItems(self.todoItems)
                } else {
                    self.messages.append("AI 無法回應")
                }
            }
        }
    }
} 