import SwiftUICore
import SwiftUI
struct TodoDetailView: View {
    let date: Date
    let todos: [String]
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Text(dateFormatted)
                .font(.title)
                .fontWeight(.bold)
            
            List(todos, id: \.self) { todo in
                Text(todo)
            }
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 15))
            
            Button("關閉") {
                isPresented = false
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding()
        .frame(width: 300, height: 350)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(radius: 10)
    }
    
    private var dateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }
}
