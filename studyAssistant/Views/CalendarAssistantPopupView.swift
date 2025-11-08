import SwiftUI

struct CalendarAssistantPopupView: View {
    // MARK: - State Variables
    @Binding var isPresented: Bool
    @State private var showTaskCards: Bool = false
    @State private var expandedSections: Set<String> = [] // "added", "deleted", "updated"

    // MARK: - Environment Objects
    @EnvironmentObject var todoViewModel: TodoViewModel
    @EnvironmentObject var staticViewModel: StaticViewModel
    @EnvironmentObject var assistantViewModel: CalendarAssistantViewModel

    // MARK: - Constants - 參考 ChatSettingView 的配色
    private let backgroundColor = Color.hex(hex: "F3D4B7")
    private let accentColor = Color.hex(hex: "E27844")
    private let cardColor = Color.hex(hex: "FEECD8")

    // 任務卡片字體大小 - 與 ChatView 一致
    private let taskTitleSize: CGFloat = 16
    private let taskContentSize: CGFloat = 14
    private let taskHeaderSize: CGFloat = 17
    private let taskCountSize: CGFloat = 15

    // 檢查是否有任務更新
    private var hasTaskUpdates: Bool {
        !assistantViewModel.lastAddedTasks.isEmpty ||
        !assistantViewModel.lastDeletedTasks.isEmpty ||
        !assistantViewModel.lastUpdatedTasks.isEmpty ||
        assistantViewModel.updateError != nil
    }

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
            .padding(.horizontal)
            .padding(.top)
            .padding(.bottom, 4)
            .background(cardColor)
            .contentShape(Rectangle())
            .onTapGesture {
                // 點擊標題區域關閉鍵盤
                hideKeyboard()
            }

