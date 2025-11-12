//
//  studyAssistantApp.swift
//  studyAssistant
//
//  Created by 李翊辰 on 2025/3/5.
//

import SwiftUI
import Combine
import Firebase
import FirebaseAuth
import GoogleSignIn
import Foundation // 確保可以訪問 NotificationConstants
import UserNotifications

/// 身份驗證狀態管理類別
class AuthState: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var currentUser: User? = nil
    
    private let authentication = Authentication()
    
    init() {
        // 監聽 Firebase 身份驗證狀態變化
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.isLoggedIn = (user != nil)
                self?.currentUser = user
                
                // 發送通知，讓其他元件知道使用者身份已變更
                if let _ = user {
                    NotificationCenter.default.post(name: .userDidLogin, object: nil)
                } else {
                    NotificationCenter.default.post(name: .userDidLogout, object: nil)
                }
            }
        }
        
        // 檢查是否已有登入用戶
        self.currentUser = Auth.auth().currentUser
        self.isLoggedIn = (self.currentUser != nil)
    }
    
    /// 使用 Google 登入
    @MainActor
    func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await authentication.googleOauth()
            // 登入成功後可以在這裡添加額外的邏輯
        } catch AuthenticationError.runtimeError(let message) {
            errorMessage = message
        } catch {
            errorMessage = "登入過程中發生錯誤：\(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    /// 登出功能
    @MainActor
    func signOut() async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await authentication.logout()
        } catch {
            errorMessage = "登出過程中發生錯誤：\(error.localizedDescription)"
        }
        
        isLoading = false
    }
}

// 定義通知名稱
extension Notification.Name {
    static let userDidLogin = Notification.Name("userDidLogin")
    static let userDidLogout = Notification.Name("userDidLogout")
    // userProfileDidChange 已在 NotificationConstants.swift 中定義，透過 Foundation 導入
}

/// 通知代理類別
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    // 前景通知處理
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // 在前景時也顯示通知
        completionHandler([.banner, .sound, .badge])
    }

    // 通知點擊處理
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let taskId = response.notification.request.identifier

        switch response.actionIdentifier {
        case "COMPLETE_ACTION":
            // 標記任務為完成
            print("用戶點擊：標記完成 - taskId: \(taskId)")
            // TODO: 實作標記完成邏輯
            break
        case "SNOOZE_ACTION":
            // 稍後提醒（10分鐘後）
            print("用戶點擊：稍後提醒 - taskId: \(taskId)")
            // TODO: 實作稍後提醒邏輯
            break
        default:
            // 點擊通知，導航到任務詳情
            print("用戶點擊通知 - taskId: \(taskId)")
            // 發送通知以導航到任務詳情
            NotificationCenter.default.post(
                name: NSNotification.Name("NavigateToTask"),
                object: nil,
                userInfo: ["taskId": taskId]
            )
            break
        }

        completionHandler()
    }
}

/// 處理 URL 回調的類別
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        print("收到 URL 回調: \(url)")

        // 檢查是否是 Google Sign In 的回調
        if GIDSignIn.sharedInstance.handle(url) {
            print("已處理 Google Sign In 回調")
            return true
        }

        print("無法處理 URL 回調")
        return false
    }
}

@main
struct studyAssistantApp: App {
    // 註冊 AppDelegate 以處理 URL 回調
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // 通知代理（不需要 @StateObject）
    private let notificationDelegate = NotificationDelegate()

    // 初始化 Firebase
    init() {
        FirebaseApp.configure()

        // 設置通知代理
        UNUserNotificationCenter.current().delegate = notificationDelegate

        // 註冊通知動作類別
        Task { @MainActor in
            NotificationManager.shared.registerNotificationCategories()

            // 請求通知權限
            let granted = await NotificationManager.shared.requestAuthorization()
            print(granted ? "✅ 通知權限已授予" : "❌ 通知權限被拒絕")
        }

        // 設置 TabBar 外觀 - 使用項目的橘色調
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()

        // 設置背景色為淺橘色
        appearance.backgroundColor = UIColor(red: 0.95, green: 0.83, blue: 0.72, alpha: 1.0) // #F3D4B7

        // 設置選中狀態的圖標顏色為深橘色
        let selectedColor = UIColor(red: 0.89, green: 0.47, blue: 0.27, alpha: 1.0) // #E27844
        appearance.stackedLayoutAppearance.selected.iconColor = selectedColor
        appearance.inlineLayoutAppearance.selected.iconColor = selectedColor
        appearance.compactInlineLayoutAppearance.selected.iconColor = selectedColor

        // 設置未選中狀態的圖標顏色
        let normalColor = UIColor.black.withAlphaComponent(0.5)
        appearance.stackedLayoutAppearance.normal.iconColor = normalColor
        appearance.inlineLayoutAppearance.normal.iconColor = normalColor
        appearance.compactInlineLayoutAppearance.normal.iconColor = normalColor

        // 應用外觀設置
        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }

