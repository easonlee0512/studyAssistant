import SwiftUI
import SwiftUICore

struct ProfileSettingView: View {
    @Environment(\.dismiss) var dismiss
    
    // 添加狀態變量管理用戶資料
    @State private var username = ""
    @State private var goal = ""
    @State private var targetDate = Date()
    @State private var showingLogoutAlert = false
    
    // 學習階段選項
    @State private var selectedStage = "大學"
    let learningStages = ["國中", "高中", "大學", "研究所", "語言學習"]
    
    // 計算剩餘天數
    private var remainingDays: Int {
        let today = Calendar.current.startOfDay(for: Date())
        let target = Calendar.current.startOfDay(for: targetDate)
        return Calendar.current.dateComponents([.day], from: today, to: target).day ?? 0
    }
    
    // 截图中的颜色
    let backgroundColor = Color(hex: "F5DFC7") // 浅米色背景
    let cardBackgroundColor = Color(hex: "FEECD8") // 卡片背景色
    let textColor = Color.black.opacity(0.8)
    let placeholderColor = Color.black.opacity(0.4)
    let dividerColor = Color.black.opacity(0.1)
    
    var body: some View {
        ZStack {
            // 背景色
            Color(hex: "F3D4B7")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 顶部导航栏
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.black)
                    }
                    .padding(.leading, 10)
                    
                    Spacer()
                    
                    Text("個人資料")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.black)
                    
                    Spacer()
                    
                    Button("儲存") {
                        saveProfile()
                        dismiss()
                    }
                    .foregroundColor(.black)
                    .font(.system(size: 17, weight: .medium))
                    .padding(.trailing, 10)
                }
                .padding(.horizontal, 10)
                .padding(.top, 15)
                .padding(.bottom, 25)
                
                // 頭像
                Circle()
                    .fill(Color(hex: "D9D9D9")) // 灰色头像
                    .frame(width: 80, height: 80)
                    .overlay(
                        Circle()
                            .stroke(Color.black.opacity(0.2), lineWidth: 1)
                    )
                    .padding(.bottom, 25)
                
                // 个人资料卡片
                VStack(spacing: 0) {
                    // 用户名区域
                    VStack(alignment: .leading, spacing: 2) {
                        Text("使用者名稱")
                            .font(.system(size: 15))
                            .foregroundColor(placeholderColor)
                            .padding(.top, 20)
                            .padding(.horizontal, 20)
                        
                        TextField("", text: $username)
                            .font(.system(size: 17))
                            .foregroundColor(textColor)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 8)
                    }
                    
                    Divider()
                        .background(dividerColor)
                        .padding(.horizontal, 20)
                    
                    // 鼓励语句区域
                    VStack(alignment: .leading, spacing: 2) {
                        Text("給自己的一句話")
                            .font(.system(size: 15))
                            .foregroundColor(placeholderColor)
                            .padding(.top, 20)
                            .padding(.horizontal, 20)
                        
                        TextField("", text: $goal)
                            .font(.system(size: 17))
                            .foregroundColor(textColor)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 8)
                    }
                    
                    Divider()
                        .background(dividerColor)
                        .padding(.horizontal, 20)
                    
                    // 目标日期区域
                    HStack {
                        Text("目標日期")
                            .font(.system(size: 17))
                            .foregroundColor(textColor)
                        
                        Spacer()
                        
                        // 日期选择器 - 圆角背景样式
                        DatePicker("", selection: $targetDate, displayedComponents: .date)
                            .labelsHidden()
                            .datePickerStyle(.compact)
                            .accentColor(.black)
                            .background(Color(hex: "E6E6E6"))
                            .cornerRadius(8)
                            .scaleEffect(0.9)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    
                    Divider()
                        .background(dividerColor)
                        .padding(.horizontal, 20)
                    
                    // 剩余天数区域
                    HStack {
                        Text("剩餘天數")
                            .font(.system(size: 17))
                            .foregroundColor(textColor)
                        
                        Spacer()
                        
                        Text("\(remainingDays)天")
                            .font(.system(size: 17))
                            .foregroundColor(placeholderColor)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    
                    Divider()
                        .background(dividerColor)
                        .padding(.horizontal, 20)
                    
                    // 學習階段區域
                    HStack {
                        Text("目前階段")
                            .font(.system(size: 17))
                            .foregroundColor(textColor)
                        
                        Spacer()
                        
                        Picker("", selection: $selectedStage) {
                            ForEach(learningStages, id: \.self) { stage in
                                Text(stage).tag(stage)
                            }
                        }
                        .pickerStyle(.menu)
                        .accentColor(.black)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    
                    Divider()
                        .background(dividerColor)
                        .padding(.horizontal, 20)
                    
                    // 登出按鈕
                    Button(action: {
                        showingLogoutAlert = true
                    }) {
                        HStack {
                            Text("登出")
                                .font(.system(size: 17))
                                .foregroundColor(.red)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.red)
                                .font(.system(size: 14))
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                }
                .background(cardBackgroundColor)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 1)
                .padding(.horizontal, 15)
                
                Spacer()
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
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
        .transition(.move(edge: .trailing))
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
    ProfileSettingView()
}
