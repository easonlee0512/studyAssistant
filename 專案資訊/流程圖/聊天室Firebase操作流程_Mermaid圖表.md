# 聊天室 Firebase 操作流程 - Mermaid 圖表

本文件提供讀書助手 App 聊天室與 Firebase 互動流程的 Mermaid 視覺化圖表。

---

## 零、GPT Function 到 Firebase 簡化流程

### 0.1 核心路徑圖（簡潔版）

```mermaid
flowchart LR
    GPT[GPT 決定呼叫<br/>saveTask/deleteTask/updateTask]

    GPT -->|回傳 tool_calls| ChatVM[ChatViewModel<br/>解析函數呼叫]

    ChatVM -->|HTTPS POST| CF[Firebase Cloud Functions<br/>createTask/updateTask/deleteTask]

    CF -->|1. 驗證身份| Auth[Firebase Auth]

    Auth -->|2. 驗證通過| CF

    CF -->|3. 操作資料庫| DB[(Firestore Database<br/>tasks/userId/userTasks)]

    DB -->|4. 回傳結果| CF

    CF -->|success/error| ChatVM

    ChatVM -->|更新快取| Sync[forceReloadTasks]

    ChatVM -->|回傳給 GPT| Result[繼續對話]

    style GPT fill:#e3f2fd
    style ChatVM fill:#f3e5f5
    style CF fill:#fff3e0
    style Auth fill:#ffebee
    style DB fill:#e8f5e9
    style Result fill:#e1f5e1
```

**說明**：
1. **GPT** 分析使用者需求後，決定呼叫操作類函數（saveTask/deleteTask/updateTask）
2. **ChatViewModel** 接收到函數呼叫請求，解析參數並準備資料
3. **Firebase Cloud Functions** 接收請求，先透過 **Firebase Auth** 驗證使用者身份
4. 驗證通過後，**Cloud Functions** 對 **Firestore Database** 進行寫入/更新/刪除操作
5. **Firestore** 完成操作後回傳結果給 **Cloud Functions**
6. **Cloud Functions** 將結果回傳給 **ChatViewModel**
7. **ChatViewModel** 觸發本地快取同步（forceReloadTasks），確保 UI 顯示最新資料
8. 函數執行結果被加入對話歷史，發送回 **GPT** 繼續對話

---

## 一、完整流程圖（Flowchart）

### 1.1 整體架構流程

```mermaid
flowchart TD
    Start([使用者在聊天室輸入]) --> Stage1[階段1: AI分析與決策]

    Stage1 --> SendToOpenAI[發送到 OpenAI API]
    SendToOpenAI --> ChatProxy1[Firebase Cloud Functions<br/>chatProxy]
    ChatProxy1 --> OpenAI1[OpenAI API Server<br/>GPT-4.1]
    OpenAI1 --> Decision{AI 決定行動}

    Decision -->|文字回應| DirectResponse[直接顯示給使用者]
    Decision -->|呼叫函數| FunctionType{函數類型判斷}

    FunctionType -->|查詢類<br/>getTime/getTask| LocalExec[本地執行]
    FunctionType -->|操作類<br/>saveTask/deleteTask/updateTask| FirebaseFlow[階段2: Firebase 操作流程]

    LocalExec --> AddToHistory1[加入對話歷史]
    FirebaseFlow --> AddToHistory1

    AddToHistory1 --> Stage3[階段3: 繼續對話]
    Stage3 --> SendBackToOpenAI[將函數結果發送回 OpenAI]
    SendBackToOpenAI --> ChatProxy2[Firebase Cloud Functions<br/>chatProxy]
    ChatProxy2 --> OpenAI2[OpenAI API Server]
    OpenAI2 --> FinalResponse[AI 生成最終回應]
    FinalResponse --> UpdateUI[更新 UI 顯示]
    UpdateUI --> End([對話完成])

    DirectResponse --> End

    style Start fill:#e1f5e1
    style End fill:#ffe1e1
    style Stage1 fill:#e3f2fd
    style FirebaseFlow fill:#fff3e0
    style Stage3 fill:#f3e5f5
    style Decision fill:#fff9c4
    style FunctionType fill:#fff9c4
```

