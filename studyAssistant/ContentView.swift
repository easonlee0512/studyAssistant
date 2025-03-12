//
//  ContentView.swift
//  studyAssistant
//
//  Created by 李翊辰 on 2025/3/5.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {

            // 待辦事項頁面
            TodoView()
                .tabItem {
                    Label("待辦", systemImage: "checklist")
                }
                .tag(0)
            // 計時頁面
            TimerView()
                .tabItem {
                    Label("計時", systemImage: "timer")
                }
                .tag(1)
            
            // 日曆頁面
            CalendarView()
                .tabItem {
                    Label("日曆", systemImage: "calendar")
                }
                .tag(2)
            
            
            
            // 設定頁面
            SettingsView()
                .tabItem {
                    Label("設定", systemImage: "gear")
                }
                .tag(3)
        }
    }
}
#Preview {
    ContentView()
}

