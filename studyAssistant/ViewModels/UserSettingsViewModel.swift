import Foundation
import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore

@MainActor
class UserSettingsViewModel: ObservableObject {
    private let dataService: DataServiceProtocol
    
    // MARK: - Published Properties
    
    @Published var userProfile: UserProfile
    @Published var appSettings: AppSettings
    @Published var syncStatus: SyncStatus = .notSynced
    @Published var errorMessage: String?
    @Published var isLoading = false
    
    private var authStateListener: AuthStateDidChangeListenerHandle?
    private var profileListener: ListenerRegistration?
    
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
        
        setupAuthListener()
        setupProfileListener()
    }
    
    deinit {
        // 移除監聽器
        authStateListener.map { Auth.auth().removeStateDidChangeListener($0) }
        profileListener?.remove()
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
            errorMessage = nil
            
            // 發送使用者個人資料已更新通知
            NotificationCenter.default.post(name: .userProfileDidChange, object: nil)
        } catch {
            syncStatus = .error(.syncError)
            errorMessage = "無法儲存使用者資料：\(error.localizedDescription)"
        }
    }
    
    // MARK: - App Settings Methods
    
    func updateAppSettings(notificationsEnabled: Bool) async {
        var updatedSettings = appSettings
        updatedSettings.notificationsEnabled = notificationsEnabled
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
        // 重置用戶個人檔案和應用設定
        userProfile = UserProfile.defaultProfile()
        appSettings = AppSettings.defaultSettings()
        syncStatus = .notSynced
        errorMessage = nil
        
        // 清理本地計時記錄
        TimerRecordManager.shared.clearRecords()
        
        // 發送通知，告知系統用戶已登出，其他視圖模型需要清理資源
        NotificationCenter.default.post(name: .userDidLogout, object: nil)
        
        print("用戶設定資料已完全清理")
    }
    
    // MARK: - Auth Listener
    
    private func setupAuthListener() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] (auth: Auth, user: User?) in
            Task { @MainActor in
                if user != nil {
                    try? await self?.loadData()
                    self?.setupProfileListener()  // 用戶登入時設置監聽器
                } else {
                    self?.userProfile = UserProfile.defaultProfile()
                    self?.profileListener?.remove()  // 用戶登出時移除監聽器
                }
            }
        }
    }
    
    // MARK: - Profile Listener
    
    private func setupProfileListener() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        // 移除舊的監聽器
        profileListener?.remove()
        
        // 設置新的監聽器
        let firebaseService = self.dataService as? FirebaseService
        profileListener = firebaseService?.db.collection("profiles")
            .document(userId)
            .addSnapshotListener { [weak self] (snapshot: DocumentSnapshot?, error: Error?) in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error listening for profile updates: \(error)")
                    return
                }
                
                guard let snapshot = snapshot, snapshot.exists else { return }
                
                // 解析新的設定數據
                if let profile = UserProfile(documentId: snapshot.documentID, data: snapshot.data() ?? [:]) {
                    Task { @MainActor in
                        self.userProfile = profile
                        // 發送設定更新通知
                        NotificationCenter.default.post(name: .userProfileDidChange, object: nil)
                    }
                }
            }
    }
} 