### 1.2 Firebase 操作詳細流程

```mermaid
flowchart TD
    Start([AI 呼叫操作函數]) --> Parse[解析函數參數<br/>ChatViewModel]

    Parse --> Validate[驗證資料格式<br/>日期/必填欄位]
    Validate --> Convert[資料轉換<br/>Timestamp → ISO 8601]
    Convert --> PrepareRequest[準備 HTTPS POST 請求]

    PrepareRequest --> CallCF[呼叫 Firebase<br/>Cloud Functions]

    CallCF --> CF{Cloud Functions<br/>處理}

    CF -->|createTask| CreateFlow[新增任務流程]
    CF -->|updateTask| UpdateFlow[更新任務流程]
    CF -->|deleteTask| DeleteFlow[刪除任務流程]

    CreateFlow --> Auth1[步驟1: 驗證使用者身份<br/>Firebase Auth]
    UpdateFlow --> Auth2[步驟1: 驗證使用者身份<br/>Firebase Auth]
    DeleteFlow --> Auth3[步驟1: 驗證使用者身份<br/>Firebase Auth]

    Auth1 --> AuthCheck1{驗證通過?}
    Auth2 --> AuthCheck2{驗證通過?}
    Auth3 --> AuthCheck3{驗證通過?}

    AuthCheck1 -->|是| Firestore1[(步驟2: 操作資料庫<br/>Firestore<br/>tasks/userId/userTasks)]
    AuthCheck2 -->|是| Firestore2[(步驟2: 操作資料庫<br/>Firestore<br/>tasks/userId/userTasks)]
    AuthCheck3 -->|是| Firestore3[(步驟2: 操作資料庫<br/>Firestore<br/>tasks/userId/userTasks)]

    AuthCheck1 -->|否| AuthFail1[回傳驗證失敗]
    AuthCheck2 -->|否| AuthFail2[回傳驗證失敗]
    AuthCheck3 -->|否| AuthFail3[回傳驗證失敗]

    Firestore1 -->|寫入| Success1[步驟3: 回傳成功結果]
    Firestore2 -->|更新| Success2[步驟3: 回傳成功結果]
    Firestore3 -->|刪除| Success3[步驟3: 回傳成功結果]

    Success1 --> BackToApp[回傳到 iOS App]
    Success2 --> BackToApp
    Success3 --> BackToApp

    AuthFail1 --> BackToApp
    AuthFail2 --> BackToApp
    AuthFail3 --> BackToApp

    BackToApp --> Sync[同步本地快取<br/>forceReloadTasks]
    Sync --> Return[回傳結果給 AI]
    Return --> End([函數執行完成])

    style Start fill:#e1f5e1
    style End fill:#ffe1e1
    style CF fill:#fff9c4
    style Firestore1 fill:#e8f5e9
    style Firestore2 fill:#e8f5e9
    style Firestore3 fill:#e8f5e9
    style Sync fill:#fff3e0
    style Auth1 fill:#ffebee
    style Auth2 fill:#ffebee
    style Auth3 fill:#ffebee
    style AuthCheck1 fill:#fff9c4
    style AuthCheck2 fill:#fff9c4
    style AuthCheck3 fill:#fff9c4
```

---

## 二、序列圖（Sequence Diagram）

### 2.1 完整對話與 Firebase 互動序列

