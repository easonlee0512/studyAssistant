//
//  SignInView.swift
//  studyAssistant
//
//  Created by esley W on 2025/4/21.
//

import SwiftUI
import FirebaseAuth

// 注意：此視圖已被 LoginView 和 AuthState 取代
// 保留此文件是為了向後兼容性，建議在應用中使用 LoginView
struct SignInView: View {
    @EnvironmentObject var authState: AuthState

    var body: some View {
        Group {
            if authState.isLoggedIn {
                ContentView()
            } else {
                LoginView()
            }
        }
    }
}

#Preview {
    SignInView()
        .environmentObject(AuthState())
}
