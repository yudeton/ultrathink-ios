import Foundation

class AIAnalysisService: ObservableObject {
    static let shared = AIAnalysisService()
    
    @Published var isGenerating = false
    @Published var generatedJournal: String = ""
    @Published var analysisInsights: [String] = []
    
    private let apiService = APIService.shared
    private let openAIBaseURL = "https://api.openai.com/v1"
    
    private init() {}
    
    func generateWorkJournal() async {
        await MainActor.run {
            isGenerating = true
        }
        
        do {
            // Collect data from all services
            let gitSummary = GitHubService.shared.generateCommitSummary()
            let emailSummary = GmailService.shared.emailSummary
            let taskSummary = TaskManagerService.shared.generateTaskSummary()
            let obsidianSummary = ObsidianService.shared.generateNoteSummary()
            let attendanceInfo = getAttendanceInfo()
            
            let combinedData = """
            今日工作數據整理:
            
            Git活動:
            \(gitSummary)
            
            郵件摘要:
            \(emailSummary)
            
            任務管理:
            \(taskSummary)
            
            筆記摘要:
            \(obsidianSummary)
            
            出勤記錄:
            \(attendanceInfo)
            """
            
            let journal = try await generateJournalWithAI(data: combinedData)
            
            await MainActor.run {
                self.generatedJournal = journal
                self.isGenerating = false
            }
            
            // Save to Obsidian if configured
            if ObsidianService.shared.todayNotes.count > 0 {
                let success = await ObsidianService.shared.createDailyNote(content: journal)
                if success {
                    print("Journal saved to Obsidian successfully")
                }
            }
            
        } catch {
            await MainActor.run {
                self.isGenerating = false
            }
            print("Error generating work journal: \(error)")
        }
    }
    
    private func generateJournalWithAI(data: String) async throws -> String {
        guard !ConfigurationManager.shared.openAIAPIKey.isEmpty else {
            throw APIError.invalidResponse
        }
        
        let prompt = """
        請基於以下工作數據，生成一份專業且有洞察力的工作日誌。請包含：
        1. 今日工作重點摘要
        2. 主要成就和進展
        3. 遇到的挑戰和解決方案
        4. 明日計劃建議
        5. 個人反思和改進點
        
        請用繁體中文撰寫，語調要專業但不失個人色彩。
        
        工作數據：
        \(data)
        """
        
        guard let url = URL(string: "\(openAIBaseURL)/chat/completions") else {
            throw APIError.invalidURL
        }
        
        let headers = [
            "Authorization": "Bearer \(ConfigurationManager.shared.openAIAPIKey)",
            "Content-Type": "application/json"
        ]
        
        let requestBody: [String: Any] = [
            "model": "gpt-4",
            "messages": [
                [
                    "role": "system",
                    "content": "你是一個專業的工作日誌助手，擅長將工作數據整理成有條理、有洞察力的日誌內容。"
                ],
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "max_tokens": 2000,
            "temperature": 0.7
        ]
        
        let bodyData = try JSONSerialization.data(withJSONObject: requestBody)
        
        let response: OpenAIResponse = try await apiService.makeRequest(
            url: url,
            method: .POST,
            headers: headers,
            body: bodyData,
            responseType: OpenAIResponse.self
        )
        
        return response.choices.first?.message.content ?? "無法生成工作日誌"
    }
    
    func generateInsights() async {
        await MainActor.run {
            isGenerating = true
        }
        
        do {
            let insights = try await analyzeWorkPatterns()
            
            await MainActor.run {
                self.analysisInsights = insights
                self.isGenerating = false
            }
            
        } catch {
            await MainActor.run {
                self.isGenerating = false
            }
            print("Error generating insights: \(error)")
        }
    }
    
    private func analyzeWorkPatterns() async throws -> [String] {
        let recentTasks = TaskManagerService.shared.tasks.suffix(50)
        let recentCommits = GitHubService.shared.commits
        let recentEmails = GmailService.shared.emails.suffix(20)
        
        let analysisData = """
        分析以下工作模式數據：
        
        近期任務：\(recentTasks.count)個
        完成率：\(calculateCompletionRate(tasks: Array(recentTasks)))%
        
        今日代碼提交：\(recentCommits.count)次
        
        今日郵件：\(recentEmails.count)封
        """
        
        let prompt = """
        基於以下工作數據，請提供3-5個具體的工作效率改進建議。
        建議應該具體、可執行，並以繁體中文回答。
        每個建議用一行表示，以"• "開頭。
        
        \(analysisData)
        """
        
        guard let url = URL(string: "\(openAIBaseURL)/chat/completions") else {
            throw APIError.invalidURL
        }
        
        let headers = [
            "Authorization": "Bearer \(ConfigurationManager.shared.openAIAPIKey)",
            "Content-Type": "application/json"
        ]
        
        let requestBody: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": [
                [
                    "role": "system",
                    "content": "你是一個工作效率分析專家，專門提供具體可行的改進建議。"
                ],
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "max_tokens": 800,
            "temperature": 0.8
        ]
        
        let bodyData = try JSONSerialization.data(withJSONObject: requestBody)
        
        let response: OpenAIResponse = try await apiService.makeRequest(
            url: url,
            method: .POST,
            headers: headers,
            body: bodyData,
            responseType: OpenAIResponse.self
        )
        
        let content = response.choices.first?.message.content ?? ""
        return content.components(separatedBy: "\n").filter { $0.hasPrefix("• ") }
    }
    