```mermaid
sequenceDiagram
    actor User as 使用者
    participant UI as iOS App<br/>(ChatViewModel)
    participant Proxy as Firebase Cloud<br/>Functions (chatProxy)
    participant OpenAI as OpenAI API<br/>(GPT-4.1)
    participant CF as Firebase Cloud<br/>Functions (createTask)
    participant DB as Firestore<br/>Database

    Note over User,DB: 階段 1: 使用者輸入與 AI 分析
    User->>UI: 輸入訊息<br/>"幫我安排明天讀書"
    UI->>Proxy: HTTPS POST<br/>JSON Request Body
    Proxy->>OpenAI: 轉發請求 + API Key
    OpenAI->>OpenAI: AI 理解需求
    OpenAI-->>Proxy: SSE 串流回應<br/>"好的，請問幾點方便？"
    Proxy-->>UI: 轉發回應
    UI-->>User: 顯示 AI 回應

    User->>UI: 回答 "早上9點"
    UI->>Proxy: HTTPS POST
    Proxy->>OpenAI: 轉發請求

    Note over OpenAI: AI 決定呼叫函數<br/>getTime + getTask
    OpenAI-->>Proxy: SSE: tool_calls
    Proxy-->>UI: 轉發 tool_calls

    Note over User,DB: 階段 2: 執行函數（本地 + Firebase）
    UI->>UI: 執行 getTime()<br/>本地執行
    UI->>UI: 執行 getTask()<br/>本地執行

    UI->>Proxy: 將函數結果發送回 OpenAI
    Proxy->>OpenAI: 包含函數結果的請求

    Note over OpenAI: AI 分析資料<br/>決定呼叫 saveTask
    OpenAI-->>Proxy: SSE: tool_calls (saveTask)
    Proxy-->>UI: 轉發 tool_calls

    Note over UI,DB: 執行 saveTask 操作
    UI->>UI: 解析參數<br/>轉換資料格式
    UI->>CF: HTTPS POST<br/>createTask({task data})
    CF->>CF: 驗證使用者身份
    CF->>CF: 驗證資料格式
    CF->>DB: 寫入任務<br/>tasks/{userId}/userTasks/{taskId}
    DB-->>CF: 寫入成功
    CF-->>UI: { success: true }

    UI->>UI: 同步本地快取<br/>forceReloadTasks()
    UI->>DB: 重新載入所有任務
    DB-->>UI: 返回最新任務列表

    Note over User,DB: 階段 3: AI 生成最終回應
    UI->>Proxy: 將執行結果發送回 OpenAI<br/>"已成功新增 1 個任務"
    Proxy->>OpenAI: 轉發請求
    OpenAI->>OpenAI: 根據結果生成回應
    OpenAI-->>Proxy: SSE 串流<br/>"已為您安排明天早上9-10點..."
    Proxy-->>UI: 轉發回應
    UI-->>User: 顯示最終回應

    Note over User,DB: ✅ 對話完成，任務已同步到 Firestore
```

### 2.2 批量操作序列（例：批量新增任務）

```mermaid
sequenceDiagram
    actor User as 使用者
    participant UI as iOS App
    participant OpenAI as OpenAI API
    participant CF as Cloud Functions<br/>(createTask)
    participant DB as Firestore

    User->>UI: "幫我這週每天下午2-4點讀書"
    UI->>OpenAI: 發送請求
    OpenAI->>OpenAI: 理解需求<br/>需要新增 7 個任務
    OpenAI-->>UI: 呼叫 saveTask<br/>tasks: [7個任務]

    Note over UI,DB: 並行處理多個任務

    par 任務 1
        UI->>CF: createTask(週一)
        CF->>DB: 寫入
        DB-->>CF: ✓
        CF-->>UI: success
    and 任務 2
        UI->>CF: createTask(週二)
        CF->>DB: 寫入
        DB-->>CF: ✓
        CF-->>UI: success
    and 任務 3
        UI->>CF: createTask(週三)
        CF->>DB: 寫入
        DB-->>CF: ✓
        CF-->>UI: success
    and 任務 4-7
        UI->>CF: createTask(週四~日)
        CF->>DB: 批量寫入
        DB-->>CF: ✓
        CF-->>UI: success
    end

    UI->>UI: 累計結果<br/>successCount = 7
    UI->>DB: forceReloadTasks()
    DB-->>UI: 返回最新任務列表

    UI->>OpenAI: 回傳結果<br/>"已成功新增 7 個任務"
    OpenAI-->>UI: 生成回應<br/>"已為您安排本週每天..."
    UI-->>User: 顯示回應
```

