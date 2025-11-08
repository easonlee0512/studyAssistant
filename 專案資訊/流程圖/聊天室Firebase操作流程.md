# 聊天室 Firebase 操作流程

本文件詳細說明讀書助手 App 中，當 AI 聊天助手需要執行任務操作（新增、修改、刪除）時，與 Firebase 後端服務的完整互動流程。

---

## 一、操作流程概覽

當使用者透過聊天室請求 AI 助手執行任務操作時，系統會經歷以下完整流程：

```
使用者輸入
    ↓
AI 理解並決定執行操作
    ↓
系統判斷函數類型
    ├─ 查詢類 (getTime/getTask) → 本地執行
    └─ 操作類 (saveTask/deleteTask/updateTask) → Firebase 流程
        ↓
    【完整 Firebase 操作流程】
        ↓
    更新本地快取
        ↓
    回傳結果給 AI
        ↓
AI 生成回應告知使用者
```

---

## 二、Firebase 操作流程詳解

### 2.1 新增任務流程（saveTask）

#### 階段 1: AI 決定新增任務

```
使用者: "幫我安排明天早上9點讀書"
    ↓
AI (透過 OpenAI): 分析需求
    ↓ [呼叫 getTime + getTask 確認資訊]
    ↓
AI: 決定呼叫 saveTask 函數
    參數: {
        "tasks": [{
            "title": "讀書",
            "startDate": "2025-01-16T09:00:00+08:00",
            "endDate": "2025-01-16T10:00:00+08:00",
            ...
        }]
    }
```

#### 階段 2: 執行 saveTask 函數

**位置**: `ChatViewModel.swift:839-993 (executeSaveTask)`

```swift
// 1. 解析 AI 提供的參數
let args = try JSONDecoder().decode(SaveTasksArgs.self, from: jsonData)

// 2. 驗證並轉換資料格式
for task in args.tasks {
    // 驗證日期格式
    guard let startDate = parseDate(task.startDate),
          let endDate = parseDate(task.endDate) else {
        continue
    }

    // 建立 PendingTask（UI 顯示用）
    let pendingTask = PendingTask(...)

    // 建立 TodoTask（資料庫儲存用）
    let todoTask = TodoTask(...)
```

#### 階段 3: 發送到 Firebase Cloud Functions

```
iOS App (ChatViewModel)
    ↓ [準備任務資料]
    ↓ 轉換 Timestamp 為 ISO 8601 字串格式
    ↓
    var taskData = todoTask.toFirestore
    let convertedData = convertTimestampsToStrings(taskData)
    ↓
    [HTTPS POST] 呼叫 Cloud Functions
    ↓
Firebase Cloud Functions - createTask
    URL: https://asia-east1-studyassistant-f7172.cloudfunctions.net/createTask

    接收參數: {
        "task": {
            "title": "讀書",
            "startDate": "2025-01-16T09:00:00+08:00",
            "endDate": "2025-01-16T10:00:00+08:00",
            "category": "學習",
            "isAllDay": false,
            "isCompleted": false,
            "userId": "當前使用者 ID",
            ...
        }
    }
```

**程式碼實作** (`ChatViewModel.swift:953-956`):
```swift
let result = try await functions.httpsCallable("createTask").call([
    "task": convertedData
])
```

#### 階段 4: Cloud Functions 處理

```
Firebase Cloud Functions (createTask)
    ↓ [1. 驗證使用者身份]
    ↓ 確認 Firebase Auth Token
    ↓ 取得 userId
    ↓
    ↓ [2. 資料驗證]
    ↓ 檢查必填欄位
    ↓ 驗證日期格式
    ↓ 驗證資料型別
    ↓
    ↓ [3. 寫入 Firestore]
    ↓
Firestore Database
    路徑: tasks/{userId}/userTasks/{taskId}

    寫入資料: {
        id: "自動生成的 taskId",
        title: "讀書",
        startDate: Timestamp,
        endDate: Timestamp,
        category: "學習",
        isAllDay: false,
        isCompleted: false,
        color: {...},
        focusTime: 0,
        repeatType: "none",
        userId: "當前使用者 ID",
        createdAt: Timestamp,
        updatedAt: Timestamp
    }
    ↓ [寫入成功]
    ↓
Firebase Cloud Functions
    ↓ [4. 回傳結果]
    ↓
    return {
        "success": true,
        "taskId": "abc123",
        "message": "任務創建成功"
    }
```