            // 輸入框區域（參考 ChatSettingView 的 TextField 樣式）
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("輸入日程安排")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.black)
                        .padding(.leading, 2)

                    Spacer()

                    // 注入預設文字2按鈕
                    Button(action: {
                        insertDefaultText2()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "text.badge.plus")
                                .font(.system(size: 14))
                            Text("自適應安排（調整時長）")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(accentColor)
                        .cornerRadius(6)
                    }
                    .disabled(assistantViewModel.isUpdating)
                    .opacity(assistantViewModel.isUpdating ? 0.5 : 1.0)

                    // 注入預設文字按鈕
                    Button(action: {
                        insertDefaultText()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "text.badge.plus")
                                .font(.system(size: 14))
                            Text("一般安排（不調整時長）")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(accentColor)
                        .cornerRadius(6)
                    }
                    .disabled(assistantViewModel.isUpdating)
                    .opacity(assistantViewModel.isUpdating ? 0.5 : 1.0)
                }

                ZStack(alignment: .topLeading) {
                    // 淡灰色背景的 TextEditor
                    TextEditor(text: $assistantViewModel.autoUpdateInput)
                        .font(.system(size: 16))
                        .lineSpacing(4)
                        .foregroundColor(.black)
                        .padding(.horizontal, 12)
                        .padding(.top, 6)
                        .padding(.bottom, 12)
                        .background(Color.gray.opacity(0.08))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.08), lineWidth: 1)
                        )
                        .frame(minHeight: 200)
                        .scrollContentBackground(.hidden)
                        .disabled(assistantViewModel.isUpdating)

                    // 占位符提示文字
                    if assistantViewModel.autoUpdateInput.isEmpty {
                        Text("可以輸入希望助手每日如何自動調整日曆")
                            .font(.system(size: 16))
                            .foregroundColor(.gray.opacity(0.6))
                            .padding(.horizontal, 16)
                            .padding(.top, 14)
                            .allowsHitTesting(false) // 允許點擊穿透
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom)
            .background(cardColor)

            // 每日自動更新 Toggle（參考 ChatSettingView 的 Toggle 樣式）
            VStack(alignment: .leading, spacing: 15) {
                Toggle(isOn: $assistantViewModel.autoUpdateEnabled) {
                    Text("每日自動更新")
                        .font(.system(size: 18))
                        .foregroundColor(.black)
                }
                .tint(accentColor)
                .disabled(assistantViewModel.isUpdating)
            }
            .padding(.horizontal)
            .padding(.vertical, 2)
            .background(cardColor)
            .contentShape(Rectangle())
            .onTapGesture {
                // 點擊 Toggle 區域關閉鍵盤（不影響 Toggle 本身的點擊）
                hideKeyboard()
            }

            // 任務卡片顯示區域 - 只在有內容時顯示
            if showTaskCards && hasTaskUpdates {
                ScrollView {
                    VStack(spacing: 12) {
                        // 新增任務區域 - 使用 lastAddedTasks 持久化顯示
                        if !assistantViewModel.lastAddedTasks.isEmpty {
                            taskSection(
                                title: "已新增的任務 (\(assistantViewModel.lastAddedTasks.count))",
                                sectionId: "added",
                                color: .green
                            ) {
                                let isExpanded = expandedSections.contains("added")
                                let displayTasks = isExpanded ? assistantViewModel.lastAddedTasks : Array(assistantViewModel.lastAddedTasks.prefix(1))

                                ForEach(displayTasks) { task in
                                    taskAddItemView(task: task)
                                }

                                if assistantViewModel.lastAddedTasks.count > 1 {
                                    expandButton(sectionId: "added", totalCount: assistantViewModel.lastAddedTasks.count)
                                }
                            }
                        }

                        // 刪除任務區域 - 使用 lastDeletedTasks 持久化顯示
                        if !assistantViewModel.lastDeletedTasks.isEmpty {
                            taskSection(
                                title: "已刪除的任務 (\(assistantViewModel.lastDeletedTasks.count))",
                                sectionId: "deleted",
                                color: .red
                            ) {
                                let isExpanded = expandedSections.contains("deleted")
                                let displayTasks = isExpanded ? assistantViewModel.lastDeletedTasks : Array(assistantViewModel.lastDeletedTasks.prefix(1))

                                ForEach(displayTasks) { task in
                                    taskDeleteItemView(task: task)
                                }

                                if assistantViewModel.lastDeletedTasks.count > 1 {
                                    expandButton(sectionId: "deleted", totalCount: assistantViewModel.lastDeletedTasks.count)
                                }
                            }
                        }

                        // 修改任務區域 - 使用 lastUpdatedTasks 持久化顯示
                        if !assistantViewModel.lastUpdatedTasks.isEmpty {
                            taskSection(
                                title: "已修改的任務 (\(assistantViewModel.lastUpdatedTasks.count))",
                                sectionId: "updated",
                                color: .blue
                            ) {
                                let isExpanded = expandedSections.contains("updated")
                                let displayTasks = isExpanded ? assistantViewModel.lastUpdatedTasks : Array(assistantViewModel.lastUpdatedTasks.prefix(1))

                                ForEach(0..<displayTasks.count, id: \.self) { index in
                                    taskUpdateItemView(updateData: displayTasks[index], index: index, total: assistantViewModel.lastUpdatedTasks.count)
                                }

                                if assistantViewModel.lastUpdatedTasks.count > 1 {
                                    expandButton(sectionId: "updated", totalCount: assistantViewModel.lastUpdatedTasks.count)
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

            // 立即更新與停止按鈕
            VStack(spacing: 10) {
                Button(action: {
                    guard !assistantViewModel.autoUpdateInput.isEmpty else { return }

                    Task {
                        expandedSections.removeAll()
                        await assistantViewModel.startUpdate(userInput: assistantViewModel.autoUpdateInput)
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
                    .background(assistantViewModel.isUpdating || assistantViewModel.autoUpdateInput.isEmpty ? accentColor.opacity(0.5) : accentColor)
                    .cornerRadius(12)
                    .shadow(color: accentColor.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                .disabled(assistantViewModel.isUpdating || assistantViewModel.autoUpdateInput.isEmpty)

                if assistantViewModel.isUpdating {
                    Button(action: {
                        assistantViewModel.cancelUpdate()
                    }) {
                        HStack {
                            Image(systemName: "stop.circle.fill")
                                .font(.system(size: 18, weight: .semibold))
                            Text("停止更新")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(Color.red.opacity(0.85))
                        .cornerRadius(12)
                        .shadow(color: Color.red.opacity(0.3), radius: 4, x: 0, y: 2)
                    }
                    .disabled(!assistantViewModel.isUpdating)
                }

                // 撤回按鈕 - 只有在沒有撤銷過且有任務更新時才顯示
                if !assistantViewModel.isUpdating && hasTaskUpdates && !assistantViewModel.hasUndone {
                    Button(action: {
                        Task {
                            await assistantViewModel.undoLastUpdate()
                        }
                    }) {
                        HStack {
                            Image(systemName: "arrow.uturn.backward.circle.fill")
                                .font(.system(size: 18, weight: .semibold))
                            Text("撤回上次更新")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(Color.orange.opacity(0.85))
                        .cornerRadius(12)
                        .shadow(color: Color.orange.opacity(0.3), radius: 4, x: 0, y: 2)
                    }
                }

                // 【新增】撤銷結果顯示區域 - 只顯示成功、部分成功或失敗的狀態
                if assistantViewModel.undoStatus == .success ||
                   assistantViewModel.undoStatus == .partialSuccess ||
                   assistantViewModel.undoStatus == .failed {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            // 根據狀態顯示不同的圖示和顏色
                            switch assistantViewModel.undoStatus {
                            case .success:
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.system(size: 20))

                            case .partialSuccess:
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                    .font(.system(size: 20))

                            case .failed:
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                    .font(.system(size: 20))

                            default:
                                EmptyView()
                            }

                            Text(assistantViewModel.undoMessage)
                                .font(.system(size: 14))
                                .foregroundColor(.black)
                                .fixedSize(horizontal: false, vertical: true)

                            Spacer()
                        }
                        .padding()
                        .background(
                            // 根據狀態顯示不同的背景顏色
                            Group {
                                switch assistantViewModel.undoStatus {
                                case .success:
                                    Color.green.opacity(0.1)
                                case .partialSuccess:
                                    Color.orange.opacity(0.1)
                                case .failed:
                                    Color.red.opacity(0.1)
                                default:
                                    Color.clear
                                }
                            }
                        )
                        .cornerRadius(8)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
            }
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
            // 如果有上一次的更新記錄，自動顯示任務卡片
            if hasTaskUpdates {
                showTaskCards = true
            }
        }
        .onChange(of: assistantViewModel.isUpdating) { newValue in
            // 當更新完成時（變為 false），顯示任務卡片
            if !newValue {
                showTaskCards = true
            }
        }
    }

    // MARK: - Keyboard Helper

    /// 隱藏鍵盤
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    // MARK: - Text Insertion Helper

    /// 注入預設文字
    private func insertDefaultText() {
        let defaultText = """
        檢查所有任務：
        1. 刪除：「已完成」且「已過期」的任務。
        2. 重新安排：「未完成」且「已過期」的任務，從今天起依序排入。
        3. 重新排程時：
        不可與其他任務重疊。
        時間須在合理範圍（08:00–22:00）。
        若當日時間不夠，自動順延至下一天。
        4. 保留原任務內容、優先級、預估時長，只調整日期與時間。
        5. 依優先級安排（高→中→低）：
            高：讀書任務
            中：運動與休息
            低：娛樂活動
        """
        assistantViewModel.autoUpdateInput = defaultText
    }

    /// 注入預設文字2（供「預設2」按鈕使用）
    private func insertDefaultText2() {
        let defaultText2 = """
        1. 已完成任務完全保留；
        2. 針對所有未完成子任務（不論原定時間在過去或未來），依依賴關係／截止日／工時估算，自『今天（Asia/Taipei）』起重新分配開始／結束時間與優先度，必要時自動順延避免衝突；
        3. 逾期任務自動移到最早可行時段並標記『延期重排』；
        4. 自動合併重複或等價子任務、補上合理工時與緩衝；
        5. 僅在需要時調整：狀態、開始時間、結束時間、優先度、所屬計畫、依賴；標題與備註若有助於清晰與可執行性可做必要更動；若不需要則維持不變（任務ID不可變更）；
        6. 維持行程無重疊，尊重我提供的工作時段／不可排時段與硬截止日；
        7. 無需向我確認，直接覆寫為最新排程；若仍有無法解的衝突，保留最佳可行解，並在受影響任務加上『需決策：原因』。
        """
        assistantViewModel.autoUpdateInput = defaultText2
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
