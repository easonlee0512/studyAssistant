import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ChatViewModel()

    var body: some View {
        VStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(viewModel.messages, id: \.self) { message in
                        Text(message)
                            .padding()
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding()
            .frame(maxHeight: .infinity)

            VStack(spacing: 10) {
                VStack(alignment: .leading) {
                    TextField("輸入計畫標題 (必填) 例如：國文", text: $viewModel.planTitle)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                        .background(Color.gray.opacity(0.1))
                    
                    if viewModel.isPlanTitleEmpty {
                        Text("請輸入計畫標題")
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding(.horizontal)
                    }
                }
                
                VStack(alignment: .leading) {
                    TextField("輸入科目範圍 (必填) 例如：10個章節", text: $viewModel.subjectRange)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                        .background(Color.gray.opacity(0.1))
                    
                    if viewModel.isSubjectRangeEmpty {
                        Text("請輸入科目範圍")
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding(.horizontal)
                    }
                }
            }
            
            TextField("讀書偏好時間 例如：禮拜六晚上", text: $viewModel.preferredTime)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
                .background(Color.gray.opacity(0.1))
            
            TextField("備注 例如：每個章節有哪幾小節", text: $viewModel.note)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
                .background(Color.gray.opacity(0.1))

            DatePicker("計畫期限", selection: $viewModel.deadline, displayedComponents: .date)
                .datePickerStyle(.compact)
                .padding(.horizontal)
                .background(Color.gray.opacity(0.1))

            Button(action: {
                viewModel.sendMessage()
            }) {
                Text("生成計畫")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
    }
}

#Preview {
    ContentView()
}