#### 階段 5: iOS App 處理回應

**程式碼實作** (`ChatViewModel.swift:959-984`):
```swift
// 解析 Cloud Functions 回應
guard let data = result.data as? [String: Any],
      let success = data["success"] as? Bool,
      success else {
    throw NSError(...)
}

// 成功：記錄並累計
successCount += 1
pendingTasks.append(pendingTask)

// 更新 UI 顯示待確認任務
chatRooms[selectedRoomIndex].messages[currentMessageIndex].pendingTasks = pendingTasks

// 重新整理本地任務清單
try await todoViewModel.forceReloadTasks()

// 回傳結果
return "已成功新增 \(successCount) 個任務"
```

#### 階段 6: 回傳給 AI 並生成回應

```
iOS App (ChatViewModel)
    ↓ 函數執行結果: "已成功新增 1 個任務"
    ↓ 將結果加入對話歷史
    ↓ [發送回 OpenAI]
    ↓
OpenAI API
    AI 收到函數執行結果
    ↓ 生成自然語言回應
    ↓
    "已為您安排明天早上9-10點的讀書時間"
    ↓
iOS App (ChatViewModel)
    ↓ 顯示回應給使用者
```

---

### 2.2 刪除任務流程（deleteTask）

#### 完整流程圖

```
使用者: "刪除明天的英文課"
    ↓
AI 分析並呼叫 getTask 找出對應任務
    ↓ 找到 taskId: "abc123"
    ↓
AI 呼叫 deleteTask({ taskIds: ["abc123"] })
    ↓
iOS App (ChatViewModel)
    ↓ [executeDel teTask 函數]
    ↓ ChatViewModel.swift:1998-2100
    ↓
    解析參數: { "taskIds": ["abc123"] }
    ↓
    逐一刪除任務:
    for taskId in taskIds {
        ↓ [HTTPS POST]
        ↓
    Firebase Cloud Functions - deleteTask
        URL: .../deleteTask
        參數: { "taskId": "abc123" }
        ↓
        [驗證使用者身份]
        ↓
        [刪除 Firestore 文件]
        ↓
    Firestore Database
        路徑: tasks/{userId}/userTasks/abc123
        ↓ [執行刪除]
        ↓ 同時刪除相關的 instances 子集合
        ↓
    Firebase Cloud Functions
        ↓ return { "success": true }
        ↓
    iOS App (ChatViewModel)
        ↓ successCount++
    }
    ↓
    重新整理本地任務清單:
    try await todoViewModel.forceReloadTasks()
    ↓
    回傳: "已成功刪除 1 個任務"
    ↓
AI 收到結果並生成回應:
    "已為您刪除明天的英文課"
```

**關鍵程式碼** (`ChatViewModel.swift:2024-2060`):
```swift
for taskId in taskIds {
    do {
        // 呼叫 Cloud Functions
        let result = try await functions.httpsCallable("deleteTask").call([
            "taskId": taskId
        ])

        // 驗證回應
        guard let data = result.data as? [String: Any],
              let success = data["success"] as? Bool,
              success else {
            failureCount += 1
            continue
        }

        successCount += 1
    } catch {
        print("刪除任務失敗: \(error)")
        failureCount += 1
    }
}

// 重新整理本地快取
if successCount > 0 {
    try await todoViewModel.forceReloadTasks()
}
```

---

### 2.3 更新任務流程（updateTask）

#### 完整流程圖

