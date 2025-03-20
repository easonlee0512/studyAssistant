//
//  ChatViewModel.swift
//  ttest
//
//  Created by Bruce on 2025/3/4.
//

import Foundation

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
    
    // 同時提供一個無參數的初始化方法，用於預覽或測試
    convenience init() {
        self.init(dataStore: AppDataStore())
    }

    private func getCurrentTime() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/M/d"  // 設定日期格式為：年/月/日
        return formatter.string(from: Date())  // 將當前時間轉換為字串
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/M/d"  // 設定日期格式為：年/月/日
        return formatter.string(from: date)  // 將輸入的日期轉換為字串
    }
    
    //解析回傳格式
    private func parseGPTResponse(_ response: String) -> [TodoItem] {
        // 檢查是否包含***標記
        if response.contains("***") {
            // 提取***之間的內容
            let components = response.components(separatedBy: "***")
            if components.count >= 2 {
                let planContent = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                // 將計畫內容按換行符號分割成多行
                let lines = planContent.components(separatedBy: .newlines)
                // 創建一個空陣列來存儲解析後的 TodoItem
                var items: [TodoItem] = []
                
                // 創建日期格式化器，用於解析日期字串
                let dateFormatter = DateFormatter()
                // 設定日期格式為 "yyyy-MM-dd"，例如 "2025-03-21"
                dateFormatter.dateFormat = "yyyy-MM-dd"
                
                // 遍歷每一行計畫內容
                for line in lines {
                    // 將每行用 ": " 分割成兩部分：日期和內容
                    let components = line.components(separatedBy: ": ")
                    // 確保分割後有兩個部分，並且可以成功解析日期
                    guard components.count == 2,
                          let dateString = components.first,
                          let date = dateFormatter.date(from: dateString) else {
                        continue  // 如果解析失敗，跳過這一行
                    }
                    
                    // 獲取冒號後面的內容部分
                    let content = components[1]
                    // 使用完整內容作為標題
                    let title = content
                    
                    // 創建日曆實例，用於處理日期時間
                    let calendar = Calendar.current
                    
                    // 設定開始時間為當天的早上9點
                    var startTimeComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
                    startTimeComponents.hour = 0+8 //因為是UTC+8
                    startTimeComponents.minute = 0
                    startTimeComponents.second = 0
                    
                    // 使用日曆來創建完整的日期時間
                    if let startTime = calendar.date(from: startTimeComponents) {
                        // 確保日期和開始時間是同一天
                        let item = TodoItem(
                            title: title,
                            date: calendar.startOfDay(for: startTime),  // 使用開始時間的日期
                            startTime: startTime,
                            durationHours: 2,
                            isCompleted: false
                        )
                        // 將創建的項目添加到陣列中
                        items.append(item)
                    }
                }
                
                // 除錯：印出所有解析結果
                print("=== TodoItems 解析結果 ===")
                for (index, item) in items.enumerated() {
                    print("項目 \(index + 1):")
                    print("  標題: \(item.title)")
                    print("  日期: \(item.date)")
                    print("  開始時間: \(item.startTime)")
                    print("  持續時間: \(item.durationHours)小時")
                    print("  完成狀態: \(item.isCompleted)")
                    print("---")
                }
                
                // 返回解析後的 TodoItem 陣列
                return items
            }
        }
        // 如果沒有***標記，返回空陣列
        return []
    }

    func sendMessage() {
        // 檢查必填欄位
        isPlanTitleEmpty = planTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        isSubjectRangeEmpty = subjectRange.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        
        // 如果有必填欄位未填寫，不發送消息
        if isPlanTitleEmpty || isSubjectRangeEmpty {
            return
        }

        let prompt = """
請依據以下資訊，為我規劃一份詳細且可實際執行的讀書計劃：
- 閱讀標題：\(planTitle)
- 閱讀範圍總量：\(subjectRange)
  （例如：「第 1～200 頁」或「第 1～10 章」，請以實際可拆分的區段視為單位）
- 目前進度：0%（尚未開始）
- 當前時間：\(getCurrentTime())
- 完成截止日期：\(formatDate(deadline))（必須在此日期前完成）
- 偏好讀書時段：\(preferredTime)
- 其他備註：\(note)

請執行下列步驟：
1. 計算從今天（含）到截止日期（含）之間的總天數。
2. 根據「閱讀範圍總量」的實際單位（如頁數或章節），將其平均分配到這些天數，並依序列出每一天對應的閱讀區段（例如，第 1-10 頁、第 11-20 頁；或第 1-2 章、第 3-4 章）。
3. 若有餘數或拆分不均，請將剩餘部分分配到其中一些天，使得所有閱讀都能在截止日期之前完成。若平均分配後仍不足以在截止日前讀完，則在部分天數上額外增加更大區段。
4. 最後，請僅使用以下格式逐日列出結果（無須任何額外解釋或其他文字），輸出日期前先加上***，輸出完後加上***：
{YYYY-MM-DD}: {閱讀標題} - {該日對應的閱讀區段}

例如：
***
2025-03-21: 計算機科學導論 - 第 1～10 頁
2025-03-22: 計算機科學導論 - 第 11～20 頁
***
... 以此類推，直到全部範圍分配完畢。

請謹記：不得添加與此無關的內容，否則後果將非常嚴重。務必確保在截止日前可讀完所有內容。並且只能輸出規定{YYYY-MM-DD}: {閱讀標題} - {該日對應的閱讀區段}，絕對不能有任何解釋。並且只印出第四點的格式，絕對不能有任何解釋。前三點的內容不要印出來。
"""
        
        // 先顯示 prompt
        DispatchQueue.main.async {
            self.messages.append("Prompt: \(prompt)")
        }
        
        OpenAIService.fetchGPTResponse(prompt: prompt) { response in
            DispatchQueue.main.async {
                if let response = response {
                    self.messages.append(response)
                    // 解析回應並轉換為 TodoItem（現在會處理***標記）
                    self.todoItems = self.parseGPTResponse(response)
                    
                    // 將解析後的 todoItems 添加到共享數據存儲中
                    self.dataStore.addTodoItems(self.todoItems)
                } else {
                    self.messages.append("AI 無法回應")
                }
            }
        }
    }
    
    // 發送自定義消息
    func sendCustomMessage(_ message: String) {
        // 添加用戶消息
        self.messages.append("我: \(message)")
        
        // 獲取已存儲在dataStore中的todoItems
        let existingItems = self.dataStore.todoItems
        
        // 構建包含已建立計畫內容的字符串
        var existingPlanContent = ""
        if !existingItems.isEmpty {
            existingPlanContent = "您已建立的具體計畫內容如下：\n"
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            
            for item in existingItems {
                let dateString = dateFormatter.string(from: item.date)
                existingPlanContent += "\(dateString): \(item.title)\n"
            }
        }
        
        // 構建提示詞，包含之前的計畫信息和已建立的計畫項目
        let prompt = """
您是一位專業的讀書計畫助手。用戶已經創建了以下讀書計畫：
- 閱讀標題：\(planTitle)
- 閱讀範圍：\(subjectRange)
- 完成截止日期：\(formatDate(deadline))
- 偏好讀書時段：\(preferredTime)
- 備註：\(note)

\(existingPlanContent)

請針對用戶的以下問題提供協助，回答應該簡潔專業，但也要保持溫暖友善的語氣。
如果用戶要求修改或新增計畫內容，請在回答後另起一行加上***，然後列出修改後的計畫內容，最後再加上***，格式如下：
***
{YYYY-MM-DD}: {閱讀標題} - {該日對應的閱讀區段}
***

用戶的問題是：\(message)
"""
        
        // 先顯示 prompt
        DispatchQueue.main.async {
            self.messages.append("Prompt: \(prompt)")
        }
        
        // 調用OpenAI API
        OpenAIService.fetchGPTResponse(prompt: prompt) { response in
            DispatchQueue.main.async {
                if let response = response {
                    // 解析可能的計畫內容
                    let newTodoItems = self.parseGPTResponse(response)
                    if !newTodoItems.isEmpty {
                        // 清除舊的計畫內容
                        self.dataStore.clearTodoItems()
                        // 添加新的計畫內容
                        self.dataStore.addTodoItems(newTodoItems)
                    }
                    
                    // 顯示完整回應，包括計畫內容
                    self.messages.append("助手: \(response)")
                } else {
                    self.messages.append("助手: 抱歉，我現在無法回應。請稍後再試。")
                }
            }
        }
    }
}
