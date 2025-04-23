import SwiftUICore
import SwiftUI

struct SettingsView: View {
    @State private var isDarkMode = true
    @State private var notificationsEnabled = true
    @State private var showingProfileSettings = false
    @State private var iscountdownnoti = true
    @State private var isshockEnabled = true
    @State private var showingStatistics = false
    var todos: [Date: [(task: String, isCompleted: Bool)]]
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景色
                Color(hex: "F3D4B7")
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 25) {
                        // 用戶資訊區域 - 水平排列，使用NavigationLink
                        NavigationLink(destination: ProfileSettingView()) {
                            HStack(spacing: 15) {
                                // 用戶頭像
                                Circle()
                                    .fill(Color(hex: "CBBDAD"))
                                    .frame(width: 70, height: 70)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.black.opacity(0.1), lineWidth: 1)
                                    )
                                    .padding(.leading, 20)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    // 用戶名
                                    Text("wesley cho")
                                        .font(.custom("Arial Rounded MT Bold", size: 24))
                                        .foregroundColor(.black)
                                    
                                    // 到期日期
                                    Text("2025/09/31到期")
                                        .font(.custom("Arial", size: 16))
                                        .foregroundColor(Color.black.opacity(0.5))
                                }
                                
                                Spacer()
                                
                                // 右側箭頭
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.black.opacity(0.5))
                                    .padding(.trailing, 20)
                            }
                        }
                        .padding(.vertical, 15)
                        
                        // VIP卡片 - 移動到上方並添加皇冠到右上方
                        ZStack(alignment: .topTrailing) {
                            // VIP卡片主體內容
                            VStack(spacing: 2) {
                                Text("VIP")
                                    .font(.custom("Helvetica", size: 30))
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.top, 15)
                                    .padding(.bottom, 4) // 縮小上下間距
                                
                                VStack(spacing: 6) { // 縮小項目間間距
                                    VIPFeatureText(text: "解鎖 AI聊天")
                                    VIPFeatureText(text: "解鎖 進階統計")
                                    VIPFeatureText(text: "解鎖 自訂主題")
                                }
                                .padding(.vertical, 5) // 縮小頂部和底部間距
                            }
                            .frame(maxWidth: .infinity)
                            .background(Color(hex: "3A4B5E"))
                            .cornerRadius(16)
                            
                            // 皇冠圖標放在右上角
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
                        
                        // 統計卡片 - 使用NavigationLink而不是Button
                        NavigationLink(destination: StatisticsView(todos: todos)) {
                            HStack {
                                // 統計圖標 - 用柱狀圖
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
                                
                                // 右側箭頭
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.black)
                                    .padding(.trailing, 20)
                            }
                            .frame(height: 60)
                            .background(Color(hex: "FEECD8"))
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
                        
                        // 設定選項卡片 - 系統風格的切換開關
                        VStack(spacing: 0) {
                            // 深色模式
                            SettingRowNew(
                                iconName: "moon.fill",
                                title: "深色模式",
                                isOn: $isDarkMode
                            )
                            
                            Divider()
                                .background(Color.black.opacity(0.1))
                                .padding(.horizontal, 15)
                            
                            // 通知
                            SettingRowNew(
                                iconName: "bell.fill",
                                title: "通知",
                                isOn: $notificationsEnabled
                            )
                            
                            Divider()
                                .background(Color.black.opacity(0.1))
                                .padding(.horizontal, 15)
                            
                            // 震動模式
                            SettingRowNew(
                                iconName: "iphone.radiowaves.left.and.right",
                                title: "震動回饋",
                                isOn: $isshockEnabled
                            )
                        }
                        .padding(.vertical, 5)
                        .background(Color(hex: "FEECD8"))
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 1)
                        .padding(.horizontal, 15)
                        
                        // 計時器設定標題
                        HStack {
                            Text("計時器設定")
                                .font(.system(size: 18, weight: .medium))
                                .padding(.leading, 20)
                            Spacer()
                        }
                        
                        // 計時器設定卡片
                        VStack(spacing: 0) {
                            // 專注時長
                            SettingRowText(
                                iconName: "timer",
                                title: "專注時長"
                            )
                            
                            Divider()
                                .background(Color.black.opacity(0.1))
                                .padding(.horizontal, 15)
                            
                            // 休息時長
                            SettingRowText(
                                iconName: "hourglass",
                                title: "休息時長"
                            )
                            
                            Divider()
                                .background(Color.black.opacity(0.1))
                                .padding(.horizontal, 15)
                            
                            // 倒計時結束音效
                            SettingRowNew(
                                iconName: "speaker.wave.2.fill",
                                title: "倒計時結束音效",
                                isOn: $iscountdownnoti
                            )
                        }
                        .padding(.vertical, 5)
                        .background(Color(hex: "FEECD8"))
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
                            // 版本
                            SettingRowText(
                                iconName: "info.circle",
                                title: "版本 1.0.0"
                            )
                            
                            Divider()
                                .background(Color.black.opacity(0.1))
                                .padding(.horizontal, 15)
                            
                            // 隱私政策
                            SettingRowText(
                                iconName: "lock.shield",
                                title: "隱私政策"
                            )
                            
                            Divider()
                                .background(Color.black.opacity(0.1))
                                .padding(.horizontal, 15)
                            
                            // 使用條款
                            SettingRowText(
                                iconName: "doc.text",
                                title: "使用條款"
                            )
                        }
                        .padding(.vertical, 5)
                        .background(Color(hex: "FEECD8"))
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 1)
                        .padding(.horizontal, 15)
                        
                        Spacer(minLength: 80)
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 50) // 添加底部间距，避免内容被底部导航栏遮挡
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// 更新的設定項目列 - 使用SF Symbols圖標
struct SettingRowNew: View {
    var iconName: String
    var title: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            // 圖標 - 使用SF Symbols
            Image(systemName: iconName)
                .resizable()
                .scaledToFit()
                .frame(width: 22, height: 22)
                .foregroundColor(.black.opacity(0.7))
                .padding(.leading, 20)
            
            // 標題
            Text(title)
                .font(.system(size: 18))
                .padding(.leading, 15)
            
            Spacer()
            
            // 開關 - 使用系統風格
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: Color.green))
                .padding(.trailing, 20)
                .scaleEffect(0.8)
        }
        .frame(height: 55)
    }
}

// 纯文本设置项
struct SettingRowText: View {
    var iconName: String
    var title: String
    
    var body: some View {
        HStack {
            // 圖標 - 使用SF Symbols
            Image(systemName: iconName)
                .resizable()
                .scaledToFit()
                .frame(width: 22, height: 22)
                .foregroundColor(.black.opacity(0.7))
                .padding(.leading, 20)
            
            // 標題
            Text(title)
                .font(.system(size: 18))
                .padding(.leading, 15)
            
            Spacer()
            
            // 右側箭頭
            Image(systemName: "chevron.right")
                .foregroundColor(.black.opacity(0.5))
                .padding(.trailing, 20)
        }
        .frame(height: 55)
    }
}

// VIP功能文字 - 更新樣式
struct VIPFeatureText: View {
    var text: String
    
    var body: some View {
        Text(text)
            .font(.system(size: 15))
            .foregroundColor(.white)
    }
}

// 顏色擴展
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// 為了預覽提供一個初始化方法
extension SettingsView {
    init() {
        self.todos = [:]
    }
}

// 预览提供器
struct SettingsViewPreviews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