---

## 三、狀態圖（State Diagram）

### 3.1 聊天室任務操作狀態流轉

```mermaid
stateDiagram-v2
    [*] --> Idle: 使用者輸入訊息

    Idle --> WaitingAI: 發送到 OpenAI

    WaitingAI --> ReceivingResponse: SSE 串流開始
    ReceivingResponse --> TextResponse: AI 回應文字
    ReceivingResponse --> FunctionCall: AI 呼叫函數

    TextResponse --> Idle: 顯示給使用者

    FunctionCall --> LocalExecution: 查詢類函數<br/>(getTime/getTask)
    FunctionCall --> FirebaseOperation: 操作類函數<br/>(saveTask/deleteTask/updateTask)

    LocalExecution --> FunctionComplete

    FirebaseOperation --> ValidatingData: 驗證資料
    ValidatingData --> CallingCloudFunctions: 呼叫 Cloud Functions
    CallingCloudFunctions --> WritingFirestore: 寫入 Firestore
    WritingFirestore --> SyncingLocal: 同步本地快取
    SyncingLocal --> FunctionComplete

    FunctionComplete --> WaitingAI: 將結果發送回 OpenAI

    WaitingAI --> [*]: 收到最終回應

    note right of FirebaseOperation
        包含完整的
        Firebase 互動流程
    end note

    note right of SyncingLocal
        forceReloadTasks()
        確保資料一致性
    end note
```

### 3.2 Firebase 操作詳細狀態

```mermaid
stateDiagram-v2
    [*] --> ParseArguments: 函數被呼叫

    ParseArguments --> ValidateFormat: 解析成功
    ParseArguments --> ErrorState: 解析失敗

    ValidateFormat --> ConvertData: 驗證通過
    ValidateFormat --> ErrorState: 驗證失敗

    ConvertData --> PrepareRequest: 轉換完成

    PrepareRequest --> CallCloudFunction: 準備 HTTPS 請求

    CallCloudFunction --> Authenticating: 發送請求

    Authenticating --> ProcessingData: 驗證成功
    Authenticating --> ErrorState: 驗證失敗

    ProcessingData --> WritingDB: Cloud Function 處理

    state WritingDB {
        [*] --> CheckOperation
        CheckOperation --> Create: saveTask
        CheckOperation --> UpdateOp: updateTask
        CheckOperation --> DeleteOp: deleteTask

        Create --> WriteFirestore
        UpdateOp --> WriteFirestore
        DeleteOp --> WriteFirestore

        WriteFirestore --> [*]: 操作完成
    }

    WritingDB --> ReturnSuccess: 寫入成功
    WritingDB --> ErrorState: 寫入失敗

    ReturnSuccess --> SyncCache: 回傳結果到 App

    SyncCache --> ReloadTasks: 呼叫 forceReloadTasks
    ReloadTasks --> FetchFromFirestore: 從 Firestore 重新載入
    FetchFromFirestore --> UpdateLocalCache: 更新本地快取
    UpdateLocalCache --> Complete: 同步完成

    Complete --> [*]: 回傳給 AI
    ErrorState --> [*]: 回傳錯誤訊息

    note right of SyncCache
        確保 UI 即時反映
        Firestore 的最新狀態
    end note
```

---

## 四、組件互動圖（Component Diagram）

### 4.1 系統架構與資料流

