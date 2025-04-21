//
//  testPersonal.swift
//  studyAssistant
//
//  Created by 李翊辰 on 2025/4/21.
//
import SwiftUI

struct PersonSetting: View {
    @State private var username: String = "使用者名稱"
    @State private var motivationalQuote: String = "鼓勵語句"
    @State private var targetDate: Date = Calendar.current.date(from: DateComponents(year: 2026, month: 2, day: 19)) ?? Date()
    
    // 计算剩余天数
    private var remainingDays: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: targetDate)
        return components.day ?? 0
    }
    
    // Figma中使用的颜色
    let backgroundColor = Color(red: 243/255, green: 212/255, blue: 183/255) // #F3D4B7
    let cardBackgroundColor = Color(red: 254/255, green: 236/255, blue: 216/255) // #FEECD8
    let grayColor = Color(red: 203/255, green: 189/255, blue: 173/255) // #CBBDAD
    let dividerColor = Color.black.opacity(0.26)
    
    var body: some View {
        ZStack {
            // 背景色
            backgroundColor.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                // 顶部区域
                HStack {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.black)
                    
                    Spacer()
                    
                    
                       
                }
                .padding(.horizontal, 20)
                .padding(.top, 30)
                
                VStack(spacing:20){
                    Circle()
                        .fill(grayColor)
                        .frame(width: 80, height: 80)
                        .overlay(
                            Circle()
                                .stroke(Color.black, lineWidth: 1)
                        )
                }
                // 个人资料卡片
                VStack(spacing: 20) {
                    // 用户名区域
                    HStack {
                        Text(username)
                            .font(.custom("Noto Sans TC", size: 20))
                            .foregroundColor(grayColor)
                        Spacer()
                    }
                    .padding(.top, 10)
                    
                    Divider()
                        .background(dividerColor)
                    
                    // 鼓励语句区域
                    HStack {
                        Text(motivationalQuote)
                            .font(.custom("Noto Sans TC", size: 20))
                            .foregroundColor(grayColor)
                        Spacer()
                    }
                    
                    Divider()
                        .background(dividerColor)
                    
                    // 目标日期区域
                    HStack {
                        Text("目標日期")
                            .font(.custom("Noto Sans TC", size: 20))
                            .foregroundColor(.black)
                        Spacer()
                        
                        // 日期小标签
                        Text(formatDate(targetDate))
                            .font(.custom("Noto Sans TC", size: 20))
                            .foregroundColor(.black)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color(red: 217/255, green: 217/255, blue: 217/255)) // #D9D9D9
                            .cornerRadius(5)
                    }
                    
                    Divider()
                        .background(dividerColor)
                    
                    // 剩余天数区域
                    HStack {
                        Text("剩餘天數")
                            .font(.custom("Noto Sans TC", size: 20))
                            .foregroundColor(.black)
                        Spacer()
                        Text("\(remainingDays)天")
                            .font(.custom("Noto Sans TC", size: 20))
                            .foregroundColor(grayColor)
                    }
                    .padding(.bottom, 10)
                }
                .padding(.horizontal, 20)
                .background(cardBackgroundColor)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.1), radius: 12, x: 1, y: 1)
                .padding(.horizontal, 20)
                
                Spacer()
            }
        }
        .navigationBarHidden(true)
    }
    
    // 格式化日期为 "MMM dd, yyyy" 格式
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d,yyyy"
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: date)
    }
}

struct PersonSetting_Previews: PreviewProvider {
    static var previews: some View {
        PersonSetting()
    }
}