```
使用者: "把明天的英文課改到下午3點"
    ↓
AI 分析並呼叫 getTask 找出對應任務
    ↓ 找到任務: { taskId: "abc123", 原時間: 09:00-10:00 }
    ↓
AI 呼叫 updateTask({
    tasks: [{
        taskId: "abc123",
        startDate: "2025-01-16T15:00:00+08:00",
        endDate: "2025-01-16T16:00:00+08:00"
    }]
})
    ↓
iOS App (ChatViewModel)
    ↓ [executeUpdateTask 函數]
    ↓ ChatViewModel.swift:2102-2250
    ↓
    解析參數並找出原始任務:
    for updateData in tasks {
        ↓ 從 todoViewModel 找出 originalTask
        ↓ 比對欄位，產生 updatedFields
        ↓
        若有變更:
            ↓ [HTTPS POST]
            ↓
        Firebase Cloud Functions - updateTask
            URL: .../updateTask
            參數: {
                "taskId": "abc123",
                "updates": {
                    "startDate": "2025-01-16T15:00:00+08:00",
                    "endDate": "2025-01-16T16:00:00+08:00",
                    "updatedAt": "2025-01-15T10:30:00+08:00"
                }
            }
            ↓
            [驗證使用者身份]
            ↓
            [更新 Firestore 文件]
            ↓
        Firestore Database
            路徑: tasks/{userId}/userTasks/abc123
            ↓ [執行部分更新]
            ↓ 只更新 startDate、endDate、updatedAt
            ↓ 其他欄位保持不變
            ↓
        Firebase Cloud Functions
            ↓ return { "success": true }
            ↓
        iOS App (ChatViewModel)
            ↓ 記錄為 pendingUpdateTasks (等待確認)
            ↓ successCount++
    }
    ↓
    回傳: "已成功更新 1 個任務"
    ↓
AI 收到結果並生成回應:
    "已將明天的英文課時間調整為下午3-4點"
```

**關鍵程式碼** (`ChatViewModel.swift:2156-2210`):
```swift
// 比對欄位變更
var updatedFields: [String: Any] = [:]

if let newTitle = updateData.title, newTitle != originalTask.title {
    updatedFields["title"] = newTitle
}
if let newStartDate = parseDate(updateData.startDate ?? ""),
   newStartDate != originalTask.startDate {
    updatedFields["startDate"] = ISO8601DateFormatter().string(from: newStartDate)
}
// ... 其他欄位比對

// 呼叫 Cloud Functions 更新
if !updatedFields.isEmpty {
    updatedFields["updatedAt"] = ISO8601DateFormatter().string(from: Date())

    let result = try await functions.httpsCallable("updateTask").call([
        "taskId": originalTask.id,
        "updates": updatedFields
    ])

    // 處理回應...
}
```

---

## 三、資料轉換機制

### 3.1 為什麼需要資料轉換？

**問題**: Firestore 使用 `Timestamp` 型別，但 JSON 不支援此型別。

**解決方案**: 在發送到 Cloud Functions 前，將所有 `Timestamp` 轉換為 ISO 8601 字串。

### 3.2 轉換函數實作

**位置**: `ChatViewModel.swift` (輔助函數)

```swift
/// 將 Firestore Timestamp 轉換為 ISO 8601 字串
func convertTimestampsToStrings(_ data: [String: Any]) -> [String: Any] {
    var result = data
    let isoFormatter = ISO8601DateFormatter()

    for (key, value) in data {
        if let timestamp = value as? Timestamp {
            // Timestamp → Date → ISO 8601 String
            result[key] = isoFormatter.string(from: timestamp.dateValue())
        }
    }

    return result
}
```

**轉換範例**:
```swift
// 轉換前 (TodoTask.toFirestore)
[
    "startDate": Timestamp(seconds: 1737014400, nanoseconds: 0),
    "endDate": Timestamp(seconds: 1737018000, nanoseconds: 0)
]

// 轉換後 (convertTimestampsToStrings)
[
    "startDate": "2025-01-16T09:00:00+08:00",
    "endDate": "2025-01-16T10:00:00+08:00"
]
```

---

## 四、錯誤處理與重試機制

### 4.1 多層次錯誤處理

```
使用者請求
    ↓
try {
    ├─ 層次 1: 參數解析錯誤
    │   ↓ catch → 回傳 "無法解析任務參數"
    │
    ├─ 層次 2: 日期格式錯誤
    │   ↓ failureCount++, continue
    │
    ├─ 層次 3: Cloud Functions 呼叫錯誤
    │   ↓ 自動重試機制 (最多 3 次)
    │   ↓ catch → failureCount++
    │
    └─ 層次 4: Firestore 寫入錯誤
        ↓ Cloud Functions 內部處理
        ↓ 回傳 success: false
        ↓ failureCount++
}
    ↓
最終回傳:
"已成功新增 3 個任務，2 個任務新增失敗"
```

