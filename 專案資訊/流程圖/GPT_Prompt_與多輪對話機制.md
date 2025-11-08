# GPT Prompt 與多輪對話機制

本文件說明讀書助手 App 中 AI 對話系統的 Prompt 構成、傳輸機制，以及多輪對話的實作原理。

---

## 一、Prompt 的組成結構

AI 對話系統的 Prompt 由三個主要部分組成，每次發送請求時都會包含這些完整資訊。

### 1.1 System Message（系統訊息）

System Message 是 AI 助理的「角色設定與行為準則」，定義了 AI 的身份、語氣、以及必須遵守的規則。

#### 核心內容

```swift
// 位置: ChatViewModel.swift 第 1070-1103 行
let systemMsg = OpenAIMessage(
    role: "system",
    content: """
        你可以安排計劃，目標是用最少的提問，為使用者排出具體且可執行的時間表。
        語氣為：\(tone)

        \(formatStudySettings())

        特別注意：
        1. 如果你要結束對話，請務必呼叫 end_conversation function
        2. 在以下情況要主動結束對話：
           - 使用者明確表示要結束對話
           - 使用者的需求已完整處理完畢
           - 對話已經沒有明確目標或進展
        3. 講話講重點就好了
        4. 不要重複呼叫同一個 function，除非有新需求或新資訊
        ...（共17條規則）
        """
)
```

#### System Message 包含的資訊

| 項目                        | 說明                             | 來源                      |
| --------------------------- | -------------------------------- | ------------------------- |
| **角色定義**          | AI 作為「讀書計劃助手」的身份    | 固定文字                  |
| **語氣設定**          | 使用者偏好的對話語氣             | `studySettings?.tone`   |
| **讀書習慣**          | 使用者的可讀書時段、每次讀書時間 | `formatStudySettings()` |
| **行為規範**          | 17 條具體的行為準則              | 固定規則                  |
| **Function 使用指引** | 何時該呼叫哪些函數               | 固定規則                  |

**範例：使用者讀書設定（formatStudySettings）**

```
使用者的讀書習慣設定：
讀書時段如下：
星期一：09:00 - 17:00
星期三：14:00 - 18:00
星期五：09:00 - 12:00
每次讀書時間：60分鐘
```

### 1.2 Conversation History（對話歷史）

對話歷史記錄了使用者與 AI 之間的所有互動，確保 AI 能理解上下文。

#### 訊息格式轉換

```swift
// 位置: ChatViewModel.swift 第 1063-1066 行
let apiMsgs = messages
    .filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    .map { OpenAIMessage(role: $0.isMe ? "user" : "assistant", content: $0.text) }
```

#### 角色映射

| App 內部角色     | OpenAI API 角色 | 說明                     |
| ---------------- | --------------- | ------------------------ |
| `isMe = true`  | `user`        | 使用者發送的訊息         |
| `isMe = false` | `assistant`   | AI 助理的回應            |
| N/A              | `function`    | 函數執行結果（自動加入） |

**對話歷史範例**（包含完整 Function Calling 流程）：

```json
[
  {"role": "user", "content": "幫我安排明天讀書"},
  {"role": "assistant", "content": "好的，請問明天幾點方便？"},
  {"role": "user", "content": "早上9點"},

  // AI 呼叫查詢類函數（getTime, getTask）
  // 系統直接回傳結果，不額外記錄 assistant 訊息
  {"role": "function", "name": "getTime", "content": "2025/01/15 10:30:00"},
  {"role": "function", "name": "getTask", "content": "{\"currentTime\":\"2025-01-15T10:30:00\",\"existingTasks\":[]}"},

  // AI 呼叫操作類函數（saveTask）
  // 系統會先記錄函數呼叫細節（僅針對 saveTask/deleteTask/updateTask）
  {"role": "assistant", "content": "執行函數: saveTask\n{\"tasks\":[{\"title\":\"讀書\",\"startDate\":\"2025-01-16T09:00:00+08:00\",\"endDate\":\"2025-01-16T10:00:00+08:00\",...}]}"},

  // 系統回傳儲存結果
  {"role": "function", "name": "saveTask", "content": "已成功新增 1 個任務"},

  // AI 根據所有資訊生成最終回應
  {"role": "assistant", "content": "已為您安排明天早上9-10點的讀書時間"}
]
```