        // 嘗試恢復先前的 Google 登入會話
        GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
            if let error = error {
                print("恢復先前的 Google 登入會話時出錯: \(error.localizedDescription)")
            } else if let user = user {
                print("成功恢復 Google 使用者: \(user.profile?.email ?? "unknown")")
            } else {
                print("無先前的 Google 登入會話")
            }
        }
    }
    
    // 創建 ViewModel 實例作為環境物件
    @StateObject private var timerManager = TimerManager()
    @StateObject private var todoViewModel = TodoViewModel()
    @StateObject private var authState = AuthState()
    @StateObject private var settingsViewModel = UserSettingsViewModel()
    @StateObject private var staticViewModel = StaticViewModel()
    @StateObject private var chatViewModel = ChatViewModel()

    // 取得 CalendarAssistantViewModel 單例
    private var calendarAssistantViewModel: CalendarAssistantViewModel {
        CalendarAssistantViewModel.shared
    }
    
    // 監聽場景階段變化
    @Environment(\.scenePhase) var scenePhase
    
    var body: some Scene {
        WindowGroup {
            if authState.isLoggedIn {
                ContentView()
                    .environmentObject(timerManager)
                    .environmentObject(todoViewModel)
                    .environmentObject(authState)
                    .environmentObject(settingsViewModel)
                    .environmentObject(staticViewModel)
                    .environmentObject(chatViewModel)
                    .environmentObject(calendarAssistantViewModel)
                    .task {
                        // 載入初始資料
                        do {
                            try await todoViewModel.loadTasks()
                            await staticViewModel.fetchStatistics()
                            await settingsViewModel.loadData()

                            // 注入依賴到 CalendarAssistantViewModel
                            await MainActor.run {
                                calendarAssistantViewModel.todoViewModel = todoViewModel
                                calendarAssistantViewModel.staticViewModel = staticViewModel

                                // 同步全域通知設定到 NotificationManager
                                let offset = settingsViewModel.appSettings.notificationOffsetMinutes
                                NotificationManager.shared.globalNotificationOffsetMinutes = offset
                            }

                            // 檢查並執行每日自動更新
                            await calendarAssistantViewModel.performDailyAutoUpdateIfNeeded()
                        } catch {
                            print("Error loading initial data: \(error)")
                        }
                    }
                    .onChange(of: scenePhase) { newPhase in
                        switch newPhase {
                        case .active:
                            // 應用回到前景，重新載入資料
                            Task {
                                do {
                                    // 強制重新載入任務，忽略快取
                                    try await todoViewModel.forceReloadTasks()
                                    // 同時也重新載入使用者設定
                                    await settingsViewModel.loadData()
                                    // 載入統計數據
                                    await staticViewModel.fetchStatistics()
                                    // 發送通知以更新所有依賴使用者設定的視圖
                                    NotificationCenter.default.post(name: .userProfileDidChange, object: nil)

                                    // 檢查並執行每日自動更新
                                    await calendarAssistantViewModel.performDailyAutoUpdateIfNeeded()
                                } catch {
                                    print("Error reloading data in foreground: \(error)")
                                }
                            }
                            timerManager.appWillEnterForeground()
                            
                        case .background:
                            // 應用進入背景，清理資源
                            timerManager.appDidEnterBackground()
                            
                        case .inactive:
                            // 應用非活動狀態（例如收到電話）
                            break
                            
                        @unknown default:
                            break
                        }
                    }
            } else {
                LoginView()
                    .environmentObject(authState)
                    // 處理從 URL 打開應用的事件
                    .onOpenURL { url in
                        print("登入視圖通過 URL 打開: \(url)")
                        // 讓 Google Sign In 處理 URL
                        GIDSignIn.sharedInstance.handle(url)
                    }
            }
        }
    }
}
