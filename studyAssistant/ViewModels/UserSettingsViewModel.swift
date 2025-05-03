import Foundation
import SwiftUI
import Firebase

@MainActor
class UserSettingsViewModel: ObservableObject {
    private let dataService: DataServiceProtocol
    
    // MARK: - Published Properties
    
    @Published var userProfile: UserProfile
    @Published var appSettings: AppSettings
    @Published var syncStatus: SyncStatus = .notSynced
    @Published var errorMessage: String?
    
    // MARK: - Initialization
    
    init(dataService: DataServiceProtocol = FirebaseService.shared) {
        self.dataService = dataService
        
        // 初始化預設值
        self.userProfile = UserProfile.defaultProfile()
        self.appSettings = AppSettings.defaultSettings()
        
        // 載入資料
        Task {
            await loadData()
        }
    }
    
    // MARK: - Data Loading
    
    func loadData() async {
        do {
            async let profile = dataService.fetchUserProfile()
            async let settings = dataService.fetchAppSettings()
            
            let (profileResult, settingsResult) = await (try profile, try settings)
            
            self.userProfile = profileResult
            self.appSettings = settingsResult
            
            self.syncStatus = .synced
        } catch {
            self.syncStatus = .error(.syncError)
            self.errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - User Profile Methods
    
    func updateUserProfile(username: String, motivationalQuote: String, targetDate: Date, learningStage: String) async {
        var updatedProfile = userProfile
        updatedProfile.username = username
        updatedProfile.motivationalQuote = motivationalQuote
        updatedProfile.targetDate = targetDate
        updatedProfile.learningStage = learningStage
        updatedProfile.version += 1
        
        do {
            try await dataService.updateUserProfile(updatedProfile)
            userProfile = updatedProfile
            syncStatus = .synced
        } catch {
            syncStatus = .error(.syncError)
            errorMessage = "無法儲存使用者資料：\(error.localizedDescription)"
        }
    }
    
    // MARK: - App Settings Methods
    
    func updateAppSettings(isDarkMode: Bool, notificationsEnabled: Bool, isShockEnabled: Bool) async {
        var updatedSettings = appSettings
        updatedSettings.isDarkMode = isDarkMode
        updatedSettings.notificationsEnabled = notificationsEnabled
        updatedSettings.isShockEnabled = isShockEnabled
        updatedSettings.lastModified = Date()
        
        do {
            try await dataService.updateAppSettings(updatedSettings)
            appSettings = updatedSettings
            syncStatus = .synced
        } catch {
            syncStatus = .error(.syncError)
            errorMessage = "無法儲存應用程式設定：\(error.localizedDescription)"
        }
    }
    
    // MARK: - Helper Methods
    
    func clearAllData() {
        userProfile = UserProfile.defaultProfile()
        appSettings = AppSettings.defaultSettings()
        syncStatus = .notSynced
    }
} 