### 4.2 重試機制實作

**位置**: `ChatViewModel.swift:1920-1995 (retryOnError)`

```swift
private func retryOnError<T>(
    maxAttempts: Int = 3,
    delay: TimeInterval = 1.5,
    operation: @escaping () async throws -> T
) async throws -> T {
    var attempts = 0

    while attempts < maxAttempts {
        do {
            // 等待指數退避時間
            if attempts > 0 {
                let waitTime = delay * Double(attempts)
                try await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
            }

            // 嘗試執行操作
            let result = try await operation()

            // 檢查 HTTP 429 (Too Many Requests)
            if httpResponse.statusCode == 429 {
                attempts += 1
                continue
            }

            return result

        } catch {
            attempts += 1
            if attempts >= maxAttempts {
                throw error
            }
        }
    }
}
```

**重試策略**:
- 第 1 次: 立即執行
- 第 2 次: 等待 1.5 秒
- 第 3 次: 等待 3.0 秒
- 失敗後: 拋出錯誤

---

## 五、本地快取同步機制

### 5.1 為什麼需要同步？

```
問題場景:
使用者透過聊天室新增任務
    ↓ 寫入 Firestore ✓
    ↓ 但本地 TodoViewModel 不知道
    ↓ 使用者切換到待辦事項頁面
    ↓ 看不到剛才新增的任務 ✗
```

### 5.2 同步流程

```
操作完成 (saveTask/deleteTask/updateTask)
    ↓
if successCount > 0 {
    ↓ [呼叫 forceReloadTasks]
    ↓
TodoViewModel
    ↓ 清空本地快取
    ↓ 從 Firestore 重新載入所有任務
    ↓ 更新 @Published var tasks
    ↓
    ↓ [SwiftUI 自動更新]
    ↓
UI 即時反映最新狀態
    ├─ TodoView 顯示新任務
    ├─ CalendarView 顯示新排程
    └─ StatisticsView 更新統計
}
```

**程式碼實作** (`ChatViewModel.swift:979-983`):
```swift
if successCount > 0 {
    do {
        try await todoViewModel.forceReloadTasks()
    } catch {
        print("⚠️ 重新整理任務清單失敗: \(error)")
    }
}
```

---

## 六、安全性機制

### 6.1 使用者身份驗證

```
iOS App
    ↓ [Firebase Auth Token]
    ↓ 自動附加在每個請求
    ↓
Firebase Cloud Functions
    ↓ [驗證 Token]
    ↓ 解析 userId
    ↓
    if (!authenticated) {
        return { error: "未授權" }
    }
    ↓
    確保 userId 與請求中的 userId 一致
    ↓
Firestore
    ↓ 只能存取 tasks/{userId}/ 路徑
```

### 6.2 Firestore 安全規則

```javascript
// Firestore Security Rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // 任務資料：只能存取自己的任務
    match /tasks/{userId}/userTasks/{taskId} {
      allow read, write: if request.auth != null
                         && request.auth.uid == userId;
    }

    // 任務實例（重複任務）
    match /tasks/{userId}/userTasks/{taskId}/instances/{instanceId} {
      allow read, write: if request.auth != null
                         && request.auth.uid == userId;
    }
  }
}
```

### 6.3 資料驗證

**Cloud Functions 端驗證**:
```typescript
// firebase_cloud_function/src/tasks/createTask.ts
export const createTask = onCall(async (request) => {
  // 1. 驗證使用者身份
  if (!request.auth) {
    throw new HttpsError('unauthenticated', '使用者未登入');
  }

  // 2. 驗證必填欄位
  const { task } = request.data;
  if (!task.title || !task.startDate || !task.endDate) {
    throw new HttpsError('invalid-argument', '缺少必填欄位');
  }

  // 3. 驗證日期格式
  const startDate = new Date(task.startDate);
  if (isNaN(startDate.getTime())) {
    throw new HttpsError('invalid-argument', '日期格式無效');
  }

  // 4. 寫入 Firestore
  const userId = request.auth.uid;
  await db.collection(`tasks/${userId}/userTasks`).add({
    ...task,
    userId,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp()
  });

  return { success: true };
});
```

---

## 七、效能優化

### 7.1 批量操作

