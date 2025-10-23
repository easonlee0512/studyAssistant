//
//  SettingsComponents.swift
//  studyAssistant
//
//  Created by 李翊辰 on 2025/4/30.
//
import SwiftUI

struct VIPFeatureText: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.system(size: 16))
            .foregroundColor(Color.black)
    }
}

struct SettingRowNew: View {
    let iconName: String
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 22))
                .frame(width: 24, height: 24)
                .foregroundColor(.black)

            Text(title)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.black)

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}

struct SettingRowText: View {
    let iconName: String
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 22))
                .frame(width: 24, height: 24)
                .foregroundColor(.black)

            Text(title)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.black)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color.black.opacity(0.3))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}

// 預覽提供者 - 為每個組件添加預覽
#Preview("VIPFeatureText") {
    ZStack {
        Color("#3A4B5E")
        VIPFeatureText(text: "解鎖 讀書助理")
    }
    .frame(height: 100)
}

#Preview("SettingRowNew") {
    SettingRowNew(
        iconName: "moon.fill",
        title: "深色模式",
        isOn: .constant(true)
    )
    .background(Color("#FEECD8"))
}

#Preview("SettingRowText") {
    SettingRowText(
        iconName: "timer",
        title: "專注時長 (30分鐘)"
    )
    .background(Color("#FEECD8"))
}