**重要說明**：
- **查詢類函數**（getTask, getTime）：只記錄函數執行結果
- **操作類函數**（saveTask, deleteTask, updateTask）：會額外記錄函數呼叫細節作為 assistant 訊息
- 這種設計讓 AI 能記住它執行了哪些具體操作，特別是批量操作時（參見 ChatViewModel.swift:1245-1279）

### 1.3 Available Tools（可用工具）

定義 AI 可以呼叫的函數清單，包括函數名稱、描述、參數結構。

```swift
// 位置: ChatViewModel.swift 第 1139-1141 行
tools: [
    getTaskFunction,      // 獲取任務列表
    getTimeFunction,      // 獲取當前時間
    saveTaskFunction,     // 儲存新任務
    deleteTaskFunction,   // 刪除任務
    updateTaskFunction,   // 更新任務
    endConversationFunction  // 結束對話
]
```

每個函數都包含完整的 JSON Schema 定義（參見 [GPT_Function_Calling_說明.md](GPT_Function_Calling_說明.md)）。

---

## 二、Prompt 的傳輸機制

### 2.1 請求封裝

所有資訊會被封裝成 `OpenAIRequest` 結構，並編碼為 JSON 格式。

```swift
// 位置: ChatViewModel.swift 第 1134-1145 行
let reqBody = OpenAIRequest(
    model: "gpt-4.1",                    // 使用的 GPT 模型
    messages: allMessages,               // System + 對話歷史 + 函數結果
    temperature: 1.0,                    // 回應的隨機性
    stream: true,                        // 啟用串流回應
    tools: [...],                        // 可用的函數清單
    tool_choice: toolChoice,             // 函數呼叫策略
    stream_options: ["include_usage": true],  // 包含 Token 使用量
    reasoning_effort: nil                // GPT-4.1 不需要
)
```

### 2.2 網路傳輸路徑

#### 完整對話流程（包含 Function Calling）

```
┌─────────────────────────────────────────────────────────────┐
│ 階段 1: 發送訊息到 OpenAI                                    │
└─────────────────────────────────────────────────────────────┘

iOS App (ChatViewModel)
    ↓ [HTTPS POST]
    ↓ JSON Request Body
    ↓
Firebase Cloud Functions - chatProxy
    URL: https://asia-east1-studyassistant-f7172.cloudfunctions.net/chatProxy
    ↓ [轉發請求 + 驗證 API Key]
    ↓
OpenAI API Server (GPT-4.1)
    ↓ [Server-Sent Events (SSE) 串流]
    ↓ data: {...content chunk...}
    ↓ data: {...tool_calls...}  ← AI 決定呼叫函數
    ↓ data: [DONE]
    ↓
Firebase Cloud Functions - chatProxy
    ↓ [轉發回應]
    ↓
iOS App (ChatViewModel)
    解析函數呼叫請求


┌─────────────────────────────────────────────────────────────┐
│ 階段 2: 執行函數（操作類函數需要與 Firebase 互動）          │
└─────────────────────────────────────────────────────────────┘

iOS App (ChatViewModel)
    執行函數判斷：
    ├─ getTime/getTask → 本地執行
    │   ↓
    │   回傳結果並繼續對話
    │
    └─ saveTask/deleteTask/updateTask → 需要 Firebase
        ↓ [HTTPS POST]
        ↓ JSON Function Data
        ↓
    Firebase Cloud Functions - createTask/updateTask/deleteTask
        URL: https://asia-east1-studyassistant-f7172.cloudfunctions.net/{functionName}
        ↓ [驗證使用者身份]
        ↓ [處理任務資料]
        ↓
    Firestore Database
        Collection: tasks/{userId}/userTasks/{taskId}
        ↓ [讀取/寫入/更新/刪除]
        ↓
    Firebase Cloud Functions
        ↓ [回傳操作結果]
        ↓ {"success": true, "message": "已成功新增 1 個任務"}
        ↓
    iOS App (ChatViewModel)
        ↓ 將函數結果加入對話歷史
        ↓ 重新整理本地任務清單
        ↓


┌─────────────────────────────────────────────────────────────┐
│ 階段 3: 繼續對話（將函數結果發送回 OpenAI）                 │
└─────────────────────────────────────────────────────────────┘

iOS App (ChatViewModel)
    ↓ [HTTPS POST]
    ↓ 包含函數執行結果的 JSON Request Body
    ↓
Firebase Cloud Functions - chatProxy
    ↓ [轉發請求]
    ↓
OpenAI API Server (GPT-4.1)
    AI 根據函數結果生成最終回應
    ↓ [SSE 串流]
    ↓ data: {...content chunk...}
    ↓ data: [DONE]
    ↓
Firebase Cloud Functions - chatProxy
    ↓ [轉發回應]
    ↓
iOS App (ChatViewModel)
    逐字更新 UI，對話完成
```

