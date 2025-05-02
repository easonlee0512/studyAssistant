//
//  LoginView.swift
//  studyAssistant
//
//  Created by esley W on 2025/4/30.
//

import SwiftUI
import FirebaseAuth

struct LoginView: View {
    @EnvironmentObject var authState: AuthState
    
    var body: some View {
        VStack(spacing: 0) {
            // 上半部：標題區塊
            ZStack {
                Color.hex(hex: "E9CBA5")
                Text("GET\nSTARTED")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(Color.hex(hex: "B88C5A"))
                    .multilineTextAlignment(.center)
            }
            .frame(height: 220)
            
            // 下半部：按鈕區塊
            VStack(spacing: 24) {
                // Google 登入按鈕
                Button(action: {
                    Task {
                        await authState.signInWithGoogle()
                    }
                }) {
                    HStack {
                        Image(systemName: "g.circle.fill")
                            .font(.system(size: 22))
                        
                        Text("Sign in with Google")
                            .font(.system(size: 20, weight: .medium))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.hex(hex: "FEECD8"))
                    .cornerRadius(24)
                    .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
                }
                .disabled(authState.isLoading)
                .padding(.horizontal, 24)
                
                // 登入狀態指示器
                if authState.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.2)
                        .padding(.top, 8)
                }
                
                // 錯誤訊息
                if let errorMessage = authState.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.top, 8)
                        .padding(.horizontal, 24)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.top, 40)
            .background(Color.hex(hex: "F3D4B7").ignoresSafeArea())
            
            Spacer()
        }
        .background(Color.hex(hex: "F3D4B7").ignoresSafeArea())
    }
}
