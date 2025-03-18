import SwiftUI

struct ProfileSettingsView: View {
    @Environment(\.dismiss) var dismiss
    
    // 添加狀態變量管理用戶資料
    @State private var username = ""
    @State private var goal = ""
    @State private var targetDate = Date()
    @State private var showingLogoutAlert = false
    
    // 學習階段選項
    @State private var selectedStage = "大學"
    let learningStages = ["國中", "高中", "大學", "研究所", "語言學習"]
    
    private var remainingDays: Int {
            let today = Calendar.current.startOfDay(for: Date())
            let target = Calendar.current.startOfDay(for: targetDate)
            return Calendar.current.dateComponents([.day], from: today, to: target).day ?? 0
        }
    
    var body: some View {
        NavigationStack {
            Form {
                // 用戶基本資料區塊
                Section(header: Text("基本資料")) {
                    TextField("使用者名稱", text: $username)
                    TextField("給自己的一句話", text: $goal)
                    DatePicker("目標日期", selection: $targetDate, displayedComponents: .date)
                    HStack {
                        Text("剩餘天數")
                        Spacer()
                        Text("\(remainingDays) 天")
                            .foregroundColor(.gray)
                    }
                }
                
                // 學習階段區塊
                Section(header: Text("學習階段")) {
                    Picker("目前階段", selection: $selectedStage) {
                        ForEach(learningStages, id: \.self) { stage in
                            Text(stage).tag(stage)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                // 帳號操作區塊
                Section {
                    Button(action: {
                        // 顯示確認登出的提示
                        showingLogoutAlert = true
                    }) {
                        Text("登出")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("個人檔案設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("關閉") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") {
                        saveProfile()
                        dismiss()
                    }
                }
            }
            .alert("確定要登出嗎？", isPresented: $showingLogoutAlert) {
                Button("取消", role: .cancel) { }
                Button("登出", role: .destructive) {
                    logout()
                }
            } message: {
                Text("登出後需要重新登入才能使用所有功能")
            }
            .onAppear {
                // 載入用戶資料
                loadProfile()
            }
        }
    }
    
    // 載入用戶資料的函數
    private func loadProfile() {
        // 這裡可以從 UserDefaults 或其他資料源讀取
        username = UserDefaults.standard.string(forKey: "username") ?? ""
        goal = UserDefaults.standard.string(forKey: "userGoal") ?? ""
        if let savedDate = UserDefaults.standard.object(forKey: "targetDate") as? Date {
                    targetDate = savedDate
                }
        selectedStage = UserDefaults.standard.string(forKey: "learningStage") ?? "大學"
    }
    
    // 儲存用戶資料的函數
    private func saveProfile() {
        // 儲存到 UserDefaults 或其他資料源
        UserDefaults.standard.set(username, forKey: "username")
        UserDefaults.standard.set(goal, forKey: "userGoal")
        UserDefaults.standard.set(targetDate, forKey: "targetDate")
        UserDefaults.standard.set(selectedStage, forKey: "learningStage")
    }
    
    // 登出函數
    private func logout() {
        // 實現登出邏輯
        // 清除用戶資料、登出狀態等
        UserDefaults.standard.set(false, forKey: "isLoggedIn")
        dismiss()
    }
}

#Preview {
    ProfileSettingsView()
}
