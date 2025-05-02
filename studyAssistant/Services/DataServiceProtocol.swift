import Foundation

enum DataServiceError: Error {
    case networkError
    case syncError
    case validationError
    case notFound
    case permissionDenied
    case unknown(String)
}

enum SyncStatus {
    case notSynced
    case syncing
    case synced
    case error(DataServiceError)
}

protocol DataServiceProtocol {
    // 使用者資料操作
    func fetchUserProfile() async throws -> UserProfile
    func updateUserProfile(_ profile: UserProfile) async throws
    
    // 應用程式設定操作
    func fetchAppSettings() async throws -> AppSettings
    func updateAppSettings(_ settings: AppSettings) async throws
    
    // 計時器記錄操作
    func saveTimerRecord(_ record: TimerRecord) async throws
    func getTimerRecords(userId: String) async throws -> [TimerRecord]
    func getTimerStatistics(userId: String) async throws -> TimerStatistics
    func getTimerStatistics(userId: String, from: Date, to: Date) async throws -> TimerStatistics
    
    // 同步狀態
    func syncStatus() -> SyncStatus
    func lastSyncTime() -> Date?
} 