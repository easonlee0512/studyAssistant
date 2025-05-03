//
//  NotificationConstants.swift
//  studyAssistant
//
//  Created on 2025/5/4.
//

import Foundation

// 定義通知名稱常數
extension Notification.Name {
    static let todoDataDidChange = Notification.Name("todoDataDidChange")
    static let userAuthDidChange = Notification.Name("userAuthDidChange")
    static let userProfileDidChange = Notification.Name("userProfileDidChange")
    
    // 可以在這裡添加其他通知名稱
} 