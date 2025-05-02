import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = UserSettingsViewModel()
    var todos: [Date: [(task: String, isCompleted: Bool)]]
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景色
                Color.hex(hex: "F3D4B7")
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 25) {
                        // 用戶資訊區域
                        NavigationLink(destination: ProfileSettingView()) {
                            HStack(spacing: 15) {
                                // 用戶頭像
//                                Circle()
//                                    .fill(Color.hex(hex: "CBBDAD"))
//                                    .frame(width: 70, height: 70)
//                                    .overlay(
//                                        Circle()
//                                            .stroke(Color.black.opacity(0.1), lineWidth: 1)
//                                    )
                                                                    
                                VStack(alignment: .leading, spacing: 2) {
                                    // 用戶名
                                    Text(viewModel.userProfile.username)
                                        .font(.custom("Arial Rounded MT Bold", size: 24))
                                        .foregroundColor(.black)
                                    
                                    // 到期日期
                                    let remainingDays = Calendar.current.dateComponents([.day], from: Date(), to: viewModel.userProfile.targetDate).day ?? 0
                                    Text("\(viewModel.userProfile.targetDate.formatted(date: .numeric, time: .omitted))到期")
                                        .font(.custom("Arial", size: 16))
                                        .foregroundColor(Color.black.opacity(0.5))
                                }.padding(.leading, 30)

                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.black.opacity(0.5))
                                    .padding(.trailing, 20)
                            }
                        }
                        .padding(.vertical, 15)
                        
                        // VIP卡片
                        ZStack(alignment: .topTrailing) {
                            VStack(spacing: 2) {
                                Text("VIP")
                                    .font(.custom("Helvetica", size: 35))
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.top, 15)
                                
                                VStack(spacing: 6) {
                                    VIPFeatureText(text: "解鎖 讀書助理")
                                    VIPFeatureText(text: "解鎖 進階統計")
                                    VIPFeatureText(text: "解鎖 自訂主題")
                                }
                                .padding(.vertical, 10)
                            }
                            .frame(maxWidth: .infinity)
                            .background(Color.hex(hex: "3A4B5E"))
                            .cornerRadius(16)
                            
                            Image(systemName: "crown.fill")
                                .resizable()
                                .frame(width: 30, height: 20)
                                .foregroundColor(.yellow.opacity(0.8))
                                .padding(.top, 10)
                                .padding(.trailing, 15)
                        }
                        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 2)
                        .padding(.horizontal, 15)
                        
                        // 統計資料區域
                        HStack {
                            Text("統計資料")
                                .font(.system(size: 18, weight: .medium))
                                .padding(.leading, 20)
                            Spacer()
                        }
                        
                        // 統計卡片
                        NavigationLink(destination: StatisticsView(todos: todos)) {
                            HStack {
                                Image(systemName: "chart.bar.fill")
                                    .resizable()
                                    .frame(width: 24, height: 24)
                                    .padding(.leading, 20)
                                    .foregroundColor(.black)
                                
                                Text("統計")
                                    .font(.system(size: 18))
                                    .padding(.leading, 10)
                                    .foregroundColor(.black)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.black)
                                    .padding(.trailing, 20)
                            }
                            .frame(height: 60)
                            .background(Color.hex(hex: "FEECD8"))
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 1)
                        }
                        .padding(.horizontal, 15)
                        
                        // 一般設定標題
                        HStack {
                            Text("一般設定")
                                .font(.system(size: 18, weight: .medium))
                                .padding(.leading, 20)
                            Spacer()
                        }
                        
                        // 設定選項卡片
                        VStack(spacing: 0) {
                            // 深色模式
                            SettingRowNew(
                                iconName: "moon.fill",
                                title: "深色模式",
                                isOn: Binding(
                                    get: { viewModel.appSettings.isDarkMode },
                                    set: { newValue in
                                        Task {
                                            await viewModel.updateAppSettings(
                                            isDarkMode: newValue,
                                            notificationsEnabled: viewModel.appSettings.notificationsEnabled,
                                            isShockEnabled: viewModel.appSettings.isShockEnabled
                                        )
                                        }
                                    }
                                )
                            )
                            
                            Divider()
                                .background(Color.black.opacity(0.1))
                                .padding(.horizontal, 15)
                            
                            // 通知
                            SettingRowNew(
                                iconName: "bell.fill",
                                title: "通知",
                                isOn: Binding(
                                    get: { viewModel.appSettings.notificationsEnabled },
                                    set: { newValue in
                                        Task {
                                            await viewModel.updateAppSettings(
                                            isDarkMode: viewModel.appSettings.isDarkMode,
                                            notificationsEnabled: newValue,
                                            isShockEnabled: viewModel.appSettings.isShockEnabled
                                        )
                                        }
                                    }
                                )
                            )
                            
                            Divider()
                                .background(Color.black.opacity(0.1))
                                .padding(.horizontal, 15)
                            
                            // 震動模式
                            SettingRowNew(
                                iconName: "iphone.radiowaves.left.and.right",
                                title: "震動回饋",
                                isOn: Binding(
                                    get: { viewModel.appSettings.isShockEnabled },
                                    set: { newValue in
                                        Task {
                                            await viewModel.updateAppSettings(
                                            isDarkMode: viewModel.appSettings.isDarkMode,
                                            notificationsEnabled: viewModel.appSettings.notificationsEnabled,
                                            isShockEnabled: newValue
                                        )
                                        }
                                    }
                                )
                            )
                        }
                        .padding(.vertical, 5)
                        .background(Color.hex(hex: "FEECD8"))
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 1)
                        .padding(.horizontal, 15)
                        
                        // 關於標題
                        HStack {
                            Text("關於")
                                .font(.system(size: 18, weight: .medium))
                                .padding(.leading, 20)
                            Spacer()
                        }
                        
                        // 關於卡片
                        VStack(spacing: 0) {
                            SettingRowText(
                                iconName: "info.circle",
                                title: "版本 1.0.0"
                            )
                            
                            Divider()
                                .background(Color.black.opacity(0.1))
                                .padding(.horizontal, 15)
                            
                            SettingRowText(
                                iconName: "lock.shield",
                                title: "隱私政策"
                            )
                            
                            Divider()
                                .background(Color.black.opacity(0.1))
                                .padding(.horizontal, 15)
                            
                            SettingRowText(
                                iconName: "doc.text",
                                title: "使用條款"
                            )
                        }
                        .padding(.vertical, 5)
                        .background(Color.hex(hex: "FEECD8"))
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 1)
                        .padding(.horizontal, 15)
                        
                        Spacer(minLength: 80)
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 50)
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
            .alert("錯誤", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("確定", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }
}

// 其他輔助視圖保持不變... 

// 預覽提供者
#Preview {
    SettingsView(todos: [:])
} 
