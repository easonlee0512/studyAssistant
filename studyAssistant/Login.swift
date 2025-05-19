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
    @State private var animateGradient = false
    @State private var titleOffset: CGFloat = -100
    @State private var buttonScale: CGFloat = 0.8
    @State private var buttonOpacity: Double = 0
    @State private var showingLogo = false
    @State private var rotationAngle: Double = 0
    
    // 主色調
    private let primaryColor = Color.hex(hex: "B88C5A")
    private let backgroundColor1 = Color.hex(hex: "F3D4B7")
    private let backgroundColor2 = Color.hex(hex: "E9CBA5")
    private let accentColor = Color.hex(hex: "FEECD8")
    
    var body: some View {
        ZStack {
            // 1. 動態背景
            AnimatedGradientBackground()
            
            VStack(spacing: 0) {
                // 2. 標誌動畫
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 120, height: 120)
                    
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 90, height: 90)
                    
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(showingLogo ? rotationAngle : 0))
                        .scaleEffect(showingLogo ? 1 : 0.1)
                        .opacity(showingLogo ? 1 : 0)
                }
                .padding(.top, 60)
                .onAppear {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                        showingLogo = true
                    }
                    
                    // 標誌小幅旋轉
                    withAnimation(Animation.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                        rotationAngle = 10
                    }
                }
                
                // 3. 標題
                Text("學習助手")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.top, 25)
                    .offset(y: titleOffset)
                    .onAppear {
                        withAnimation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.3)) {
                            titleOffset = 0
                        }
                    }
                
                Text("你的個人學習夥伴")
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.top, 5)
                    .offset(y: titleOffset)
                    .onAppear {
                        withAnimation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.4)) {
                            titleOffset = 0
                        }
                    }
                
                Spacer()
                
                // 4. 登入按鈕
                VStack(spacing: 24) {
                    // Google 登入按鈕
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                            buttonScale = 0.95
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                                buttonScale = 1
                            }
                            
                            Task {
                                await authState.signInWithGoogle()
                            }
                        }
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "g.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.hex(hex: "3F85F4"))
                            
                            Text("以 Google 帳號登入")
                                .font(.system(size: 20, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(.black.opacity(0.8))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 30)
                                .fill(Color.white)
                                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 30)
                                .stroke(Color.white.opacity(0.5), lineWidth: 1)
                        )
                    }
                    .disabled(authState.isLoading)
                    .scaleEffect(buttonScale)
                    .opacity(buttonOpacity)
                    .onAppear {
                        withAnimation(.easeOut(duration: 0.8).delay(0.6)) {
                            buttonOpacity = 1
                        }
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.6)) {
                            buttonScale = 1
                        }
                    }
                    
                    // 登入狀態指示器
                    if authState.isLoading {
                        LoadingView()
                            .padding(.top, 8)
                    }
                    
                    // 錯誤訊息
                    if let errorMessage = authState.errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.red.opacity(0.3))
                            )
                            .font(.system(size: 15, weight: .medium))
                            .padding(.top, 8)
                            .padding(.horizontal, 24)
                            .multilineTextAlignment(.center)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 50)
            }
        }
    }
}

// 動畫背景
struct AnimatedGradientBackground: View {
    @State private var animateGradient = false
    
    var body: some View {
        LinearGradient(
            colors: [
                Color.hex(hex: "B88C5A"),
                Color.hex(hex: "E9CBA5"),
                Color.hex(hex: "F3D4B7"),
                Color.hex(hex: "E9CBA5").opacity(0.8)
            ],
            startPoint: animateGradient ? .topLeading : .bottomLeading,
            endPoint: animateGradient ? .bottomTrailing : .topTrailing
        )
        .ignoresSafeArea()
        .overlay(
            ZStack {
                // 添加淡淡的圖案
                ForEach(0..<15) { index in
                    Circle()
                        .fill(Color.white.opacity(Double.random(in: 0.03...0.08)))
                        .frame(width: CGFloat.random(in: 50...200))
                        .position(
                            x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                            y: CGFloat.random(in: 0...UIScreen.main.bounds.height)
                        )
                        .blur(radius: 15)
                }
            }
        )
        .onAppear {
            withAnimation(.linear(duration: 6).repeatForever(autoreverses: true)) {
                animateGradient.toggle()
            }
        }
    }
}

// 自定義載入指示器
struct LoadingView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: 5)
                .opacity(0.3)
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
            
            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(lineWidth: 5)
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
                .onAppear {
                    withAnimation(Animation.linear(duration: 1).repeatForever(autoreverses: false)) {
                        isAnimating = true
                    }
                }
        }
    }
}
