import SwiftUI

struct TestSignInView: View {
    var body: some View {
        ZStack {
            // 背景漸層
            LinearGradient(
                gradient: Gradient(colors: [Color.white, Color(UIColor.systemGray6)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // 主要內容
            VStack(spacing: 50) {
                Spacer()
                
                // 頂部標題區域
                VStack(spacing: 10) {
                    // 可以在這裡加入應用程式 Logo
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                        .padding(.bottom, 20)
                    
                    Text("GET")
                        .font(.system(size: 50, weight: .bold, design: .rounded))
                        .foregroundColor(.primary.opacity(0.8))
                    
                    Text("STARTED")
                        .font(.system(size: 50, weight: .bold, design: .rounded))
                        .foregroundColor(.primary.opacity(0.8))
                }
                .shadow(color: .gray.opacity(0.2), radius: 5, x: 0, y: 5)
                
                Spacer()
                
                // 登入按鈕區域
                VStack(spacing: 20) {
                    // Google 登入按鈕
                    Button(action: {
                        // 處理 Google 登入邏輯
                    }) {
                        HStack {
                            Image("google_logo") // 假設有 Google 圖標資源
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                                .padding(.leading, 10)
                            
                            Text("Sign in with Google")
                                .font(.headline)
                                .foregroundColor(.black)
                            
                            Spacer()
                        }
                        .frame(height: 55)
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                        .cornerRadius(28)
                        .shadow(color: .gray.opacity(0.2), radius: 5, x: 0, y: 2)
                        .overlay(
                            RoundedRectangle(cornerRadius: 28)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    }
                    
                    // Apple 登入按鈕
                    Button(action: {
                        // 處理 Apple 登入邏輯
                    }) {
                        HStack {
                            Image(systemName: "apple.logo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 24)
                                .padding(.leading, 10)
                            
                            Text("Sign in with Apple")
                                .font(.headline)
                                .foregroundColor(.black)
                            
                            Spacer()
                        }
                        .frame(height: 55)
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                        .cornerRadius(28)
                        .shadow(color: .gray.opacity(0.2), radius: 5, x: 0, y: 2)
                        .overlay(
                            RoundedRectangle(cornerRadius: 28)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, 40)
                
                Spacer()
                
                // 底部文字
                VStack(spacing: 10) {
                    Text("By continuing, you agree to our")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    HStack(spacing: 5) {
                        Text("Terms of Service")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .underline()
                        
                        Text("and")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text("Privacy Policy")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .underline()
                    }
                }
                .padding(.bottom, 30)
            }
        }
    }
}

struct GoogleButton: View {
    var body: some View {
        HStack {
            Image(systemName: "g.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .foregroundColor(.blue)
            
            Text("Sign in with Google")
                .font(.headline)
                .foregroundColor(.black)
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .cornerRadius(8)
    }
}

struct TestSignInView_Previews: PreviewProvider {
    static var previews: some View {
        TestSignInView()
    }
}