**為什麼使用 Cloud Functions Proxy？**

- **安全性**: API Key 不暴露在客戶端
- **計費控制**: 統一管理 API 使用量
- **錯誤處理**: 集中式錯誤處理與重試機制

### 2.3 HTTP 請求細節

```swift
// 位置: ChatViewModel.swift 第 1154-1158 行
var req = URLRequest(url: proxyURL)
req.httpMethod = "POST"
req.addValue("application/json", forHTTPHeaderField: "Content-Type")
req.addValue("text/event-stream", forHTTPHeaderField: "Accept")  // SSE 格式
req.httpBody = data  // JSON 編碼的請求體
```

### 2.4 串流回應處理

系統使用 **Server-Sent Events (SSE)** 技術接收 AI 的回應，實現逐字顯示的效果。

```swift
// 位置: ChatViewModel.swift 第 1169-1195 行
let (bytes, resp) = try await URLSession.shared.bytes(for: req, delegate: nil)

for try await line in bytes.lines {
    guard line.hasPrefix("data: ") else { continue }
    let payload = String(line.dropFirst(6))

    if payload == "[DONE]" {
        // 處理完成標記
        break
    }

    // 解析 JSON chunk
    if let json = payload.data(using: .utf8),
       let chunk = try? decoder.decode(OpenAIStreamChunk.self, from: json) {
        // 提取文字或函數呼叫
        if let piece = chunk.choices.first?.delta.content {
            await onToken?(piece)  // 即時回調顯示文字
        }
    }
}
```

**串流回應的優勢**：

- ✅ 即時反饋，使用者體驗更佳
- ✅ 降低感知延遲
- ✅ 可以提前取消長時間的回應

---

## 三、多輪對話的彙整機制

### 3.1 對話累積架構

系統使用 `allMessages` 陣列來累積整個對話的完整脈絡。

```swift
// 位置: ChatViewModel.swift 第 1104 行
var allMessages = [systemMsg] + apiMsgs
```

**每次發送請求時的訊息結構**：

```
allMessages = [
    System Message (固定角色設定),
    User Message 1,
    Assistant Response 1,
    Function Result 1,
    User Message 2,
    Assistant Response 2,
    Function Result 2,
    ...
    User Message N (當前)
]
```

### 3.2 函數執行結果的整合

當 AI 呼叫函數後，執行結果會以 `function` 角色加入對話歷史。

```swift
// 位置: ChatViewModel.swift 第 1281-1286 行
allMessages.append(
    OpenAIMessage(
        role: "function",
        content: functionResult,  // 例如: "已成功新增 3 個任務"
        name: functionName        // 例如: "saveTask"
    )
)
```

**函數結果整合範例**：

```
使用者: "幫我安排明天讀書"
    ↓
AI 呼叫 getTime()
    ↓
系統回傳: "2025/01/15 10:30:00"
    ↓ (加入 allMessages)
AI 呼叫 getTask()
    ↓
系統回傳: "{...任務清單...}"
    ↓ (加入 allMessages)
AI 呼叫 saveTask({...})
    ↓
系統回傳: "已成功新增 1 個任務"
    ↓ (加入 allMessages)
AI 根據所有資訊生成最終回應
    ↓
AI: "已為您安排明天早上9-10點的讀書時間"
```

### 3.3 多輪對話循環機制

系統使用 `while` 迴圈實現多輪對話，直到對話自然結束。

```swift
// 位置: ChatViewModel.swift 第 1109-1531 行
while !endConversationReached {
    // 1. 決定 tool_choice 策略
    var toolChoice: String? = nil
    if sendToGPTCount == 0 {
        toolChoice = "none"       // 第一次：理解需求
    } else if sendToGPTCount == 1 {
        toolChoice = "required"   // 第二次：強制使用函數
    } else {
        // 後續：根據上次回應動態調整
        toolChoice = determineToolChoice()
    }

    // 2. 發送請求到 OpenAI
    let response = await sendRequest(allMessages, toolChoice)

    // 3. 處理回應
    if response.containsFunctionCall {
        // 執行函數並將結果加入 allMessages
        let result = await executeFunction(response.functionCall)
        allMessages.append(functionResultMessage(result))

        // 檢查是否為 endConversation
        if response.functionCall.name == "end_conversation" {
            endConversationReached = true
        }

        // 繼續下一輪對話，讓 AI 根據函數結果生成回應
        continue
    }

    if response.containsText {
        // 收到文字回應，這一輪對話完成
        allMessages.append(assistantMessage(response.text))
        break
    }
}
```

