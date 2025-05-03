import SwiftUI
import Firebase

// 定義通知名稱常數（如果已在其他檔案定義則可移除此處的重複定義）
extension Notification.Name {
    static let userAuthDidChange = Notification.Name("userAuthDidChange")
}

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
    @State private var isRefreshing = false
    @State private var showingSuccessMessage = false
    
    // 學習階段選項
    let learningStages = ["國中", "高中", "大學", "研究所", "語言學習"]
    
    // Figma 設計中的顏色
    let backgroundColor = Color(red: 243/255, green: 212/255, blue: 183/255) // #F3D4B7
    let cardColor = Color(red: 254/255, green: 236/255, blue: 216/255) // #FEECD8
    let accentColor = Color(red: 226/255, green: 138/255, blue: 95/255) // #E28A5F
    
    init() {
        // 使用 _viewModel 初始化 StateObject
        _viewModel = StateObject(wrappedValue: UserSettingsViewModel())
    }
    
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
                    
                    // 重新整理按鈕
                    Button(action: {
                        Task {
                            await refreshData()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.title2)
                            .foregroundColor(.black)
                    }
                    .disabled(isLoading)
                }
                .padding()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // 使用者信息顯示
                        if let email = Auth.auth().currentUser?.email {
                            HStack {
                                Text("目前登入：\(email)")
                                    .font(.footnote)
                                    .foregroundColor(.gray)
                                Spacer()
                            }
                            .padding(.horizontal)
                        }
                        
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
                isLoading = true
                await loadProfile()
            }
            
            // 添加通知監聽
            setupNotificationObserver()
        }
        .onDisappear {
            // 移除通知監聽
            NotificationCenter.default.removeObserver(self)
        }
        .alert("錯誤", isPresented: $showError) {
            Button("確定", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .alert("儲存成功", isPresented: $showingSuccessMessage) {
            Button("確定", role: .cancel) { }
        } message: {
            Text("您的個人資料已成功儲存")
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
    
    // 重新整理資料
    private func refreshData() async {
        isRefreshing = true
        await loadProfile()
        isRefreshing = false
    }
    
    // 載入個人資料
    private func loadProfile() async {
        isLoading = true
        
        print("開始載入使用者資料")
        
        do {
            // 等待 viewModel 從資料庫重新載入資料
            await viewModel.loadData()
            
            // 檢查是否有錯誤訊息
            if let errorMsg = viewModel.errorMessage {
                print("載入資料時發生錯誤：\(errorMsg)")
                DispatchQueue.main.async {
                    self.showError = true
                    self.errorMessage = "載入資料失敗：\(errorMsg)"
                }
                // 即使有錯誤，也嘗試使用現有資料更新 UI
            }
            
            // 取得最新的使用者資料
            let profile = viewModel.userProfile
            print("成功獲取使用者資料：\(profile.username)")
            
            // 在主線程更新 UI 狀態
            DispatchQueue.main.async {
                self.username = profile.username
                self.motivationalQuote = profile.motivationalQuote
                self.targetDate = profile.targetDate
                self.selectedStage = profile.learningStage
                print("UI 已更新")
            }
        } catch {
            print("載入資料時發生例外：\(error)")
            DispatchQueue.main.async {
                self.showError = true
                self.errorMessage = "載入資料失敗：\(error.localizedDescription)"
            }
        }
        
        DispatchQueue.main.async {
            self.isLoading = false
            print("載入完成，關閉載入指示器")
        }
    }
    
    // 儲存個人資料
    private func saveProfile() async {
        isLoading = true
        
        await viewModel.updateUserProfile(
            username: username,
            motivationalQuote: motivationalQuote,
            targetDate: targetDate,
            learningStage: selectedStage
        )
        
        if let errorMsg = viewModel.errorMessage {
            DispatchQueue.main.async {
                self.showError = true
                self.errorMessage = errorMsg
            }
        } else {
            DispatchQueue.main.async {
                self.showingSuccessMessage = true
            }
        }
        
        DispatchQueue.main.async {
            self.isLoading = false
        }
    }
    
    // 登出
    private func logout() {
        do {
            try Auth.auth().signOut()
            viewModel.clearAllData()
            
            // 發送通知通知其他視圖使用者已登出
            NotificationCenter.default.post(name: .userAuthDidChange, object: nil)
            
            dismiss()
        } catch {
            showError = true
            errorMessage = "登出失敗：\(error.localizedDescription)"
        }
    }
    
    // 設置通知監聽
    private func setupNotificationObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUserAuthChange),
            name: .userAuthDidChange,
            object: nil
        )
    }
    
    // 處理使用者驗證狀態變更通知
    @objc private func handleUserAuthChange() {
        Task {
            await loadProfile()
        }
    }
}

#Preview {
    NavigationStack {
        ProfileSettingView()
    }
} 
