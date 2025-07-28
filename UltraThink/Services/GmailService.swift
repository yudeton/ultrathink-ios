import Foundation

class GmailService: ObservableObject {
    static let shared = GmailService()
    
    @Published var emails: [GmailMessage] = []
    @Published var isLoading = false
    @Published var emailSummary: String = ""
    
    private let apiService = APIService.shared
    private let baseURL = "https://www.googleapis.com/gmail/v1"
    
    private init() {}
    
    func fetchTodayEmails() async {
        guard let credentials = ConfigurationManager.shared.gmailCredentials else {
            print("Gmail credentials not configured")
            return
        }
        
        await MainActor.run {
            isLoading = true
        }
        
        do {
            let validToken = try await ensureValidAccessToken(credentials: credentials)
            
            let today = Calendar.current.startOfDay(for: Date())
            let todayTimestamp = Int(today.timeIntervalSince1970)
            
            let query = "after:\(todayTimestamp)"
            
            guard let url = URL(string: "\(baseURL)/users/me/messages?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") else {
                throw APIError.invalidURL
            }
            
            let headers = [
                "Authorization": "Bearer \(validToken)"
            ]
            
            let response: GmailMessageListResponse = try await apiService.makeRequest(
                url: url,
                headers: headers,
                responseType: GmailMessageListResponse.self
            )
            
            var detailedMessages: [GmailMessage] = []
            
            for messageInfo in response.messages ?? [] {
                if let messageDetail = await fetchMessageDetail(messageId: messageInfo.id, accessToken: validToken) {
                    detailedMessages.append(messageDetail)
                }
            }
            
            await MainActor.run {
                self.emails = detailedMessages
                self.isLoading = false
                self.generateEmailSummary()
            }
            
        } catch {
            await MainActor.run {
                self.isLoading = false
            }
            print("Error fetching emails: \(error)")
        }
    }
    
    private func fetchMessageDetail(messageId: String, accessToken: String) async -> GmailMessage? {
        do {
            guard let url = URL(string: "\(baseURL)/users/me/messages/\(messageId)") else {
                return nil
            }
            
            let headers = [
                "Authorization": "Bearer \(accessToken)"
            ]
            
            let message: GmailMessage = try await apiService.makeRequest(
                url: url,
                headers: headers,
                responseType: GmailMessage.self
            )
            
            return message
            
        } catch {
            print("Error fetching message detail: \(error)")
            return nil
        }
    }
    
    private func ensureValidAccessToken(credentials: GmailCredentials) async throws -> String {
        if let expiresAt = credentials.expiresAt, expiresAt > Date() {
            return credentials.accessToken
        }
        
        return try await refreshAccessToken(credentials: credentials)
    }
    
    private func refreshAccessToken(credentials: GmailCredentials) async throws -> String {
        guard let url = URL(string: "https://oauth2.googleapis.com/token") else {
            throw APIError.invalidURL
        }
        
        let body = [
            "client_id": credentials.clientId,
            "client_secret": credentials.clientSecret,
            "refresh_token": credentials.refreshToken,
            "grant_type": "refresh_token"
        ]
        
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        
        let response: TokenRefreshResponse = try await apiService.makeRequest(
            url: url,
            method: .POST,
            body: bodyData,
            responseType: TokenRefreshResponse.self
        )
        
        var updatedCredentials = credentials
        updatedCredentials.accessToken = response.accessToken
        updatedCredentials.expiresAt = Date().addingTimeInterval(TimeInterval(response.expiresIn))
        
        await MainActor.run {
            ConfigurationManager.shared.gmailCredentials = updatedCredentials
            ConfigurationManager.shared.saveConfiguration()
        }
        
        return response.accessToken
    }
    
    private func generateEmailSummary() {
        let totalEmails = emails.count
        let senders = Set(emails.compactMap { $0.getFrom() })
        let importantEmails = emails.filter { $0.isImportant() }
        
        var summary = "今日郵件摘要:\n"
        summary += "總郵件數: \(totalEmails)\n"
        summary += "重要郵件: \(importantEmails.count)\n"
        summary += "主要發件人: \(senders.prefix(5).joined(separator: ", "))\n\n"
        
        summary += "重要郵件詳情:\n"
        for email in importantEmails.prefix(10) {
            summary += "• 從 \(email.getFrom() ?? "Unknown") : \(email.getSubject() ?? "No Subject")\n"
        }
        
        emailSummary = summary
    }
}

struct GmailMessageListResponse: Codable {
    let messages: [GmailMessageInfo]?
    let nextPageToken: String?
    let resultSizeEstimate: Int?
}

struct GmailMessageInfo: Codable {
    let id: String
    let threadId: String
}

struct GmailMessage: Codable, Identifiable {
    let id: String
    let threadId: String
    let labelIds: [String]?
    let snippet: String?
    let payload: GmailMessagePayload?
    let internalDate: String?
    
    func getSubject() -> String? {
        return payload?.headers?.first { $0.name.lowercased() == "subject" }?.value
    }
    
    func getFrom() -> String? {
        return payload?.headers?.first { $0.name.lowercased() == "from" }?.value
    }
    
    func getDate() -> Date? {
        guard let internalDate = internalDate,
              let timestamp = TimeInterval(internalDate) else {
            return nil
        }
        return Date(timeIntervalSince1970: timestamp / 1000)
    }
    
    func isImportant() -> Bool {
        guard let labelIds = labelIds else { return false }
        return labelIds.contains("IMPORTANT") || labelIds.contains("CATEGORY_PRIMARY")
    }
}

struct GmailMessagePayload: Codable {
    let headers: [GmailHeader]?
    let body: GmailMessageBody?
}

struct GmailHeader: Codable {
    let name: String
    let value: String
}

struct GmailMessageBody: Codable {
    let size: Int?
    let data: String?
}

struct TokenRefreshResponse: Codable {
    let accessToken: String
    let expiresIn: Int
    let tokenType: String?
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
    }
}