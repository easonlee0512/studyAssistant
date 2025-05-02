# 學習助手應用待辦事項清單

# 修復日誌 (2023-05-02)

## 已解決問題
1. **解決 DataServiceProtocol 協議一致性問題**
   - FirebaseService 類實作不符合 DataServiceProtocol 協議的定義
   - 修正了 getTimerRecords 和 getTimerStatistics 方法的參數要求
   - 確保所有方法實現與協議定義一致

2. **修復 UserProfile 初始化問題**
   - 使用 UserProfile.defaultProfile() 建立預設資料
   - 修正了使用 UserProfile 構造函數時傳入不正確的參數數量問題
   - 確保 ID 和 email 正確設置

3. **移除 AppSettings 中不存在的 userId 引用**
   - 更新 fetchAppSettings 和 saveSettings 方法
   - 保證與當前登入用戶 ID 正確關聯

## 預防
- 未來需要確保介面實作與協議定義保持一致
- 加強類型安全和參數檢查
- 在修改模型結構時注意更新所有引用的地方

## 介面修改
- [ ] 完成一個登入介面要實際進行測試
- [ ] 確認所有介面風格、顏色、字體有統一
- [ ] 修改程式讓介面能夠適應所有尺寸
- [ ] 確保所有程式使用swift都是ios 16能使用的
- [ ] 添加動畫過渡效果 

## 資料庫統一
- [ ] 確認figma資料庫完整
- [ ] 檢查所有資料庫是否統一或有缺少

## 架構重構

- [ ] 建立資料模型層 (Model)
  - [ ] 創建 Models 目錄
  - [ ] 將 TodoTask 移至獨立的 Model 檔案
  - [ ] 定義 TimerRecord 模型
  - [ ] 定義 UserSettings 模型
  - [ ] 定義 ChatModels 模型

- [ ] 建立資料存取服務 (DataService)
  - [ ] 創建 Services 目錄
  - [ ] 定義 DataServiceProtocol
  - [ ] 實現 LocalDataService
  - [ ] 準備 HybridDataService 架構

- [ ] 開發 ViewModel 層
  - [ ] 創建 ViewModels 目錄
  - [ ] 實現 TodoViewModel
  - [ ] 實現 TimerViewModel
  - [ ] 實現 ChatViewModel
  - [ ] 實現 SettingsViewModel

- [ ] 重構 View 層
  - [x] 重構 TodoView 使用 ViewModel
  - [ ] 重構 TimerView 使用 ViewModel
  - [ ] 重構 ChatView 使用 ViewModel
  - [ ] 重構 SettingsView 使用 ViewModel

## 功能改進

- [ ] 待辦事項功能
  - [ ] 添加任務分類功能
  - [ ] 實現任務搜尋
  - [ ] 添加重複任務設定
  - [ ] 完善日曆視圖與待辦事項關聯

- [ ] 計時器功能
  - [ ] 實現計時記錄儲存
  - [ ] 添加專注統計圖表

- [ ] 聊天助手功能
  - [ ] 優化 AI 回覆
  - [ ] 添加歷史對話管理
  - [ ] 實現聊天內容持久化

## 錯誤修復

## 優化