### 3.4 對話狀態追蹤

系統透過多個變數追蹤對話狀態，確保多輪對話的連貫性。

| 變數                       | 類型            | 用途                                     |
| -------------------------- | --------------- | ---------------------------------------- |
| `sendToGPTCount`         | Int             | 記錄本次使用者提問後的請求次數           |
| `lastToolChoice`         | String?         | 上一次的 tool_choice 設定                |
| `lastReplyType`          | String?         | 上一次的回應類型（"text" 或 "function"） |
| `endConversationReached` | Bool            | 是否觸發結束對話                         |
| `allMessages`            | [OpenAIMessage] | 累積的完整對話記錄                       |

---

## 四、Tool Choice 智慧策略

Tool Choice 是控制 AI 何時呼叫函數的關鍵機制，直接影響對話的流暢度與效率。

### 4.1 策略演算法

```swift
// 位置: ChatViewModel.swift 第 1117-1132 行
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
```

### 4.2 三種 Tool Choice 模式

| 模式               | 說明                           | 使用時機                  |
| ------------------ | ------------------------------ | ------------------------- |
| **none**     | 禁止呼叫函數，只能生成文字回應 | 第1次對話：理解使用者需求 |
| **required** | 強制呼叫至少一個函數           | 第2次對話：獲取必要資訊   |
| **auto**     | AI 自行判斷是否需要呼叫函數    | 後續對話：保持彈性        |

### 4.3 策略決策樹

```
使用者發送訊息
    ↓
sendToGPTCount = 0 （重置計數）
    ↓
┌────────────────────────────────┐
│ 第 1 次請求                     │
│ tool_choice = "none"            │
│ → AI 理解需求並回應             │
└────────────────────────────────┘
    ↓
使用者可能繼續對話或提供更多資訊
    ↓
┌────────────────────────────────┐
│ 第 2 次請求                     │
│ tool_choice = "required"        │
│ → AI 必須呼叫函數獲取資訊       │
│   (通常是 getTime 或 getTask)   │
└────────────────────────────────┘
    ↓
AI 呼叫函數並獲得結果
    ↓
┌────────────────────────────────┐
│ 第 3 次請求                     │
│ tool_choice = "auto"            │
│ → AI 根據情況決定               │
│   可能繼續呼叫函數或生成回應    │
└────────────────────────────────┘
    ↓
若 AI 選擇回應文字 (lastReplyType = "text")
    ↓
┌────────────────────────────────┐
│ 第 4 次請求                     │
│ tool_choice = "required"        │
│ → 鼓勵 AI 採取行動              │
└────────────────────────────────┘
    ↓
若 AI 選擇呼叫函數 (lastReplyType = "function")
    ↓
┌────────────────────────────────┐
│ 第 5 次請求                     │
│ tool_choice = "auto"            │
│ → 給予 AI 彈性                  │
└────────────────────────────────┘
```

### 4.4 策略設計理念

**為什麼第一次設為 "none"？**

- 讓 AI 先理解使用者的完整需求
- 避免過早呼叫函數，導致誤解使用者意圖
- 提升對話的自然度

**為什麼第二次設為 "required"？**

- 強制 AI 獲取必要資訊（時間、現有任務等）
- 避免 AI 憑空猜測或提供不準確的建議
- 確保決策基於真實資料

**為什麼後續使用動態策略？**

- 平衡效率與自然度
- 若 AI 剛說話，鼓勵它行動（required）
- 若 AI 剛行動，讓它自由判斷（auto）
- 形成「對話 → 行動 → 對話 → 行動」的節奏

---

## 五、完整對話流程範例

### 範例：使用者請求安排讀書時間

**使用者**: "幫我這週每天安排2小時讀書時間"

#### 第 1 輪（tool_choice = "none"）

**發送到 OpenAI**:

```json
{
  "messages": [
    {"role": "system", "content": "你可以安排計劃...（完整 system prompt）"},
    {"role": "user", "content": "幫我這週每天安排2小時讀書時間"}
  ],
  "tool_choice": "none"
}
```

