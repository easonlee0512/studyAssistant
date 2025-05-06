//
//  Authentication.swift
//  studyAssistant
//
//  Created by esley W on 2025/4/30.
//google signin 認證

import Foundation
import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import Network

struct Authentication {
    @MainActor
    func googleOauth() async throws {
        print("開始 Google 登入流程")
        
        // 檢查網路連接
        let networkStatus = await checkNetworkConnection()
        if !networkStatus {
            print("標準網路檢測顯示無連接，嘗試替代方法...")
            // 嘗試替代方法檢測網路
            let alternativeNetworkStatus = await tryAlternativeNetwork()
            if !alternativeNetworkStatus {
                print("錯誤：所有網路測試均失敗，確實無網路連接")
                throw AuthenticationError.runtimeError("無法連接到網路，請檢查您的網路連接然後重試")
            } else {
                print("替代網路測試成功，繼續登入流程")
            }
        }
        
        // 檢查 Bundle ID 正確性
        if let bundleID = Bundle.main.bundleIdentifier {
            print("應用程式 Bundle ID: \(bundleID)")
            // 確保 Bundle ID 正確
            if bundleID != "eason.studyAssistant" {
                print("警告：Bundle ID 與預期不符！預期：eason.studyAssistant，實際：\(bundleID)")
                #if DEBUG
                print("注意：在開發環境中，Bundle ID 不匹配可能不會影響功能")
                #else
                print("錯誤：Bundle ID 不匹配可能會導致認證問題")
                throw AuthenticationError.runtimeError("應用程式配置錯誤，請聯繫開發人員")
                #endif
            }
        } else {
            print("警告：無法獲取 Bundle ID")
        }
        
        // google sign in
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            print("錯誤：無法獲取 Firebase clientID")
            throw AuthenticationError.runtimeError("無法獲取認證信息")
        }
        
        print("使用的 clientID: \(clientID)")

        // Create Google Sign In configuration object.
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        // 檢查是否在模擬器上運行
        #if targetEnvironment(simulator)
        print("應用程式在模擬器上運行")
        print("在模擬器上設定 GoogleSignIn，可能存在已知限制")
        #else
        print("應用程式在實際設備上運行")
        #endif