```mermaid
graph TB
    subgraph Client["iOS App (Client)"]
        User[使用者介面]
        ChatVM[ChatViewModel]
        TodoVM[TodoViewModel]
        LocalCache[本地快取]
    end

    subgraph Firebase["Firebase Backend"]
        ChatProxy[Cloud Function<br/>chatProxy]
        CreateTask[Cloud Function<br/>createTask]
        UpdateTask[Cloud Function<br/>updateTask]
        DeleteTask[Cloud Function<br/>deleteTask]
        Firestore[(Firestore<br/>Database)]
        Auth[Firebase Auth]
    end

    subgraph External["外部服務"]
        OpenAI[OpenAI API<br/>GPT-4.1]
    end

    User -->|輸入訊息| ChatVM
    ChatVM -->|HTTPS POST| ChatProxy
    ChatProxy -->|轉發請求<br/>+ API Key| OpenAI
    OpenAI -->|SSE 串流| ChatProxy
    ChatProxy -->|轉發回應| ChatVM

    ChatVM -->|saveTask| CreateTask
    ChatVM -->|updateTask| UpdateTask
    ChatVM -->|deleteTask| DeleteTask

    CreateTask -->|1. 驗證身份| Auth
    UpdateTask -->|1. 驗證身份| Auth
    DeleteTask -->|1. 驗證身份| Auth

    Auth -->|2. 驗證通過| CreateTask
    Auth -->|2. 驗證通過| UpdateTask
    Auth -->|2. 驗證通過| DeleteTask

    CreateTask -->|3. 寫入| Firestore
    UpdateTask -->|3. 更新| Firestore
    DeleteTask -->|3. 刪除| Firestore

    Firestore -->|4. 回傳結果| CreateTask
    Firestore -->|4. 回傳結果| UpdateTask
    Firestore -->|4. 回傳結果| DeleteTask

    CreateTask -->|success| ChatVM
    UpdateTask -->|success| ChatVM
    DeleteTask -->|success| ChatVM

    ChatVM -->|forceReloadTasks| TodoVM
    TodoVM -->|查詢| Firestore
    Firestore -->|任務列表| TodoVM
    TodoVM -->|更新| LocalCache
    LocalCache -->|顯示| User

    style User fill:#e1f5e1
    style Firestore fill:#fff3e0
    style OpenAI fill:#e3f2fd
    style ChatProxy fill:#f3e5f5
    style Auth fill:#ffebee
```

**重要安全流程說明**:
- Cloud Functions（CreateTask、UpdateTask、DeleteTask）在執行任何資料庫操作之前，**必須先通過 Firebase Auth 驗證**
- 驗證流程為序列化執行：
  1. **步驟 1**: Cloud Function 收到請求後，先向 Firebase Auth 驗證使用者身份
  2. **步驟 2**: 只有在驗證通過後，才會繼續執行
  3. **步驟 3**: 通過驗證後，才對 Firestore 進行寫入/更新/刪除操作
  4. **步驟 4**: Firestore 完成操作後回傳結果
- 此設計確保所有資料庫操作都經過身份驗證，防止未授權存取

---

## 五、錯誤處理流程圖

### 5.1 多層次錯誤處理

```mermaid
flowchart TD
    Start([執行函數]) --> TryCatch{Try-Catch}

    TryCatch -->|成功| ParseArgs[解析參數]
    TryCatch -->|失敗| Error1[錯誤層次 1<br/>參數解析錯誤]

    ParseArgs --> ValidateDate{驗證日期格式}
    ValidateDate -->|成功| ConvertData[轉換資料]
    ValidateDate -->|失敗| Error2[錯誤層次 2<br/>日期格式無效<br/>failureCount++]

    ConvertData --> CallCF[呼叫 Cloud Functions]
    CallCF --> Retry{重試機制}

    Retry -->|第1次失敗| Wait1[等待 1.5 秒]
    Retry -->|第2次失敗| Wait2[等待 3.0 秒]
    Retry -->|第3次失敗| Error3[錯誤層次 3<br/>Cloud Functions 失敗<br/>failureCount++]

    Wait1 --> CallCF
    Wait2 --> CallCF

    Retry -->|成功| CheckResponse{檢查回應}
    CheckResponse -->|success: true| Success[successCount++]
    CheckResponse -->|success: false| Error4[錯誤層次 4<br/>Firestore 寫入失敗<br/>failureCount++]

    Success --> Sync[同步本地快取]
    Error2 --> Continue{還有其他任務?}
    Error3 --> Continue
    Error4 --> Continue

    Continue -->|是| ParseArgs
    Continue -->|否| Report[回報結果]

    Sync --> Report
    Error1 --> Report

    Report --> End([回傳:<br/>已成功 X 個任務<br/>Y 個任務失敗])

    style Start fill:#e1f5e1
    style End fill:#ffe1e1
    style Error1 fill:#ffcdd2
    style Error2 fill:#ffcdd2
    style Error3 fill:#ffcdd2
    style Error4 fill:#ffcdd2
    style Success fill:#c8e6c9
    style Retry fill:#fff9c4
```