    private func calculateCompletionRate(tasks: [TaskItem]) -> Int {
        guard !tasks.isEmpty else { return 0 }
        let completedCount = tasks.filter { $0.isCompleted }.count
        return Int((Double(completedCount) / Double(tasks.count)) * 100)
    }
    
    private func getAttendanceInfo() -> String {
        if let attendance = AttendanceService.shared.todayAttendance {
            var info = "今日出勤："
            
            if let clockIn = attendance.clockInTime {
                let formatter = DateFormatter()
                formatter.timeStyle = .short
                info += " 上班：\(formatter.string(from: clockIn))"
            }
            
            if let clockOut = attendance.clockOutTime {
                let formatter = DateFormatter()
                formatter.timeStyle = .short
                info += " 下班：\(formatter.string(from: clockOut))"
            }
            
            if attendance.isAutoClocked {
                info += " (自動打卡)"
            }
            
            return info
        } else {
            return "今日出勤：無記錄"
        }
    }
    
    func generateMeetingSummary(transcript: String) async -> String? {
        do {
            let prompt = """
            請將以下會議記錄整理成結構化的會議摘要，包含：
            1. 會議主要議題
            2. 重要決議
            3. 行動項目
            4. 下次會議要點
            
            會議記錄：
            \(transcript)
            """
            
            guard let url = URL(string: "\(openAIBaseURL)/chat/completions") else {
                return nil
            }
            
            let headers = [
                "Authorization": "Bearer \(ConfigurationManager.shared.openAIAPIKey)",
                "Content-Type": "application/json"
            ]
            
            let requestBody: [String: Any] = [
                "model": "gpt-3.5-turbo",
                "messages": [
                    [
                        "role": "system",
                        "content": "你是專業的會議記錄整理助手。"
                    ],
                    [
                        "role": "user",
                        "content": prompt
                    ]
                ],
                "max_tokens": 1000,
                "temperature": 0.5
            ]
            
            let bodyData = try JSONSerialization.data(withJSONObject: requestBody)
            
            let response: OpenAIResponse = try await apiService.makeRequest(
                url: url,
                method: .POST,
                headers: headers,
                body: bodyData,
                responseType: OpenAIResponse.self
            )
            
            return response.choices.first?.message.content
            
        } catch {
            print("Error generating meeting summary: \(error)")
            return nil
        }
    }
}

struct OpenAIResponse: Codable {
    let choices: [OpenAIChoice]
}

struct OpenAIChoice: Codable {
    let message: OpenAIMessage
}

struct OpenAIMessage: Codable {
    let content: String
}