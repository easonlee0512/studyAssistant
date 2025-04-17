import SwiftUI

// 簡化的統計視圖，僅包含界面元素
struct StatisticsTestView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 增加頂部空間
                Spacer()
                    .frame(height: 30)
                
                // 頂部標題
                Text("統計分析")
                    .font(.system(size: 32, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 10)
                
                // 學習進度卡片
                VStack(alignment: .leading, spacing: 16) {
                    Text("學習進度")
                        .font(.system(size: 20, weight: .bold))
                    
                    // 離散數學進度
                    HStack {
                        Text("離散數學")
                            .font(.system(size: 16))
                            .frame(width: 80, alignment: .leading)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color.white.opacity(0.5))
                                    .frame(height: 10)
                                    .cornerRadius(5)
                                
                                Rectangle()
                                    .fill(Color.blue)
                                    .frame(width: 100, height: 10)
                                    .cornerRadius(5)
                            }
                            
                            Text("34%")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    // 線性代數進度
                    HStack {
                        Text("線性代數")
                            .font(.system(size: 16))
                            .frame(width: 80, alignment: .leading)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color.white.opacity(0.5))
                                    .frame(height: 10)
                                    .cornerRadius(5)
                                
                                Rectangle()
                                    .fill(Color.purple)
                                    .frame(width: 150, height: 10)
                                    .cornerRadius(5)
                            }
                            
                            Text("45%")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding()
                .background(Color(red: 1, green: 0.93, blue: 0.85))
                .cornerRadius(16)
                .shadow(radius: 2)
                
                // 專注時長統計卡片
                VStack(alignment: .leading, spacing: 16) {
                    Text("專注時長統計")
                        .font(.system(size: 20, weight: .bold))
                    
                    HStack(spacing: 15) {
                        // 總專注時長
                        VStack(spacing: 5) {
                            Text("總專注時長")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text("5h38m")
                                .font(.system(size: 20, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(10)
                        .background(Color.white.opacity(0.5))
                        .cornerRadius(8)
                        
                        // 專注次數
                        VStack(spacing: 5) {
                            Text("專注次數")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text("8次")
                                .font(.system(size: 20, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(10)
                        .background(Color.white.opacity(0.5))
                        .cornerRadius(8)
                    }
                }
                .padding()
                .background(Color(red: 1, green: 0.93, blue: 0.85))
                .cornerRadius(16)
                .shadow(radius: 2)
                
                // 每日專注時長分布
                VStack(alignment: .leading, spacing: 16) {
                    Text("專注時長")
                        .font(.system(size: 20, weight: .bold))
                    
                    HStack {
                        VStack(alignment: .trailing, spacing: 10) {
                            Text("3").font(.caption)
                            Text("6").font(.caption)
                            Text("9").font(.caption)
                            Text("12").font(.caption)
                            Text("15").font(.caption)
                            Text("18").font(.caption)
                            Text("21").font(.caption)
                            Text("24").font(.caption)
                        }
                        .foregroundColor(.gray)
                        .frame(width: 30)
                        
                        VStack(spacing: 10) {
                            // 時間條形圖
                            Rectangle().fill(Color.pink).frame(width: 200, height: 16).cornerRadius(3)
                            Rectangle().fill(Color.blue).frame(width: 120, height: 16).cornerRadius(3)
                            Rectangle().fill(Color.green).frame(width: 80, height: 16).cornerRadius(3)
                            Rectangle().fill(Color.purple).frame(width: 150, height: 16).cornerRadius(3)
                            Rectangle().fill(Color.clear).frame(height: 16)
                            Rectangle().fill(Color.orange).frame(width: 180, height: 16).cornerRadius(3)
                            Rectangle().fill(Color.clear).frame(height: 16)
                            Rectangle().fill(Color.clear).frame(height: 16)
                        }
                    }
                }
                .padding()
                .background(Color(red: 1, green: 0.93, blue: 0.85))
                .cornerRadius(16)
                .shadow(radius: 2)
            }
            .padding()
            .padding(.top, 20)  // 增加頂部邊距
            .frame(maxWidth: .infinity)
        }
        .background(Color(red: 0.95, green: 0.83, blue: 0.72))
        .edgesIgnoringSafeArea(.all)
    }
}

struct StatisticsTestView_Previews: PreviewProvider {
    static var previews: some View {
        StatisticsTestView()
    }
}
