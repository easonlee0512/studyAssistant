//
//  studyAssistantApp.swift
//  studyAssistant
//
//  Created by 李翊辰 on 2025/3/5.
//

import SwiftUI
import Combine

@main
struct studyAssistantApp: App {
    // 創建 TimerManager 實例作為環境物件
    @StateObject private var timerManager = TimerManager()
    
    // 監聽場景階段變化
    @Environment(\.scenePhase) var scenePhase
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(timerManager) // 注入 TimerManager
        }
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .active:
                // 應用回到前景
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
