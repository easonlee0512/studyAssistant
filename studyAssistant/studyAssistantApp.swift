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
}

@main
struct studyAssistantApp: App {
    // 初始化 Firebase
    init() {
        FirebaseApp.configure()
    }
    
    // 創建 ViewModel 實例作為環境物件
    @StateObject private var timerManager = TimerManager()
    @StateObject private var todoViewModel = TodoViewModel()
    @StateObject private var authState = AuthState()
    
    // 監聽場景階段變化
    @Environment(\.scenePhase) var scenePhase
    
    var body: some Scene {
        WindowGroup {
            if authState.isLoggedIn {
                ContentView()
                    .environmentObject(timerManager)
                    .environmentObject(todoViewModel)
                    .environmentObject(authState)
                    .task {
                        // 載入初始資料
                        do {
                            try await todoViewModel.loadTasks()
                        } catch {
                            print("Error loading tasks: \(error)")
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .userDidLogin)) { _ in
                        // 當使用者登入時重新載入資料
                        Task {
                            do {
                                try await todoViewModel.loadTasks()
                            } catch {
                                print("Error loading tasks after login: \(error)")
                            }
                        }
                    }
            } else {
                LoginView()
                    .environmentObject(authState)
            }
        }
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .active:
                // 應用回到前景，重新載入資料
                Task {
                    do {
                        try await todoViewModel.loadTasks()
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
