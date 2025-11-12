//
//  NotificationManager.swift
//  studyAssistant
//
//  通知管理器 - 負責管理所有本地推送通知
//

import Foundation
import UserNotifications
import SwiftUI

@MainActor
class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()

    @Published var isAuthorized = false
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined

    // 全域通知設定（分鐘）
    var globalNotificationOffsetMinutes: Int = 10  // 預設值，會在 app 啟動時更新

    private let notificationCenter = UNUserNotificationCenter.current()

    private override init() {
        super.init()
        Task {
            await checkAuthorizationStatus()
        }
    }

    // MARK: - 權限管理

    /// 請求通知權限
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            await checkAuthorizationStatus()
            return granted
        } catch {
            print("請求通知權限失敗: \(error)")
            return false
        }
    }

    /// 檢查當前權限狀態
    func checkAuthorizationStatus() async {
        let settings = await notificationCenter.notificationSettings()
        authorizationStatus = settings.authorizationStatus
        isAuthorized = settings.authorizationStatus == .authorized

        print("通知權限狀態: \(authorizationStatus.rawValue)")
    }

    /// 打開系統設定頁面
    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
        }
    }

    // MARK: - 通知排程

    /// 為任務排程通知（使用全域設定）
    func scheduleNotification(for task: TodoTask) async {
        // 檢查權限
        guard isAuthorized else {
            print("⚠️ 無通知權限，跳過排程")
            return
        }

        // 檢查任務是否啟用通知
        guard task.notificationEnabled else {
            print("⚠️ 任務未啟用通知: \(task.title)")
            return
        }

        // 先取消舊通知（如果存在）
        await cancelNotification(for: task.id)

        // 使用全域提前提醒時間
        let offsetMinutes = globalNotificationOffsetMinutes

        // 根據重複類型排程
        switch task.repeatType {
        case .none:
            await scheduleOneTimeNotification(for: task, offsetMinutes: offsetMinutes)
        case .daily:
            await scheduleRepeatingNotifications(for: task, repeatType: .daily, offsetMinutes: offsetMinutes)
        case .weekly:
            await scheduleRepeatingNotifications(for: task, repeatType: .weekly, offsetMinutes: offsetMinutes)
        case .monthly:
            await scheduleRepeatingNotifications(for: task, repeatType: .monthly, offsetMinutes: offsetMinutes)
        }
    }

    /// 排程單次通知
    private func scheduleOneTimeNotification(for task: TodoTask, offsetMinutes: Int) async {
        let notificationDate = calculateNotificationDate(
            startDate: task.startDate,
            offsetMinutes: offsetMinutes
        )

        // 檢查時間是否已過
        guard notificationDate > Date() else {
            return
        }

        let content = createNotificationContent(for: task, offsetMinutes: offsetMinutes)
        let trigger = createTrigger(for: notificationDate)

        let identifier = task.id
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await notificationCenter.add(request)
        } catch {
            print("❌ 排程通知失敗: \(error)")
        }
    }

    /// 排程重複任務的通知
    private func scheduleRepeatingNotifications(for task: TodoTask, repeatType: RepeatType, offsetMinutes: Int) async {
        let calendar = Calendar.current
        var scheduledCount = 0

        // 檢查64個通知限制
        let pendingNotifications = await notificationCenter.pendingNotificationRequests()
        let availableSlots = 64 - pendingNotifications.count

        guard availableSlots > 0 else {
            return
        }

        let maxNotifications: Int
        switch repeatType {
        case .daily:
            maxNotifications = min(7, availableSlots)  // 排程7天
        case .weekly:
            maxNotifications = min(4, availableSlots)  // 排程4週
        case .monthly:
            maxNotifications = min(3, availableSlots)  // 排程3個月
        default:
            maxNotifications = 1
        }

        for index in 0..<maxNotifications {
            var notificationDate: Date?

            switch repeatType {
            case .daily:
                notificationDate = calendar.date(byAdding: .day, value: index, to: task.startDate)
            case .weekly:
                notificationDate = calendar.date(byAdding: .weekOfYear, value: index, to: task.startDate)
            case .monthly:
                notificationDate = calendar.date(byAdding: .month, value: index, to: task.startDate)
            default:
                break
            }

            guard let date = notificationDate else { continue }

            // 檢查是否超過重複結束日期
            if let repeatEndDate = task.repeatEndDate,
               date > repeatEndDate {
                break
            }

            let finalDate = calculateNotificationDate(
                startDate: date,
                offsetMinutes: offsetMinutes
            )

            // 跳過已過期的通知
            guard finalDate > Date() else { continue }

            let content = createNotificationContent(for: task, offsetMinutes: offsetMinutes)
            let trigger = createTrigger(for: finalDate)

            // 為重複任務的每個實例建立唯一 ID
            let identifier = "\(task.id)_\(index)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

            do {
                try await notificationCenter.add(request)
                scheduledCount += 1
            } catch {
                print("❌ 排程重複通知失敗: \(error)")
            }
        }
    }

    /// 建立通知內容
    private func createNotificationContent(for task: TodoTask, offsetMinutes: Int) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.sound = .default
        content.badge = 1

        // 時間格式化器
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM/dd"

        // 標題：任務標題 + 時間
        if task.isAllDay {
            // 全天任務
            content.title = "\(task.title)  全天"
        } else {
            // 有具體時間的任務
            let startTime = timeFormatter.string(from: task.startDate)
            let endTime = timeFormatter.string(from: task.endDate)

            // 檢查是否跨日
            let calendar = Calendar.current
            if calendar.isDate(task.startDate, inSameDayAs: task.endDate) {
                // 同一天：複習微積分  14:00 - 16:00
                content.title = "\(task.title)  \(startTime) - \(endTime)"
            } else {
                // 跨日：複習微積分  11/12 14:00 - 11/13 16:00
                let startDateStr = dateFormatter.string(from: task.startDate)
                let endDateStr = dateFormatter.string(from: task.endDate)
                content.title = "\(task.title)  \(startDateStr) \(startTime) - \(endDateStr) \(endTime)"
            }
        }

        // 內文：備註（如果有）
        if !task.note.isEmpty {
            content.body = task.note
        } else {
            content.body = " "  // 至少需要一個空格
        }

        // 設定類別（用於動作按鈕）
        content.categoryIdentifier = "TASK_REMINDER"

        // 加入任務 ID 到 userInfo（用於點擊後跳轉）
        content.userInfo = ["taskId": task.id]

        return content
    }

    /// 建立通知觸發器
    private func createTrigger(for date: Date) -> UNCalendarNotificationTrigger {
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: date
        )
        return UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
    }

    /// 計算通知時間（考慮提前提醒）
    private func calculateNotificationDate(startDate: Date, offsetMinutes: Int) -> Date {
        let offsetSeconds = TimeInterval(offsetMinutes * 60)
        return startDate.addingTimeInterval(-offsetSeconds)
    }

    // MARK: - 取消通知

    /// 取消指定任務的通知
    func cancelNotification(for taskId: String) async {
        // 取消單次通知
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [taskId])

        // 取消重複通知（可能有多個）
        let pendingNotifications = await notificationCenter.pendingNotificationRequests()
        let repeatIdentifiers = pendingNotifications
            .map { $0.identifier }
            .filter { $0.hasPrefix("\(taskId)_") }

        if !repeatIdentifiers.isEmpty {
            notificationCenter.removePendingNotificationRequests(withIdentifiers: repeatIdentifiers)
            print("✅ 已取消 \(repeatIdentifiers.count + 1) 個通知")
        } else {
            print("✅ 已取消通知: \(taskId)")
        }
    }

    /// 取消所有通知
    func cancelAllNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
        print("✅ 已取消所有待處理通知")
    }

    /// 取消已送達的通知
    func removeDeliveredNotifications() {
        notificationCenter.removeAllDeliveredNotifications()
    }

    // MARK: - 查詢通知

    /// 取得待處理的通知數量
    func getPendingNotificationsCount() async -> Int {
        let notifications = await notificationCenter.pendingNotificationRequests()
        return notifications.count
    }

    /// 取得待處理的通知清單
    func getPendingNotifications() async -> [UNNotificationRequest] {
        return await notificationCenter.pendingNotificationRequests()
    }

    /// 取得指定任務的通知
    func getNotifications(for taskId: String) async -> [UNNotificationRequest] {
        let allNotifications = await notificationCenter.pendingNotificationRequests()
        return allNotifications.filter { request in
            request.identifier == taskId || request.identifier.hasPrefix("\(taskId)_")
        }
    }

    // MARK: - 通知限制管理

    /// 管理64個通知限制
    func manageNotificationLimit() async {
        let pending = await notificationCenter.pendingNotificationRequests()

        guard pending.count >= 60 else {
            print("✅ 通知數量正常: \(pending.count)/64")
            return
        }

        print("⚠️ 通知接近上限: \(pending.count)/64，開始清理...")

        // 找出7天後的通知
        let sevenDaysLater = Date().addingTimeInterval(7 * 24 * 60 * 60)
        var oldNotifications: [String] = []

        for request in pending {
            if let trigger = request.trigger as? UNCalendarNotificationTrigger,
               let nextTriggerDate = trigger.nextTriggerDate(),
               nextTriggerDate > sevenDaysLater {
                oldNotifications.append(request.identifier)
            }
        }

        if !oldNotifications.isEmpty {
            notificationCenter.removePendingNotificationRequests(withIdentifiers: oldNotifications)
            print("✅ 已清理 \(oldNotifications.count) 個7天後的通知")
        }
    }

    // MARK: - 通知動作設定

    /// 註冊通知動作按鈕
    func registerNotificationCategories() {
        let completeAction = UNNotificationAction(
            identifier: "COMPLETE_ACTION",
            title: "標記完成",
            options: [.foreground]
        )

        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE_ACTION",
            title: "稍後提醒",
            options: []
        )

        let category = UNNotificationCategory(
            identifier: "TASK_REMINDER",
            actions: [completeAction, snoozeAction],
            intentIdentifiers: [],
            options: .customDismissAction
        )

        notificationCenter.setNotificationCategories([category])
        print("✅ 已註冊通知動作類別")
    }
}
