import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = UserSettingsViewModel()
    var todos: [Date: [(task: String, isCompleted: Bool)]]
    @EnvironmentObject private var authState: AuthState
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景色
                Color.hex(hex: "F3D4B7")
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // 用戶資訊區域
                        NavigationLink(destination: ProfileSettingView().environmentObject(authState)) {
                            HStack(spacing: 15) {
                                // 用戶頭像
                                Circle()
                                    .fill(Color.hex(hex: "CBBDAD"))
                                    .frame(width: 60, height: 60)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.black.opacity(0.1), lineWidth: 1)
                                    )
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .font(.system(size: 28))
                                            .foregroundColor(.white)
                                    )

                                VStack(alignment: .leading, spacing: 4) {
                                    // 用戶名
                                    Text(viewModel.userProfile.username)
                                        .font(.custom("Arial Rounded MT Bold", size: 22))
                                        .foregroundColor(.black)
                                        .lineLimit(1)

                                    // 到期日期
                                    let remainingDays = Calendar.current.dateComponents([.day], from: Date(), to: viewModel.userProfile.targetDate).day ?? 0
                                    Text("\(viewModel.userProfile.targetDate.formatted(date: .numeric, time: .omitted))到期")
                                        .font(.custom("Arial", size: 15))
                                        .foregroundColor(Color.black.opacity(0.7))
                                }


                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color.black.opacity(0.3))
                            }
                            .padding(.horizontal, 20)
                        }
                        .padding(.vertical, 16)
                        
                        // 統計資料區域
                        HStack {
                            Text("統計資料")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(Color.black.opacity(0.8))
                                .padding(.leading, 20)
                            Spacer()
                        }
                        .padding(.top, 8)

                        // 統計卡片
                        NavigationLink(destination: StatisticsView(todos: todos)) {
                            HStack(spacing: 12) {
                                Image(systemName: "chart.bar.fill")
                                    .font(.system(size: 22))
                                    .frame(width: 24, height: 24)
                                    .foregroundColor(.black)

                                Text("統計")
                                    .font(.system(size: 17, weight: .medium))
                                    .foregroundColor(.black)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color.black.opacity(0.3))
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(Color.hex(hex: "FEECD8"))
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                        }
                        .padding(.horizontal, 16)
                        
                        // 一般設定標題
                        HStack {
                            Text("一般設定")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(Color.black.opacity(0.8))
                                .padding(.leading, 20)
                            Spacer()
                        }
                        .padding(.top, 8)

                        // 設定選項卡片 - 只保留通知
                        VStack(spacing: 0) {
                            // 通知
                            SettingRowNew(
                                iconName: "bell.fill",
                                title: "通知",
                                isOn: Binding(
                                    get: { viewModel.appSettings.notificationsEnabled },
                                    set: { newValue in
                                        Task {
                                            await viewModel.updateAppSettings(
                                                notificationsEnabled: newValue
                                            )
                                        }
                                    }
                                )
                            )
                        }
                        .padding(.vertical, 8)
                        .background(Color.hex(hex: "FEECD8"))
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                        .padding(.horizontal, 16)
                        
                        // 關於標題
                        HStack {
                            Text("關於")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(Color.black.opacity(0.8))
                                .padding(.leading, 20)
                            Spacer()
                        }
                        .padding(.top, 8)

                        // 關於卡片
                        VStack(spacing: 0) {
                            SettingRowText(
                                iconName: "info.circle",
                                title: "版本 1.0.0"
                            )

                            Divider()
                                .background(Color.black.opacity(0.1))
                                .padding(.horizontal, 20)

                            SettingRowText(
                                iconName: "lock.shield",
                                title: "隱私政策"
                            )

                            Divider()
                                .background(Color.black.opacity(0.1))
                                .padding(.horizontal, 20)

                            SettingRowText(
                                iconName: "doc.text",
                                title: "使用條款"
                            )
                        }
                        .padding(.vertical, 8)
                        .background(Color.hex(hex: "FEECD8"))
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                        .padding(.horizontal, 16)

                        Spacer(minLength: 40)
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
            .alert("錯誤", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("確定", role: .cancel) {}.foregroundColor(Color.black)
            } message: {
                Text(viewModel.errorMessage ?? "").foregroundColor(Color.black)
            }
        }
    }
}

// 其他輔助視圖保持不變... 

// 預覽提供者
#Preview {
    SettingsView(todos: [:])
} 