**AI 回應**: "好的，我來幫您安排本週的讀書時間。請稍等，我先確認當前時間和您現有的任務安排。"

#### 第 2 輪（tool_choice = "required"）

**發送到 OpenAI**:

```json
{
  "messages": [
    {"role": "system", "content": "..."},
    {"role": "user", "content": "幫我這週每天安排2小時讀書時間"},
    {"role": "assistant", "content": "好的，我來幫您安排..."}
  ],
  "tool_choice": "required"
}
```

**AI 呼叫**: `getTime()` 和 `getTask()`

**函數結果**:

```json
{
  "messages": [
    ...（前面的對話）,
    {"role": "function", "name": "getTime", "content": "2025/01/15 10:30:00"},
    {"role": "function", "name": "getTask", "content": "{\"existingTasks\": [...]}"}
  ]
}
```

#### 第 3 輪（tool_choice = "auto"）

AI 分析資料後決定呼叫 `saveTask()`，批量新增 7 個任務。

**函數結果**:

```json
{
  "messages": [
    ...（前面的對話和函數結果）,
    {"role": "function", "name": "saveTask", "content": "已成功新增 7 個任務"}
  ]
}
```

#### 第 4 輪（tool_choice = "auto"）

**AI 最終回應**: "我已經為您安排好本週每天的讀書時間：\n- 週一 14:00-16:00\n- 週二 14:00-16:00\n...\n祝您學習順利！"

**AI 呼叫**: `endConversation()`

**對話結束**

---

## 六、技術特點與優勢

### 6.1 上下文保持

✅ **完整對話歷史**

- 每次請求都包含從對話開始到當前的所有訊息
- AI 能理解跨多輪的複雜指令
- 支援使用者修改或追加需求

✅ **函數結果整合**

- 函數執行結果自動加入對話歷史
- AI 基於真實資料做決策，而非猜測

### 6.2 效能優化

✅ **串流回應**

- 使用 Server-Sent Events (SSE) 技術
- 逐字顯示，降低感知延遲
- 可隨時取消長時間的生成

✅ **智慧策略**

- 動態調整 tool_choice，減少不必要的函數呼叫
- 平衡效率與自然度

### 6.3 錯誤處理

✅ **重試機制**

- 網路錯誤自動重試（最多 3 次）
- 指數退避策略（1.5 秒 × 嘗試次數）

✅ **任務取消**

- 支援使用者隨時取消正在進行的對話
- 避免浪費 API 資源

### 6.4 安全性

✅ **API Key 隔離**

- 使用 Cloud Functions Proxy
- 客戶端永不接觸 API Key

✅ **使用者資料隔離**

- 所有函數呼叫都綁定當前使用者 ID
- 無法存取其他使用者的資料

---

## 七、實作位置索引

| 功能               | 檔案位置                          |
| ------------------ | --------------------------------- |
| Proxy URL 定義     | `ChatViewModel.swift:422`       |
| System Prompt 構建 | `ChatViewModel.swift:1070-1103` |
| 對話歷史轉換       | `ChatViewModel.swift:1063-1066` |
| 請求封裝           | `ChatViewModel.swift:1134-1145` |
| HTTP 請求設定      | `ChatViewModel.swift:1154-1158` |
| 串流回應處理       | `ChatViewModel.swift:1169-1520` |
| Tool Choice 策略   | `ChatViewModel.swift:1117-1132` |
| 多輪對話循環       | `ChatViewModel.swift:1109-1531` |
| 函數結果整合       | `ChatViewModel.swift:1281-1286` |
| 錯誤重試機制       | `ChatViewModel.swift:1920-1995` |

---

## 八、總結

本系統透過精心設計的 Prompt 結構、智慧的 Tool Choice 策略，以及完善的多輪對話彙整機制，實現了流暢且高效的 AI 對話體驗。

**核心設計理念**：

1. **完整上下文**: 確保 AI 理解整個對話脈絡
2. **真實資料驅動**: 基於函數呼叫獲得的真實資料做決策
3. **智慧策略**: 動態調整行為，平衡效率與自然度
4. **即時反饋**: 串流技術提供良好的使用者體驗
5. **安全可靠**: Cloud Functions Proxy 確保 API Key 安全

這些機制共同構成了一個既智慧又可靠的 AI 助理系統，能夠理解使用者需求、執行實際操作，並提供自然流暢的對話體驗。
