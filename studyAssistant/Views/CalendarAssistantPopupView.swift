import SwiftUI

struct CalendarAssistantPopupView: View {
    // MARK: - State Variables
    @Binding var isPresented: Bool
    @State private var inputText: String = ""
    @State private var autoUpdateEnabled: Bool = false
    @State private var showTaskCards: Bool = false
    @State private var expandedSections: Set<String> = [] // "added", "deleted", "updated"

    // MARK: - Environment Objects
    @EnvironmentObject var todoViewModel: TodoViewModel
    @EnvironmentObject var staticViewModel: StaticViewModel
    @StateObject private var assistantViewModel = CalendarAssistantViewModel()

    // MARK: - Constants - 參考 ChatSettingView 的配色
    private let backgroundColor = Color.hex(hex: "F3D4B7")
    private let accentColor = Color.hex(hex: "E27844")
    private let cardColor = Color.hex(hex: "FEECD8")

    // 任務卡片字體大小 - 與 ChatView 一致
    private let taskTitleSize: CGFloat = 16
    private let taskContentSize: CGFloat = 14
    private let taskHeaderSize: CGFloat = 17
    private let taskCountSize: CGFloat = 15

    // MARK: - UserDefaults Keys
    private let inputTextKey = "calendarAssistant_inputText"
    private let autoUpdateKey = "calendarAssistant_autoUpdate"

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
            .contentShape(Rectangle())
            .onTapGesture {
                // 點擊標題區域關閉鍵盤
                hideKeyboard()
            }

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
                        .frame(height: 120) // 縮小以留出空間給任務卡片
                        .scrollContentBackground(.hidden)
                        .disabled(assistantViewModel.isUpdating)
                        .onChange(of: inputText) { newValue in
                            // 儲存輸入文字到本地
                            saveInputText(newValue)
                        }

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
                .disabled(assistantViewModel.isUpdating)
                .onChange(of: autoUpdateEnabled) { newValue in
                    // 儲存自動更新設定到本地
                    saveAutoUpdate(newValue)
                }
            }
            .padding()
            .background(cardColor)
            .contentShape(Rectangle())
            .onTapGesture {
                // 點擊 Toggle 區域關閉鍵盤（不影響 Toggle 本身的點擊）
                hideKeyboard()
            }

            // 任務卡片顯示區域
            if showTaskCards {
                ScrollView {
                    VStack(spacing: 12) {
                        // 新增任務區域
                        if !assistantViewModel.addedTasks.isEmpty {
                            taskSection(
                                title: "已新增的任務 (\(assistantViewModel.addedTasks.count))",
                                sectionId: "added",
                                color: .green
                            ) {
                                let isExpanded = expandedSections.contains("added")
                                let displayTasks = isExpanded ? assistantViewModel.addedTasks : Array(assistantViewModel.addedTasks.prefix(1))

                                ForEach(displayTasks) { task in
                                    taskAddItemView(task: task)
                                }

                                if assistantViewModel.addedTasks.count > 1 {
                                    expandButton(sectionId: "added", totalCount: assistantViewModel.addedTasks.count)
                                }
                            }
                        }

                        // 刪除任務區域
                        if !assistantViewModel.deletedTasks.isEmpty {
                            taskSection(
                                title: "已刪除的任務 (\(assistantViewModel.deletedTasks.count))",
                                sectionId: "deleted",
                                color: .red
                            ) {
                                let isExpanded = expandedSections.contains("deleted")
                                let displayTasks = isExpanded ? assistantViewModel.deletedTasks : Array(assistantViewModel.deletedTasks.prefix(1))

                                ForEach(displayTasks) { task in
                                    taskDeleteItemView(task: task)
                                }

                                if assistantViewModel.deletedTasks.count > 1 {
                                    expandButton(sectionId: "deleted", totalCount: assistantViewModel.deletedTasks.count)
                                }
                            }
                        }

                        // 修改任務區域
                        if !assistantViewModel.updatedTasks.isEmpty {
                            taskSection(
                                title: "已修改的任務 (\(assistantViewModel.updatedTasks.count))",
                                sectionId: "updated",
                                color: .blue
                            ) {
                                let isExpanded = expandedSections.contains("updated")
                                let displayTasks = isExpanded ? assistantViewModel.updatedTasks : Array(assistantViewModel.updatedTasks.prefix(1))

                                ForEach(0..<displayTasks.count, id: \.self) { index in
                                    taskUpdateItemView(updateData: displayTasks[index], index: index, total: assistantViewModel.updatedTasks.count)
                                }

                                if assistantViewModel.updatedTasks.count > 1 {
                                    expandButton(sectionId: "updated", totalCount: assistantViewModel.updatedTasks.count)
                                }
                            }
                        }

                        // 顯示錯誤信息
                        if let error = assistantViewModel.updateError {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("錯誤")
                                    .font(.system(size: taskHeaderSize, weight: .semibold))
                                    .foregroundColor(.red)
                                Text(error)
                                    .font(.system(size: taskContentSize))
                                    .foregroundColor(.black)
                            }
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .frame(maxHeight: 300)
                .background(cardColor)
                .contentShape(Rectangle())
                .onTapGesture {
                    // 點擊任務卡片區域關閉鍵盤
                    hideKeyboard()
                }
            }

            // 狀態顯示區域
            if assistantViewModel.isUpdating && !assistantViewModel.currentStatus.isEmpty {
                VStack(spacing: 8) {
                    Text(assistantViewModel.currentStatus)
                        .font(.system(size: 14))
                        .foregroundColor(.black.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 8)
                .padding(.horizontal)
                .background(cardColor)
            }

            // 立即更新按鈕
            Button(action: {
                guard !inputText.isEmpty else { return }

                Task {
                    showTaskCards = false
                    expandedSections.removeAll()
                    await assistantViewModel.startUpdate(userInput: inputText)
                    showTaskCards = true
                }
            }) {
                HStack {
                    if assistantViewModel.isUpdating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Text("更新中...")
                            .font(.system(size: 18, weight: .semibold))
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16, weight: .semibold))
                        Text("立即更新")
                            .font(.system(size: 18, weight: .semibold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(assistantViewModel.isUpdating || inputText.isEmpty ? accentColor.opacity(0.5) : accentColor)
                .cornerRadius(12)
                .shadow(color: accentColor.opacity(0.3), radius: 4, x: 0, y: 2)
            }
            .disabled(assistantViewModel.isUpdating || inputText.isEmpty)
            .padding()
            .background(cardColor)
            .contentShape(Rectangle())
            .onTapGesture {
                // 點擊按鈕區域關閉鍵盤
                hideKeyboard()
            }
        }
        .background(cardColor)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.15), radius: 4, x: 2, y: 2)
        .frame(width: 360)  // 縮小寬度從 420 到 360
        .frame(maxHeight: 650)
        .onAppear {
            // 注入依賴
            assistantViewModel.todoViewModel = todoViewModel
            assistantViewModel.staticViewModel = staticViewModel

            // 載入儲存的資料
            loadSavedData()
        }
    }

    // MARK: - Keyboard Helper

    /// 隱藏鍵盤
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    // MARK: - Local Storage

    /// 儲存輸入文字到本地
    private func saveInputText(_ text: String) {
        UserDefaults.standard.set(text, forKey: inputTextKey)
    }

    /// 儲存自動更新設定到本地
    private func saveAutoUpdate(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: autoUpdateKey)
    }

    /// 載入儲存的資料
    private func loadSavedData() {
        // 載入輸入文字
        if let savedText = UserDefaults.standard.string(forKey: inputTextKey) {
            inputText = savedText
        }

        // 載入自動更新設定
        autoUpdateEnabled = UserDefaults.standard.bool(forKey: autoUpdateKey)
    }

    // MARK: - Helper Views

    /// 任務區段容器
    private func taskSection<Content: View>(
        title: String,
        sectionId: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: taskHeaderSize, weight: .semibold))
                .foregroundColor(.black)
                .padding(.horizontal, 8)

            VStack(alignment: .leading, spacing: 8) {
                content()
            }
        }
        .padding(8)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }

    /// 展開/收起按鈕
    private func expandButton(sectionId: String, totalCount: Int) -> some View {
        Button(action: {
            withAnimation {
                if expandedSections.contains(sectionId) {
                    expandedSections.remove(sectionId)
                } else {
                    expandedSections.insert(sectionId)
                }
            }
        }) {
            HStack {
                Text(expandedSections.contains(sectionId) ? "收起" : "展開全部 (\(totalCount) 個任務)")
                Image(systemName: expandedSections.contains(sectionId) ? "chevron.up" : "chevron.down")
            }
            .foregroundColor(Color.black)
            .opacity(0.8)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Task Item Views (復用自 ChatView)

    /// 格式化日期時間
    private func formatDate(_ date: Date?, isAllDay: Bool) -> String {
        guard let date = date else { return "未設定" }
        let formatter = DateFormatter()
        if isAllDay {
            formatter.dateFormat = "yyyy/MM/dd"
        } else {
            formatter.dateFormat = "yyyy/MM/dd HH:mm"
        }
        return formatter.string(from: date)
    }

    /// 顯示單個待新增任務的視圖
    private func taskAddItemView(task: PendingTask) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("標題: " + task.title)
                .font(.system(size: taskTitleSize, weight: .medium))
                .fixedSize(horizontal: false, vertical: true)
            Text("備註: " + task.note)
                .font(.system(size: taskContentSize))
                .fixedSize(horizontal: false, vertical: true)
            Text("類別: " + task.category)
                .font(.system(size: taskContentSize))
                .fixedSize(horizontal: false, vertical: true)
            Text("開始時間: " + formatDate(task.startDate, isAllDay: task.isAllDay))
                .font(.system(size: taskContentSize))
                .fixedSize(horizontal: false, vertical: true)
            Text("結束時間: " + formatDate(task.endDate, isAllDay: task.isAllDay))
                .font(.system(size: taskContentSize))
                .fixedSize(horizontal: false, vertical: true)
            Text("全天: " + (task.isAllDay ? "是" : "否"))
                .font(.system(size: taskContentSize))
            Text("已完成: " + (task.isCompleted ? "是" : "否"))
                .font(.system(size: taskContentSize))
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }

    /// 顯示單個待刪除任務的視圖
    private func taskDeleteItemView(task: TodoTask) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("標題: " + task.title)
                .font(.system(size: taskTitleSize, weight: .medium))
            if !task.note.isEmpty {
                Text("備註: " + task.note)
                    .font(.system(size: taskContentSize))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("類別: " + task.category)
                .font(.system(size: taskContentSize))
                .fixedSize(horizontal: false, vertical: true)
            Text("開始時間: " + formatDate(task.startDate, isAllDay: task.isAllDay))
                .font(.system(size: taskContentSize))
                .fixedSize(horizontal: false, vertical: true)
            Text("結束時間: " + formatDate(task.endDate, isAllDay: task.isAllDay))
                .font(.system(size: taskContentSize))
                .fixedSize(horizontal: false, vertical: true)
            Text("全天: " + (task.isAllDay ? "是" : "否"))
                .font(.system(size: taskContentSize))
            Text("已完成: " + (task.isCompleted ? "是" : "否"))
                .font(.system(size: taskContentSize))
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
    }

    /// 顯示單個待修改任務的視圖
    private func taskUpdateItemView(updateData: (original: TodoTask, updated: PendingTask), index: Int, total: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if total > 1 {
                Text("任務 \(index + 1) / \(total)")
                    .font(.system(size: taskCountSize))
                    .foregroundColor(Color.black)
                    .padding(.bottom, 2)
            }

            HStack(alignment: .top, spacing: 10) {
                // 原始任務數據
                VStack(alignment: .leading, spacing: 5) {
                    Text("原始資料")
                        .font(.system(size: taskHeaderSize, weight: .semibold))
                        .foregroundColor(Color.black)
                        .padding(.bottom, 2)

                    Text("標題: " + updateData.original.title)
                        .font(.system(size: taskTitleSize, weight: .medium))
                        .foregroundColor(Color.black)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("備註: " + updateData.original.note)
                        .font(.system(size: taskContentSize))
                        .foregroundColor(Color.black)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("類別: " + updateData.original.category)
                        .font(.system(size: taskContentSize))
                        .foregroundColor(Color.black)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("開始時間: " + formatDate(updateData.original.startDate, isAllDay: updateData.original.isAllDay))
                        .font(.system(size: taskContentSize))
                        .foregroundColor(Color.black)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("結束時間: " + formatDate(updateData.original.endDate, isAllDay: updateData.original.isAllDay))
                        .font(.system(size: taskContentSize))
                        .foregroundColor(Color.black)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("全天: " + (updateData.original.isAllDay ? "是" : "否"))
                        .font(.system(size: taskContentSize))
                        .foregroundColor(Color.black)
                    Text("已完成: " + (updateData.original.isCompleted ? "是" : "否"))
                        .font(.system(size: taskContentSize))
                        .foregroundColor(Color.black)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .frame(maxWidth: .infinity)

                // 更新後的任務數據
                VStack(alignment: .leading, spacing: 5) {
                    Text("更新後資料")
                        .font(.system(size: taskHeaderSize, weight: .semibold))
                        .foregroundColor(Color.black)
                        .padding(.bottom, 2)

                    Text("標題: " + updateData.updated.title)
                        .font(.system(size: taskTitleSize, weight: .medium))
                        .foregroundColor(Color.black)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("備註: " + updateData.updated.note)
                        .font(.system(size: taskContentSize))
                        .foregroundColor(Color.black)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("類別: " + updateData.updated.category)
                        .font(.system(size: taskContentSize))
                        .foregroundColor(Color.black)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("開始時間: " + formatDate(updateData.updated.startDate, isAllDay: updateData.updated.isAllDay))
                        .font(.system(size: taskContentSize))
                        .foregroundColor(Color.black)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("結束時間: " + formatDate(updateData.updated.endDate, isAllDay: updateData.updated.isAllDay))
                        .font(.system(size: taskContentSize))
                        .foregroundColor(Color.black)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("全天: " + (updateData.updated.isAllDay ? "是" : "否"))
                        .font(.system(size: taskContentSize))
                        .foregroundColor(Color.black)
                    Text("已完成: " + (updateData.updated.isCompleted ? "是" : "否"))
                        .font(.system(size: taskContentSize))
                        .foregroundColor(Color.black)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
                .frame(maxWidth: .infinity)
            }
        }
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