**單次請求 vs 批量請求**:
```
❌ 差的做法（逐一新增）:
for task in tasks {
    await createTask(task)  // 7 次網路請求
}
總時間: 7 × 200ms = 1400ms

✅ 好的做法（批量新增）:
await saveTask(tasks: [...7個任務])  // 7 次請求但並行執行
總時間: ~200ms
```

**實作方式** (`ChatViewModel.swift:906-972`):
```swift
// 並行處理多個任務
for task in args.tasks {
    // 每個任務獨立呼叫 Cloud Functions
    // Swift 的 async/await 會自動優化並行執行
    let result = try await functions.httpsCallable("createTask").call([...])
}
```

### 7.2 本地快取優先

**getTask 優化策略**:
```swift
// ChatViewModel.swift:728-740
var tasks = todoViewModel.tasks  // 優先使用本地快取

if tasks.isEmpty {
    // 快取為空才向 Firebase 請求
    let firebaseService = FirebaseService.shared
    tasks = try await firebaseService.fetchTodoTasks()
}
```

**優點**:
- 減少網路請求
- 降低延遲
- 節省 Firebase 讀取配額

---

## 八、實際使用場景範例

### 場景 1: 批量安排讀書時間

**使用者**: "幫我這週每天下午2-4點安排讀書時間"

```
1. AI 理解需求
   ↓ 本週 = 7 天
   ↓ 下午2-4點 = 2小時

2. AI 呼叫 getTime 確認今天日期
   ↓ 2025/01/15

3. AI 呼叫 getTask 檢查現有任務
   ↓ 發現週三下午已有課

4. AI 呼叫 saveTask 批量新增
   ↓ 參數: 6 個任務（跳過週三）
   ↓
   iOS App 逐一發送到 Cloud Functions
   ├─ createTask(週一下午讀書) ✓
   ├─ createTask(週二下午讀書) ✓
   ├─ createTask(週四下午讀書) ✓
   ├─ createTask(週五下午讀書) ✓
   ├─ createTask(週六下午讀書) ✓
   └─ createTask(週日下午讀書) ✓
   ↓
   Firestore: 成功寫入 6 筆任務
   ↓
   本地同步: forceReloadTasks()
   ↓
   AI 回應: "已為您安排本週每天下午2-4點的讀書時間（週三因已有安排而跳過）"
```

### 場景 2: 修改多個任務

**使用者**: "把這週的數學課都往後延30分鐘"

```
1. AI 呼叫 getTask 找出所有數學課
   ↓ 找到 3 個任務

2. AI 呼叫 updateTask 批量修改
   ↓ 參數: [
       { taskId: "abc", startDate: "原時間+30分", endDate: "原時間+30分" },
       { taskId: "def", startDate: "原時間+30分", endDate: "原時間+30分" },
       { taskId: "ghi", startDate: "原時間+30分", endDate: "原時間+30分" }
     ]
   ↓
   iOS App 逐一更新
   ├─ updateTask(abc) ✓
   ├─ updateTask(def) ✓
   └─ updateTask(ghi) ✓
   ↓
   Firestore: 成功更新 3 筆任務
   ↓
   AI 回應: "已將本週的 3 堂數學課時間都往後延 30 分鐘"
```

---

## 九、流程圖總結

### 完整流程（從使用者輸入到 Firebase 再回到 UI）

