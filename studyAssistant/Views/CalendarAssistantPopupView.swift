import SwiftUI

struct CalendarAssistantPopupView: View {
    // MARK: - State Variables
    @Binding var isPresented: Bool
    @State private var inputText: String = ""
    @State private var autoUpdateEnabled: Bool = false

    // MARK: - Constants - 參考 ChatSettingView 的配色
    private let backgroundColor = Color.hex(hex: "F3D4B7")
    private let accentColor = Color.hex(hex: "E27844")
    private let cardColor = Color.hex(hex: "FEECD8")

    var body: some View {
        VStack(spacing: 0) {
            // 標題區域
            HStack {
                Text("日曆安排助手")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.black)

                Spacer()

                // 關閉按鈕 - 橘色
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isPresented = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(accentColor)
                }
            }
            .padding()
            .background(cardColor)

            // 輸入框區域（參考 ChatSettingView 的 TextField 樣式）
            VStack(alignment: .leading, spacing: 10) {
                Text("輸入日程安排")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.black)

                ZStack(alignment: .topLeading) {
                    // 淡灰色背景的 TextEditor
                    TextEditor(text: $inputText)
                        .font(.system(size: 16))
                        .foregroundColor(.black)
                        .padding(12)
                        .background(Color.gray.opacity(0.08))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.08), lineWidth: 1)
                        )
                        .frame(height: 200) // 固定高度，佔約60%的視覺空間
                        .scrollContentBackground(.hidden)

                    // 占位符提示文字
                    if inputText.isEmpty {
                        Text("可以輸入希望助手每日如何自動調整日曆")
                            .font(.system(size: 16))
                            .foregroundColor(.gray.opacity(0.6))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 10)
                            .allowsHitTesting(false) // 允許點擊穿透
                    }
                }
            }
            .padding()
            .background(cardColor)

            // 每日自動更新 Toggle（參考 ChatSettingView 的 Toggle 樣式）
            VStack(alignment: .leading, spacing: 15) {
                Toggle(isOn: $autoUpdateEnabled) {
                    Text("每日自動更新")
                        .font(.system(size: 18))
                        .foregroundColor(.black)
                }
                .tint(accentColor)
            }
            .padding()
            .background(cardColor)

            // 立即更新按鈕
            Button(action: {
                // TODO: 實作更新功能
                print("立即更新按鈕被點擊")
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16, weight: .semibold))

                    Text("立即更新")
                        .font(.system(size: 18, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(accentColor)
                .cornerRadius(12)
                .shadow(color: accentColor.opacity(0.3), radius: 4, x: 0, y: 2)
            }
            .padding()
            .background(cardColor)
        }
        .background(cardColor)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.15), radius: 4, x: 2, y: 2)
        .frame(width: 350)
    }
}

// MARK: - Preview
#Preview {
    ZStack(alignment: .topLeading) {
        Color.hex(hex: "F3D4B8")
            .ignoresSafeArea()

        CalendarAssistantPopupView(isPresented: .constant(true))
            .padding(.top, 160)
            .padding(.leading, 20)
    }
}
