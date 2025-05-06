import SwiftUI
import Firebase
import FirebaseAuth // 顯式導入 FirebaseAuth
import Foundation // 確保可以訪問 NotificationConstants
import Combine // 導入 Combine 框架

// 創建一個觀察器類來處理通知
class AuthChangeObserver: ObservableObject {
    @Published var shouldReloadProfile = false
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // 使用 NotificationCenter.Publisher 替代 addObserver
        NotificationCenter.default.publisher(for: .userAuthDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.shouldReloadProfile = true
            }
            .store(in: &cancellables)
    }
}

struct ProfileSettingView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = UserSettingsViewModel()
    @StateObject private var authObserver = AuthChangeObserver()
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
    
    // 統一應用的顏色
    let backgroundColor = Color.hex(hex: "F3D4B7") // 背景色
    let cardColor = Color.hex(hex: "FEECD8") // 卡片顏色
    let accentColor = Color.hex(hex: "E28A5F") // 按鈕強調色
    
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
                        if let email = FirebaseAuth.Auth.auth().currentUser?.email {
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
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(accentColor)
                                    .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                                
                                Text("儲存變更")
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding()
                            }
                            .frame(maxWidth: .infinity, minHeight: 50)
                        }
                        .padding(.horizontal)
                        .disabled(isLoading)
                        .opacity(isLoading ? 0.6 : 1)
                        
                        Spacer(minLength: 30)
                    
                        // 登出按鈕
                        Button(action: {
                            showingLogoutAlert = true
                        }) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(red: 0.8, green: 0.2, blue: 0.2))
                                    .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                                
                                Text("登出")
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding()
                            }
                            .frame(maxWidth: .infinity, minHeight: 50)
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
        }
        .onChange(of: authObserver.shouldReloadProfile) { newValue in
            if newValue {
                Task {
                    await loadProfile()
                    authObserver.shouldReloadProfile = false
                }
            }
        }
        .onDisappear {
            // 不再需要移除通知觀察者，Combine 會自動處理
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
                // 確保無論如何都發送一次通知
                NotificationCenter.default.post(name: .userProfileDidChange, object: nil)
                print("ProfileSettingView: 已發送設定更新通知")
            }
        }
        
        DispatchQueue.main.async {
            self.isLoading = false
        }
    }
    
    // 登出
    private func logout() {
        do {
            try FirebaseAuth.Auth.auth().signOut()
            viewModel.clearAllData()
            
            // 發送通知通知其他視圖使用者已登出
            NotificationCenter.default.post(name: .userAuthDidChange, object: nil)
            
            dismiss()
        } catch {
            showError = true
            errorMessage = "登出失敗：\(error.localizedDescription)"
        }
    }
}

#Preview {
    NavigationStack {
        ProfileSettingView()
    }
} 
