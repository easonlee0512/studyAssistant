import SwiftUI

struct SignInView: View {
    @State private var username = ""
    @State private var password = ""
    @State private var showAlert = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "person.circle")
                    .resizable()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.orange)
                    .padding(.top, 50)
                
                TextField("用戶名", text: $username)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                SecureField("密碼", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                VStack(spacing : 10){
                    Button(action: {
                        // 這裡處理登入邏輯
                        showAlert = true
                    }) {
                        Text("登入")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    Button(action: {
                        // Create account action
                    }) {
                        Text("Create Account")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    
                }.padding(.horizontal)
                
                NavigationLink(destination: CreateAccountView()) {
                    Text("還沒有帳號？立即註冊")
                        .foregroundColor(.orange)
                }
                
                Spacer()
            }
            .navigationTitle("登入")
            .alert("提示", isPresented: $showAlert) {
                Button("確定", role: .cancel) { }
            } message: {
                Text("登入功能待實現")
            }
        }
    }
}

#Preview {
    SignInView()
}
