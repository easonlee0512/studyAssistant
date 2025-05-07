// 為了預覽提供空的任務列表
struct TodoAddView_Previews: PreviewProvider {
    @State static var isShown = true
    static var viewModel = TodoViewModel()
    static var staticViewModel = StaticViewModel()
    
    static var previews: some View {
        TodoAddView(viewModel: viewModel, isPresented: $isShown, selectedDate: Date())
            .environmentObject(viewModel)
            .environmentObject(staticViewModel)
    }
} 