---

## 六、Tool Choice 策略流程圖

### 6.1 智慧 Tool Choice 決策

```mermaid
flowchart TD
    Start([使用者發送訊息]) --> Reset[sendToGPTCount = 0]
    Reset --> Loop{發送請求循環}

    Loop --> CheckCount{sendToGPTCount?}

    CheckCount -->|= 0| None[tool_choice = none]
    CheckCount -->|= 1| Required[tool_choice = required]
    CheckCount -->|> 1| Dynamic{動態策略}

    Dynamic --> CheckLast{lastToolChoice?}
    CheckLast -->|required| SetAuto[tool_choice = auto]
    CheckLast -->|auto| CheckType{lastReplyType?}

    CheckType -->|text| SetRequired[tool_choice = required]
    CheckType -->|function| SetAuto2[tool_choice = auto]

    None --> SendRequest[發送到 OpenAI]
    Required --> SendRequest
    SetAuto --> SendRequest
    SetRequired --> SendRequest
    SetAuto2 --> SendRequest

    SendRequest --> ReceiveResponse{收到回應}

    ReceiveResponse -->|文字| SaveReply1[lastReplyType = text<br/>lastToolChoice = 當前值]
    ReceiveResponse -->|函數呼叫| SaveReply2[lastReplyType = function<br/>lastToolChoice = 當前值]

    SaveReply1 --> CheckEnd{結束對話?}
    SaveReply2 --> ExecuteFunction[執行函數]

    ExecuteFunction --> CheckEndConv{endConversation?}
    CheckEndConv -->|是| Exit([對話結束])
    CheckEndConv -->|否| IncCount[sendToGPTCount++]

    IncCount --> Loop

    CheckEnd -->|是| Exit
    CheckEnd -->|否| IncCount2[sendToGPTCount++]
    IncCount2 --> Loop

    style Start fill:#e1f5e1
    style Exit fill:#ffe1e1
    style None fill:#e3f2fd
    style Required fill:#fff3e0
    style SetAuto fill:#f3e5f5
    style SetRequired fill:#fff3e0
    style SetAuto2 fill:#f3e5f5
    style CheckCount fill:#fff9c4
    style Dynamic fill:#fff9c4
```

---

## 七、資料轉換流程

### 7.1 Timestamp 與 ISO 8601 轉換

```mermaid
flowchart LR
    subgraph iOS["iOS App"]
        TodoTask[TodoTask Object]
        Firestore1[toFirestore Method]
        Convert[convertTimestampsToStrings]
        JSON1[JSON for Cloud Functions]
    end

    subgraph CloudFunctions["Cloud Functions"]
        Receive[接收 JSON]
        Parse[解析參數]
        ConvertBack[ISO 8601 → Timestamp]
        FirestoreWrite[寫入 Firestore]
    end

    subgraph Database["Firestore"]
        Store[(儲存為 Timestamp 型別)]
    end

    TodoTask -->|包含 Date 物件| Firestore1
    Firestore1 -->|轉換為 Timestamp| Convert
    Convert -->|Timestamp → ISO 8601 String| JSON1

    JSON1 -->|HTTPS POST| Receive
    Receive --> Parse
    Parse --> ConvertBack
    ConvertBack -->|String → Timestamp| FirestoreWrite
    FirestoreWrite --> Store

    style TodoTask fill:#e3f2fd
    style JSON1 fill:#fff3e0
    style Store fill:#c8e6c9
    style Convert fill:#fff9c4
    style ConvertBack fill:#fff9c4
```

