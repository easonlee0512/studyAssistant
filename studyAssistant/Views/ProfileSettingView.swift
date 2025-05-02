import SwiftUI
import Firebase

struct ProfileSettingView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = UserSettingsViewModel()
    @State private var username: String = ""
    @State private var motivationalQuote: String = ""
    @State private var targetDate = Date()
    @State private var selectedStage: String = "大學"
    @State private var isLoading = true
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showingLogoutAlert = false
    
    // 學習階段選項
    let learningStages = ["國中", "高中", "大學", "研究所", "語言學習"]
    
    // Figma 設計中的顏色
    let backgroundColor = Color(red: 243/255, green: 212/255, blue: 183/255) // #F3D4B7
    let cardColor = Color(red: 254/255, green: 236/255, blue: 216/255) // #FEECD8
    let accentColor = Color(red: 226/255, green: 138/255, blue: 95/255) // #E28A5F
    
    var body: some View {
        ZStack {
            // 背景色
            backgroundColor
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // 標題
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "arrow.left")
                            .font(.title2)
                            .foregroundColor(.black)
                    }
                    
                    Spacer()
                    
                    Text("個人資料設定")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    // 空的視圖保持對稱
                    Image(systemName: "arrow.left")
                        .font(.title2)
                        .foregroundColor(.clear)
                }
                .padding()
                
                ScrollView {
                    VStack(spacing: 20) {
                // 個人資料卡片
                        VStack(spacing: 15) {
                            // 用戶名
                            profileField(title: "使用者名稱", text: $username, iconName: "person")
                            
                            // 座右銘
                            profileField(title: "座右銘", text: $motivationalQuote, iconName: "text.quote")
                    
                            // 目標日期
                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundColor(accentColor)
                                    .frame(width: 30)
                    
                        Text("目標日期")
                            .foregroundColor(.black)
                        
                        Spacer()
                        
                                DatePicker("", selection: $targetDate, displayedComponents: .date)
                            .labelsHidden()
                            }
                            .padding()
                            .background(cardColor)
                            .cornerRadius(10)
                            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                    
                            // 學習階段
                    HStack {
                                Image(systemName: "graduationcap")
                                    .foregroundColor(accentColor)
                                    .frame(width: 30)
                                
                                Text("學習階段")
                            .foregroundColor(.black)
                        
                        Spacer()
                        
                                Picker("", selection: $selectedStage) {
                                    ForEach(learningStages, id: \.self) { stage in
                                        Text(stage).tag(stage)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                    }
                            .padding()
                            .background(cardColor)
                            .cornerRadius(10)
                            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                        }
                        .padding(.horizontal)
                    
                        // 保存按鈕
                        Button(action: {
                            Task {
                                await saveProfile()
                            }
                        }) {
                            Text("儲存變更")
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(accentColor)
                                .cornerRadius(10)
                                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                    }
                        .padding(.horizontal)
                        .disabled(isLoading)
                        .opacity(isLoading ? 0.6 : 1)
                        
                        Spacer(minLength: 30)
                    
                    // 登出按鈕
                    Button(action: {
                        showingLogoutAlert = true
                    }) {
                            Text("登出")
                                .fontWeight(.bold)
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.red, lineWidth: 1)
                                )
                                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 50)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            Task {
                await loadProfile()
            }
        }
        .alert("錯誤", isPresented: $showError) {
            Button("確定", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .overlay {
            if isLoading {
                VStack {
                    ProgressView()
                        .scaleEffect(1.5)
                    
                    Text("載入中...")
                        .font(.caption)
                        .padding(.top, 5)
                    }
                .padding()
                .background(Color.white.opacity(0.8))
                .cornerRadius(10)
                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
            }
        }
        .alert("確認登出", isPresented: $showingLogoutAlert) {
            Button("取消", role: .cancel) { }
            Button("登出", role: .destructive) {
                logout()
            }
        } message: {
            Text("確定要登出嗎？")
        }
    }
    
    // 自定義個人資料輸入欄位
    private func profileField(title: String, text: Binding<String>, iconName: String) -> some View {
        HStack {
            Image(systemName: iconName)
                .foregroundColor(accentColor)
                .frame(width: 30)
            
            Text(title)
                .foregroundColor(.black)
            
            Spacer()
            
            TextField("", text: text)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 150)
        }
        .padding()
        .background(cardColor)
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    private func loadProfile() async {
        isLoading = true
        defer { isLoading = false }
        
        let profile = viewModel.userProfile
        
        // 在主線程更新 UI 狀態
        DispatchQueue.main.async {
            username = profile.username
            motivationalQuote = profile.motivationalQuote
            targetDate = profile.targetDate
            selectedStage = profile.learningStage
    }
    }
    
    private func saveProfile() async {
        isLoading = true
        defer { isLoading = false }
        
        await viewModel.updateUserProfile(
            username: username,
            motivationalQuote: motivationalQuote,
            targetDate: targetDate,
            learningStage: selectedStage
        )
        
        if viewModel.errorMessage != nil {
            showError = true
            errorMessage = viewModel.errorMessage ?? "儲存失敗"
        }
    }
    
    private func logout() {
        viewModel.clearAllData()
        dismiss()
    }
}

#Preview {
    NavigationStack {
        ProfileSettingView()
    }
} 