        //get rootView
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            print("錯誤：無法獲取當前 UIWindowScene")
            throw AuthenticationError.runtimeError("無法取得視窗場景")
        }
        
        guard let rootViewController = scene.windows.first?.rootViewController else {
            print("錯誤：無法獲取 rootViewController")
            throw AuthenticationError.runtimeError("無法取得根視圖控制器")
        }

        do {
            print("呼叫 GIDSignIn.sharedInstance.signIn")
            
            // 在模擬器上提供額外信息
            #if targetEnvironment(simulator)
            print("注意：在模擬器上，您可能需要使用 Safari 完成 Google 登入")
            print("如果看到「無法連接到網路」，請嘗試：")
            print("1. 確認模擬器的網路連接")
            print("2. 重啟模擬器")
            print("3. 在實際設備上測試")
            #endif
            
            // 先檢查是否已經有登入用戶
            if let currentUser = GIDSignIn.sharedInstance.currentUser,
               let idToken = currentUser.idToken?.tokenString {
                print("發現已經登入的用戶")
                
                print("準備使用 Firebase Auth 登入")
                let credential = GoogleAuthProvider.credential(
                    withIDToken: idToken, 
                    accessToken: currentUser.accessToken.tokenString
                )
                try await Auth.auth().signIn(with: credential)
                print("Firebase Auth 登入成功")
                return
            }
            
            // 如果無已登入用戶，使用標準登入流程
            let result = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: rootViewController
            )
            print("Google 登入成功")
            
            let user = result.user
            guard let idToken = user.idToken?.tokenString else {
                print("錯誤：無法獲取 idToken")
                throw AuthenticationError.runtimeError("無法獲取 Google 身份驗證令牌")
            }

            print("準備使用 Firebase Auth 登入")
            //Firebase auth
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken, accessToken: user.accessToken.tokenString
            )
            try await Auth.auth().signIn(with: credential)
            print("Firebase Auth 登入成功")
        } catch {
            print("Google 登入過程中出錯: \(error.localizedDescription)")
            
            // 如果用戶取消登入流程，提供友好提示
            if let error = error as? NSError {
                if error.domain == GIDSignInError.errorDomain {
                    if error.code == GIDSignInError.Code.canceled.rawValue {
                        print("用戶取消了登入流程")
                        throw AuthenticationError.runtimeError("您已取消登入流程")
                    } else if error.code == GIDSignInError.Code.EMM.rawValue {
                        throw AuthenticationError.runtimeError("需要企業管理驗證")
                    }
                } else if error.domain == NSURLErrorDomain {
                    switch error.code {
                    case NSURLErrorNotConnectedToInternet:
                        throw AuthenticationError.runtimeError("網路連接問題：您目前未連接到網路")
                    case NSURLErrorTimedOut:
                        throw AuthenticationError.runtimeError("網路連接問題：連接逾時，請檢查您的網路速度")
                    case NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost:
                        throw AuthenticationError.runtimeError("網路連接問題：無法連接到 Google 伺服器")
                    default:
                        throw AuthenticationError.runtimeError("網路連接問題：\(error.localizedDescription)")
                    }
                }
            }
            
            // 一般錯誤處理
            if error.localizedDescription.contains("canceled") || error.localizedDescription.contains("取消") {
                throw AuthenticationError.runtimeError("您已取消登入流程")
            } else {
                throw AuthenticationError.runtimeError("登入失敗：\(error.localizedDescription)")
            }
        }
    }

    func logout() async throws {
        print("開始登出流程")
        
        // 先清理 Google 會話
        GIDSignIn.sharedInstance.signOut()
        
        // 清理網路緩存
        URLCache.shared.removeAllCachedResponses()
        
        // 確保所有憑證緩存被清除
        URLSession.shared.reset { 
            print("URLSession 已重置") 
        }
        
        // 最後才登出 Firebase
        try Auth.auth().signOut()
        
        print("登出成功")
    }
    
    // 檢查網路連接
    private func checkNetworkConnection() async -> Bool {
        print("開始檢查網路連接...")
        let monitor = NWPathMonitor()
        let result = await withCheckedContinuation { continuation in
            monitor.pathUpdateHandler = { path in
                // 顯示詳細的網路狀態
                let status = path.status
                print("網路狀態: \(status == .satisfied ? "已連接" : "未連接")")
                print("網路類型: \(path.isExpensive ? "行動數據" : "WiFi/以太網")")
                
                // 顯示可達性
                let interfaces = path.availableInterfaces
                for interface in interfaces {
                    print("可用網路介面: \(interface.name), 類型: \(String(describing: interface.type))")
                }
                
                // 測試特定網域的可達性
                print("Google 可達: \(path.isConstrained ? "受限" : "正常")")
                
                monitor.cancel()
                
                // 返回網路可用性
                continuation.resume(returning: path.status == .satisfied)
            }
            monitor.start(queue: DispatchQueue.global())
        }
        print("網路檢查結果: \(result ? "已連接" : "未連接")")
        
        return result
    }

    // 嘗試不同的網路連接方法
    @MainActor
    private func tryAlternativeNetwork() async -> Bool {
        // 嘗試使用幾個不同的域名
        let testDomains = [
            "google.com",
            "apple.com",
            "cloudflare.com",
            "github.com"
        ]
        
        // 使用基本的 TCP 連接測試，而不是 HTTP 請求
        for domain in testDomains {
            if await canConnect(to: domain, port: 443) {
                print("\(domain) 連接成功")
                return true
            }
        }
        
        print("所有測試域名均連接失敗")
        return false
    }
    
    // 檢查是否可以連接到特定域名和端口
    private func canConnect(to host: String, port: Int) async -> Bool {
        await withCheckedContinuation { continuation in
            let socket = NWConnection(
                host: NWEndpoint.Host(host),
                port: NWEndpoint.Port(integerLiteral: NWEndpoint.Port.IntegerLiteralType(port)),
                using: .tcp
            )
            
            socket.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    socket.cancel()
                    continuation.resume(returning: true)
                case .failed, .cancelled:
                    socket.cancel()
                    continuation.resume(returning: false)
                default:
                    break
                }
            }
            
            socket.start(queue: .global())
            
            // 添加 3 秒超時
            DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
                socket.cancel()
                continuation.resume(returning: false)
            }
        }
    }
}

enum AuthenticationError: Error {
    case runtimeError(String)
}