**轉換範例**:
```
iOS App (Date):
startDate = 2025-01-16 09:00:00

↓ toFirestore

Timestamp:
Timestamp(seconds: 1737014400, nanoseconds: 0)

↓ convertTimestampsToStrings

ISO 8601 String:
"2025-01-16T09:00:00+08:00"

↓ Cloud Functions

Timestamp:
Timestamp(seconds: 1737014400, nanoseconds: 0)

↓ Firestore

儲存為 Timestamp 型別
```

---

## 八、使用說明

### 如何在 Markdown 中使用這些圖表

1. **複製對應的 Mermaid 程式碼區塊**
2. **貼到支援 Mermaid 的 Markdown 編輯器中**
   - GitHub README.md
   - GitLab
   - Notion
   - Obsidian
   - Typora
   - VS Code (安裝 Mermaid 擴充套件)

3. **線上編輯器**
   - https://mermaid.live/
   - 可以即時預覽和調整

### 匯出為圖片

在 Mermaid Live Editor 中：
1. 編輯圖表
2. 點擊「Actions」
3. 選擇「PNG」或「SVG」匯出

---

## 九、圖表對照表

| 圖表類型 | 章節 | 用途 | 適合用於 |
|---------|------|------|---------|
| **Flowchart** | 一、1.1 | 整體架構流程 | 報告概覽章節 |
| **Flowchart** | 一、1.2 | Firebase 操作詳細流程 | 技術實作章節 |
| **Sequence Diagram** | 二、2.1 | 完整對話序列 | 系統互動說明 |
| **Sequence Diagram** | 二、2.2 | 批量操作序列 | 效能優化說明 |
| **State Diagram** | 三、3.1 | 任務操作狀態 | 狀態管理說明 |
| **State Diagram** | 三、3.2 | Firebase 操作狀態 | 詳細狀態流轉 |
| **Component Diagram** | 四、4.1 | 系統架構 | 架構設計章節 |
| **Flowchart** | 五、5.1 | 錯誤處理流程 | 可靠性設計 |
| **Flowchart** | 六、6.1 | Tool Choice 策略 | AI 智慧策略 |
| **Flowchart** | 七、7.1 | 資料轉換流程 | 資料處理說明 |

---

## 十、建議使用方式

### 報告章節建議配置

**4.X 聊天室功能架構**
- 使用：一、1.1 整體架構流程 (Flowchart)
- 說明整體運作流程

**4.X.1 AI 對話流程**
- 使用：二、2.1 完整對話序列 (Sequence Diagram)
- 展示各組件互動時序

**4.X.2 Firebase 操作機制**
- 使用：一、1.2 Firebase 操作詳細流程 (Flowchart)
- 說明資料庫操作流程

**4.X.3 系統架構設計**
- 使用：四、4.1 系統架構 (Component Diagram)
- 展示各組件關係

**4.X.4 智慧策略設計**
- 使用：六、6.1 Tool Choice 策略 (Flowchart)
- 說明 AI 決策機制

**4.X.5 錯誤處理機制**
- 使用：五、5.1 錯誤處理流程 (Flowchart)
- 說明多層次錯誤處理

**4.X.6 批量操作優化**
- 使用：二、2.2 批量操作序列 (Sequence Diagram)
- 展示並行處理優勢

---

這些 Mermaid 圖表提供了清晰的視覺化呈現，讓讀者能快速理解複雜的系統互動流程。所有圖表都可以直接用於專題報告、文件或簡報中。
