import SwiftUI
import Firebase
import FirebaseAuth

@MainActor
class ProfileViewModel: ObservableObject {
    private let firebaseService = FirebaseService.shared
    @Published private(set) var profile: UserProfile?
    
    func loadProfile() async throws -> UserProfile? {
        // 從 FirebaseService 獲取當前用戶的 profile
        profile = try await firebaseService.fetchUserProfile()
        return profile
    }
    
    func saveProfile(username: String, userGoal: String, targetDate: Date, learningStage: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "ProfileViewModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "沒有登入的用戶"])
        }
        
        // 使用當前的 profile 作為基礎，或創建新的 profile
        let currentProfile = profile ?? UserProfile.defaultProfile()
        
        // 更新 profile 資料
        var updatedProfile = currentProfile
        updatedProfile.id = userId
        updatedProfile.username = username
        updatedProfile.userGoal = userGoal
        updatedProfile.targetDate = targetDate
        updatedProfile.learningStage = learningStage
        
        try await firebaseService.updateUserProfile(updatedProfile)
        profile = updatedProfile
    }
    
    func clearAllData() {
        // 登出時清除本地資料
        profile = nil
        // 如果需要，這裡可以添加其他清理操作
    }
}
 