//
//  StudySettings.swift
//  studyAssistant
//
//  Created by 李翊辰 on 2025/5/10.
//

import FirebaseFirestore
import Foundation

// MARK: - 讀書設定資料模型
struct StudySettings: Codable {
    var id: String?
    var userId: String
    var studyDuration: Double = 60  // 預設讀書時間60分鐘
    var selectedDays: [Int] = [1, 2, 3, 4, 5]  // 預設週一至週五
    var dailyStartHours: [String: Int] = [:]  // 每天的開始時間 (小時)
    var dailyStartMinutes: [String: Int] = [:]  // 每天的開始時間 (分鐘)
    var dailyEndHours: [String: Int] = [:]  // 每天的結束時間 (小時)
    var dailyEndMinutes: [String: Int] = [:]  // 每天的結束時間 (分鐘)
    var tone: String = "沉著穩重的專家"  // 預設語氣
    var isStudyDatePreferenceEnabled: Bool = true // 新增：控制讀書日期/時段偏好
    var isStudyTimePreferenceEnabled: Bool = true // 新增：控制每次讀書時長偏好
    var updatedAt: Timestamp

    init(userId: String) {
        self.userId = userId
        self.updatedAt = Timestamp()
        // isStudyDatePreferenceEnabled 和 isStudyTimePreferenceEnabled 使用預設值 true

        // 初始化每天的預設開始和結束時間
        for day in 1...7 {
            let dayString = String(day)
            dailyStartHours[dayString] = 9  // 預設上午9點開始
            dailyStartMinutes[dayString] = 0
            dailyEndHours[dayString] = 17  // 預設下午5點結束
            dailyEndMinutes[dayString] = 0
        }
    }

    // 從 Firestore 文檔創建
    init?(document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }

        self.id = document.documentID
        self.userId = data["userId"] as? String ?? ""
        self.studyDuration = data["studyDuration"] as? Double ?? 60
        self.selectedDays = data["selectedDays"] as? [Int] ?? [1, 2, 3, 4, 5]
        self.dailyStartHours = data["dailyStartHours"] as? [String: Int] ?? [:]
        self.dailyStartMinutes = data["dailyStartMinutes"] as? [String: Int] ?? [:]
        self.dailyEndHours = data["dailyEndHours"] as? [String: Int] ?? [:]
        self.dailyEndMinutes = data["dailyEndMinutes"] as? [String: Int] ?? [:]
        self.tone = data["tone"] as? String ?? "沉著穩重的專家"
        self.isStudyDatePreferenceEnabled = data["isStudyDatePreferenceEnabled"] as? Bool ?? true
        self.isStudyTimePreferenceEnabled = data["isStudyTimePreferenceEnabled"] as? Bool ?? true
        self.updatedAt = data["updatedAt"] as? Timestamp ?? Timestamp()
    }

    // 轉換為 Firestore 數據
    func toFirestoreData() -> [String: Any] {
        return [
            "userId": userId,
            "studyDuration": studyDuration,
            "selectedDays": selectedDays,
            "dailyStartHours": dailyStartHours,
            "dailyStartMinutes": dailyStartMinutes,
            "dailyEndHours": dailyEndHours,
            "dailyEndMinutes": dailyEndMinutes,
            "tone": tone,
            "isStudyDatePreferenceEnabled": isStudyDatePreferenceEnabled,
            "isStudyTimePreferenceEnabled": isStudyTimePreferenceEnabled,
            "updatedAt": updatedAt,
        ]
    }

    // 取得特定星期的開始時間
    func getStartTimeForDay(_ day: Int) -> Date {
        let dayString = String(day)
        let hour = dailyStartHours[dayString] ?? 9
        let minute = dailyStartMinutes[dayString] ?? 0
        return createDate(hour: hour, minute: minute)
    }

    // 取得特定星期的結束時間
    func getEndTimeForDay(_ day: Int) -> Date {
        let dayString = String(day)
        let hour = dailyEndHours[dayString] ?? 17
        let minute = dailyEndMinutes[dayString] ?? 0
        return createDate(hour: hour, minute: minute)
    }

    // 設定特定星期的開始時間
    mutating func setStartTimeForDay(_ day: Int, date: Date) {
        let dayString = String(day)
        let calendar = Calendar.current
        dailyStartHours[dayString] = calendar.component(.hour, from: date)
        dailyStartMinutes[dayString] = calendar.component(.minute, from: date)
    }

    // 設定特定星期的結束時間
    mutating func setEndTimeForDay(_ day: Int, date: Date) {
        let dayString = String(day)
        let calendar = Calendar.current
        dailyEndHours[dayString] = calendar.component(.hour, from: date)
        dailyEndMinutes[dayString] = calendar.component(.minute, from: date)
    }

    // 創建日期
    private func createDate(hour: Int, minute: Int) -> Date {
        return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date())
            ?? Date()
    }
}