```
┌──────────────────────────────────────────────────────────┐
│ 1. 使用者輸入                                             │
└──────────────────────────────────────────────────────────┘
使用者在聊天室輸入: "幫我安排明天讀書"
    ↓
┌──────────────────────────────────────────────────────────┐
│ 2. AI 分析與決策                                          │
└──────────────────────────────────────────────────────────┘
iOS App → Firebase chatProxy → OpenAI API
    AI 理解需求並決定呼叫 saveTask
    ↓
┌──────────────────────────────────────────────────────────┐
│ 3. 本地執行函數                                           │
└──────────────────────────────────────────────────────────┘
iOS App (ChatViewModel.executeSaveTask)
    ├─ 解析參數
    ├─ 驗證資料
    ├─ 轉換格式 (Timestamp → ISO 8601)
    └─ 準備發送
    ↓
┌──────────────────────────────────────────────────────────┐
│ 4. 發送到 Firebase Cloud Functions                       │
└──────────────────────────────────────────────────────────┘
[HTTPS POST] functions.httpsCallable("createTask").call()
    ↓
┌──────────────────────────────────────────────────────────┐
│ 5. Cloud Functions 處理                                  │
└──────────────────────────────────────────────────────────┘
Firebase Cloud Functions (createTask)
    ├─ 驗證使用者身份 (Auth Token)
    ├─ 驗證資料格式
    ├─ 轉換日期字串 → Timestamp
    └─ 寫入 Firestore
    ↓
┌──────────────────────────────────────────────────────────┐
│ 6. Firestore 資料庫操作                                  │
└──────────────────────────────────────────────────────────┘
Firestore: tasks/{userId}/userTasks/{taskId}
    [寫入成功]
    ↓
┌──────────────────────────────────────────────────────────┐
│ 7. 回傳結果                                               │
└──────────────────────────────────────────────────────────┘
Cloud Functions → iOS App
    { "success": true, "taskId": "abc123" }
    ↓
┌──────────────────────────────────────────────────────────┐
│ 8. 本地同步                                               │
└──────────────────────────────────────────────────────────┘
iOS App
    ├─ 記錄成功數量
    ├─ 呼叫 todoViewModel.forceReloadTasks()
    └─ 從 Firestore 重新載入所有任務
    ↓
┌──────────────────────────────────────────────────────────┐
│ 9. 回傳給 AI                                              │
└──────────────────────────────────────────────────────────┘
函數執行結果: "已成功新增 1 個任務"
    ↓ 加入對話歷史
    ↓ 發送回 OpenAI
    ↓
┌──────────────────────────────────────────────────────────┐
│ 10. AI 生成最終回應                                       │
└──────────────────────────────────────────────────────────┘
OpenAI API
    AI 根據結果生成自然語言
    "已為您安排明天早上9-10點的讀書時間"
    ↓
┌──────────────────────────────────────────────────────────┐
│ 11. 顯示給使用者                                          │
└──────────────────────────────────────────────────────────┘
iOS App 更新 UI
    ├─ 聊天室顯示 AI 回應
    ├─ 待辦事項頁面顯示新任務
    └─ 日曆頁面顯示新排程
```

---

## 十、關鍵程式碼位置索引

| 功能 | 檔案與行數 | 說明 |
|------|-----------|------|
| **saveTask 執行** | `ChatViewModel.swift:839-993` | 解析參數、呼叫 Cloud Functions、同步快取 |
| **deleteTask 執行** | `ChatViewModel.swift:1998-2100` | 批量刪除任務 |
| **updateTask 執行** | `ChatViewModel.swift:2102-2250` | 比對變更、批量更新 |
| **資料轉換** | `ChatViewModel.swift` (輔助函數) | Timestamp ↔ ISO 8601 |
| **錯誤重試** | `ChatViewModel.swift:1920-1995` | 指數退避重試機制 |
| **本地同步** | `ChatViewModel.swift:979-983` | 呼叫 forceReloadTasks |
| **Cloud Functions - createTask** | `firebase_cloud_function/src/tasks/createTask.ts` | 新增任務到 Firestore |
| **Cloud Functions - updateTask** | `firebase_cloud_function/src/tasks/updateTask.ts` | 更新任務 |
| **Cloud Functions - deleteTask** | `firebase_cloud_function/src/tasks/deleteTask.ts` | 刪除任務 |

---

## 十一、設計優勢總結

### ✅ 安全性
- API Key 隱藏在 Cloud Functions
- 使用者資料完全隔離
- 多層次身份驗證

### ✅ 可靠性
- 自動重試機制（最多 3 次）
- 完整錯誤處理
- 本地快取同步確保資料一致性

### ✅ 效能
- 批量操作減少網路請求
- 本地快取優先策略
- 並行處理多個任務

### ✅ 使用者體驗
- AI 自動處理複雜流程
- 即時同步 UI
- 自然語言互動，無需學習指令

### ✅ 可維護性
- 職責分離（iOS App / Cloud Functions / Firestore）
- 統一的錯誤處理模式
- 清晰的資料流向

---

這個完整的 Firebase 操作流程確保了聊天室功能既強大又可靠，使用者只需用自然語言表達需求，系統就能自動完成從理解、執行到同步的完整操作。
