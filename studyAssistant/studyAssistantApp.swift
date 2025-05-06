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
    
    // 初始化 Firebase
    init() {
        FirebaseApp.configure()
        
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
                    .task {
                        // 首先嘗試遷移舊數據
                        do {
                            let firebaseService = FirebaseService.shared
                            try await firebaseService.migrateTasksToUserCollection()
                        } catch {
                            print("任務遷移錯誤: \(error)")
                        }
                        
                        // 載入初始資料
                        do {
                            try await todoViewModel.loadTasks()
                        } catch {
                            print("Error loading tasks: \(error)")
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .userDidLogin)) { _ in
                        // 當使用者登入時遷移舊數據並重新載入資料
                        Task {
                            do {
                                let firebaseService = FirebaseService.shared
                                try await firebaseService.migrateTasksToUserCollection()
                                try await todoViewModel.loadTasks()
                                // 同時也重新載入使用者設定
                                await settingsViewModel.loadData()
                                // 發送通知以更新所有依賴使用者設定的視圖
                                NotificationCenter.default.post(name: Notification.Name.userProfileDidChange, object: nil)
                            } catch {
                                print("Error loading tasks after login: \(error)")
                            }
                        }
                    }
                    // 處理從 URL 打開應用的事件
                    .onOpenURL { url in
                        print("應用通過 URL 打開: \(url)")
                        // 讓 Google Sign In 處理 URL
                        GIDSignIn.sharedInstance.handle(url)
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
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .active:
                // 應用回到前景，重新載入資料
                Task {
                    do {
                        try await todoViewModel.loadTasks()
                        // 同時也重新載入使用者設定
                        await settingsViewModel.loadData()
                        // 發送通知以更新所有依賴使用者設定的視圖
                        NotificationCenter.default.post(name: Notification.Name.userProfileDidChange, object: nil)
                    } catch {
                        print("Error reloading tasks: \(error)")
                    }
                }
                timerManager.appWillEnterForeground()
            case .background:
                // 應用進入背景
                timerManager.appDidEnterBackground()
            case .inactive:
                // 應用非活動狀態（例如收到電話）
                break
            @unknown default:
                break
            }
        }
    }
}
