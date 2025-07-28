import Foundation

class ConfigurationManager: ObservableObject {
    static let shared = ConfigurationManager()
    
    @Published var githubToken: String = ""
    @Published var githubUsername: String = ""
    @Published var gmailCredentials: GmailCredentials?
    @Published var obsidianVaultPath: String = ""
    @Published var attendanceSystemURL: String = ""
    @Published var attendanceCredentials: AttendanceCredentials?
    @Published var openAIAPIKey: String = ""
    @Published var n8nWebhookURL: String = ""
    
    private let userDefaults = UserDefaults.standard
    
    private init() {
        loadConfiguration()
    }
    
    func loadConfiguration() {
        githubToken = userDefaults.string(forKey: "github_token") ?? ""
        githubUsername = userDefaults.string(forKey: "github_username") ?? ""
        obsidianVaultPath = userDefaults.string(forKey: "obsidian_vault_path") ?? ""
        attendanceSystemURL = userDefaults.string(forKey: "attendance_system_url") ?? ""
        openAIAPIKey = userDefaults.string(forKey: "openai_api_key") ?? ""
        n8nWebhookURL = userDefaults.string(forKey: "n8n_webhook_url") ?? ""
        
        if let gmailData = userDefaults.data(forKey: "gmail_credentials") {
            gmailCredentials = try? JSONDecoder().decode(GmailCredentials.self, from: gmailData)
        }
        
        if let attendanceData = userDefaults.data(forKey: "attendance_credentials") {
            attendanceCredentials = try? JSONDecoder().decode(AttendanceCredentials.self, from: attendanceData)
        }
    }
    
    func saveConfiguration() {
        userDefaults.set(githubToken, forKey: "github_token")
        userDefaults.set(githubUsername, forKey: "github_username")
        userDefaults.set(obsidianVaultPath, forKey: "obsidian_vault_path")
        userDefaults.set(attendanceSystemURL, forKey: "attendance_system_url")
        userDefaults.set(openAIAPIKey, forKey: "openai_api_key")
        userDefaults.set(n8nWebhookURL, forKey: "n8n_webhook_url")
        
        if let gmailCredentials = gmailCredentials {
            if let data = try? JSONEncoder().encode(gmailCredentials) {
                userDefaults.set(data, forKey: "gmail_credentials")
            }
        }
        
        if let attendanceCredentials = attendanceCredentials {
            if let data = try? JSONEncoder().encode(attendanceCredentials) {
                userDefaults.set(data, forKey: "attendance_credentials")
            }
        }
    }
    
    func isGitHubConfigured() -> Bool {
        return !githubToken.isEmpty && !githubUsername.isEmpty
    }
    
    func isGmailConfigured() -> Bool {
        return gmailCredentials != nil
    }
    
    func isObsidianConfigured() -> Bool {
        return !obsidianVaultPath.isEmpty
    }
    
    func isAttendanceConfigured() -> Bool {
        return !attendanceSystemURL.isEmpty && attendanceCredentials != nil
    }
    
    func isOpenAIConfigured() -> Bool {
        return !openAIAPIKey.isEmpty
    }
}

struct GmailCredentials: Codable {
    let accessToken: String
    let refreshToken: String
    let clientId: String
    let clientSecret: String
    var expiresAt: Date?
}

struct AttendanceCredentials: Codable {
    let username: String
    let password: String
    let employeeId: String?
    let additionalParams: [String: String]?
}