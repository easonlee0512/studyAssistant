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
    
    @Published var isPlanTitleEmpty: Bool = false
    @Published var isSubjectRangeEmpty: Bool = false

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
        // 將 GPT 的回應文字按換行符號分割成多行
        let lines = response.components(separatedBy: .newlines)
        // 創建一個空陣列來存儲解析後的 TodoItem
        var items: [TodoItem] = []
        
        // 創建日期格式化器，用於解析日期字串
        let dateFormatter = DateFormatter()
        // 設定日期格式為 "yyyy-MM-dd"，例如 "2025-03-21"
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        // 遍歷每一行回應
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
            startTimeComponents.hour = 9
            startTimeComponents.minute = 0
            startTimeComponents.second = 0
            
            // 使用日曆來創建完整的日期時間
            if let startTime = calendar.date(from: startTimeComponents) {
                // 確保日期和開始時間是同一天
                let item = TodoItem(
                    title: title,
                    date: calendar.startOfDay(for: startTime),  // 使用開始時間的日期
                    startTime: startTime,
                    durationHours: 2.0,
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
4. 最後，請僅使用以下格式逐日列出結果（無須任何額外解釋或其他文字）：
{YYYY-MM-DD}: {閱讀標題} - {該日對應的閱讀區段}

例如：
2025-03-21: 計算機科學導論 - 第 1～10 頁
2025-03-22: 計算機科學導論 - 第 11～20 頁
... 以此類推，直到全部範圍分配完畢。

請謹記：不得添加與此無關的內容，否則後果將非常嚴重。務必確保在截止日前可讀完所有內容。
"""
        
        // 先顯示 prompt
        DispatchQueue.main.async {
            self.messages.append("Prompt: \(prompt)")
        }
        
        OpenAIService.fetchGPTResponse(prompt: prompt) { response in
            DispatchQueue.main.async {
                if let response = response {
                    self.messages.append(response)
                    
                    // 解析回應並轉換為 TodoItem
                    self.todoItems = self.parseGPTResponse(response)
                } else {
                    self.messages.append("AI 無法回應")
                }
            }
        }
    }
}
