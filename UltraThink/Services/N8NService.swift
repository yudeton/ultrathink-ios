import Foundation

class N8NService: ObservableObject {
    static let shared = N8NService()
    
    @Published var workflows: [N8NWorkflow] = []
    @Published var isExecuting = false
    
    private let apiService = APIService.shared
    
    private init() {}
    
    func triggerDailyWorkflow() async {
        guard !ConfigurationManager.shared.n8nWebhookURL.isEmpty else {
            print("N8N webhook URL not configured")
            return
        }
        
        await MainActor.run {
            isExecuting = true
        }
        
        do {
            let workflowData = WorkflowTriggerData(
                trigger: "daily_summary",
                timestamp: Date(),
                data: collectDailyData()
            )
            
            let success = try await executeWorkflow(data: workflowData)
            
            await MainActor.run {
                self.isExecuting = false
            }
            
            if success {
                print("Daily workflow executed successfully")
            }
            
        } catch {
            await MainActor.run {
                self.isExecuting = false
            }
            print("Error executing daily workflow: \(error)")
        }
    }
    
    func triggerGitCommitWorkflow(commits: [GitHubCommit]) async {
        guard !ConfigurationManager.shared.n8nWebhookURL.isEmpty else { return }
        
        do {
            let commitData = commits.map { commit in
                [
                    "sha": commit.sha ?? "",
                    "message": commit.commit?.message ?? "",
                    "author": commit.commit?.author?.name ?? "",
                    "date": commit.commit?.author?.date?.timeIntervalSince1970 ?? 0
                ]
            }
            
            let workflowData = WorkflowTriggerData(
                trigger: "git_commits",
                timestamp: Date(),
                data: ["commits": commitData]
            )
            
            let _ = try await executeWorkflow(data: workflowData)
            
        } catch {
            print("Error executing git commit workflow: \(error)")
        }
    }
    
    func triggerEmailWorkflow(emails: [GmailMessage]) async {
        guard !ConfigurationManager.shared.n8nWebhookURL.isEmpty else { return }
        
        do {
            let emailData = emails.map { email in
                [
                    "id": email.id,
                    "subject": email.getSubject() ?? "",
                    "from": email.getFrom() ?? "",
                    "snippet": email.snippet ?? "",
                    "date": email.getDate()?.timeIntervalSince1970 ?? 0
                ]
            }
            
            let workflowData = WorkflowTriggerData(
                trigger: "email_analysis",
                timestamp: Date(),
                data: ["emails": emailData]
            )
            
            let _ = try await executeWorkflow(data: workflowData)
            
        } catch {
            print("Error executing email workflow: \(error)")
        }
    }
    
    func triggerTaskUpdateWorkflow(task: TaskItem, action: String) async {
        guard !ConfigurationManager.shared.n8nWebhookURL.isEmpty else { return }
        
        do {
            let taskData = [
                "id": task.id.uuidString,
                "title": task.title,
                "category": task.category ?? "",
                "priority": task.priority.rawValue,
                "isCompleted": task.isCompleted,
                "action": action
            ] as [String : Any]
            
            let workflowData = WorkflowTriggerData(
                trigger: "task_update",
                timestamp: Date(),
                data: ["task": taskData]
            )
            
            let _ = try await executeWorkflow(data: workflowData)
            
        } catch {
            print("Error executing task workflow: \(error)")
        }
    }
    
    func triggerAttendanceWorkflow(record: AttendanceRecord, action: String) async {
        guard !ConfigurationManager.shared.n8nWebhookURL.isEmpty else { return }
        
        do {
            var attendanceData: [String: Any] = [
                "action": action,
                "date": record.date.timeIntervalSince1970,
                "isAutoClocked": record.isAutoClocked
            ]
            
            if let clockInTime = record.clockInTime {
                attendanceData["clockInTime"] = clockInTime.timeIntervalSince1970
            }
            
            if let clockOutTime = record.clockOutTime {
                attendanceData["clockOutTime"] = clockOutTime.timeIntervalSince1970
            }
            
            if let location = record.location {
                attendanceData["location"] = location
            }
            
            let workflowData = WorkflowTriggerData(
                trigger: "attendance_update",
                timestamp: Date(),
                data: ["attendance": attendanceData]
            )
            
            let _ = try await executeWorkflow(data: workflowData)
            
        } catch {
            print("Error executing attendance workflow: \(error)")
        }
    }
    
    private func executeWorkflow(data: WorkflowTriggerData) async throws -> Bool {
        guard let url = URL(string: ConfigurationManager.shared.n8nWebhookURL) else {
            throw APIError.invalidURL
        }
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let bodyData = try encoder.encode(data)
        
        let response: N8NResponse = try await apiService.makeRequest(
            url: url,
            method: .POST,
            body: bodyData,
            responseType: N8NResponse.self
        )
        
        return response.success ?? true
    }
    
    private func collectDailyData() -> [String: Any] {
        var data: [String: Any] = [:]
        
        // Git data
        let gitCommits = GitHubService.shared.commits
        data["git"] = [
            "commitCount": gitCommits.count,
            "commits": gitCommits.map { commit in
                [
                    "sha": commit.sha ?? "",
                    "message": commit.commit?.message ?? "",
                    "author": commit.commit?.author?.name ?? ""
                ]
            }
        ]
        
        // Email data
        let emails = GmailService.shared.emails
        data["email"] = [
            "totalCount": emails.count,
            "importantCount": emails.filter { $0.isImportant() }.count
        ]
        
        // Task data
        let completedToday = TaskManagerService.shared.getCompletedTasksToday()
        data["tasks"] = [
            "completedToday": completedToday.count,
            "totalPending": TaskManagerService.shared.tasks.filter { !$0.isCompleted }.count
        ]
        
        // Obsidian data
        let obsidianNotes = ObsidianService.shared.todayNotes
        data["obsidian"] = [
            "notesModified": obsidianNotes.count
        ]
        
        // Attendance data
        if let attendance = AttendanceService.shared.todayAttendance {
            data["attendance"] = [
                "clockedIn": attendance.clockInTime != nil,
                "clockedOut": attendance.clockOutTime != nil,
                "isAutoClocked": attendance.isAutoClocked
            ]
        }
        
        return data
    }
    
    func setupAutomationSchedule() {
        // Setup daily triggers at specific times
        scheduleWorkflowTrigger(at: "09:00", workflow: "morning_summary")
        scheduleWorkflowTrigger(at: "18:00", workflow: "evening_summary")
        scheduleWorkflowTrigger(at: "23:00", workflow: "daily_wrap_up")
    }
    
    private func scheduleWorkflowTrigger(at time: String, workflow: String) {
        // Here you would implement local notification scheduling or background task
        // to trigger workflows at specific times
        print("Scheduled workflow '\(workflow)' at \(time)")
    }
    
    func createCustomWorkflow(_ workflow: N8NWorkflow) async -> Bool {
        // This would integrate with N8N API to create custom workflows
        // For now, we'll just store it locally
        workflows.append(workflow)
        return true
    }
    
    func getWorkflowStatus() async -> [String: Any] {
        // This would query N8N for workflow execution status
        return [
            "activeWorkflows": workflows.count,
            "lastExecution": Date().timeIntervalSince1970,
            "status": "running"
        ]
    }
}

struct WorkflowTriggerData: Codable {
    let trigger: String
    let timestamp: Date
    let data: [String: Any]
    
    enum CodingKeys: String, CodingKey {
        case trigger, timestamp, data
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(trigger, forKey: .trigger)
        try container.encode(timestamp, forKey: .timestamp)
        
        // Convert [String: Any] to JSON
        let jsonData = try JSONSerialization.data(withJSONObject: data)
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            try container.encode(jsonString, forKey: .data)
        }
    }
}

struct N8NResponse: Codable {
    let success: Bool?
    let message: String?
    let executionId: String?
    
    enum CodingKeys: String, CodingKey {
        case success, message
        case executionId = "execution_id"
    }
}

struct N8NWorkflow: Identifiable, Codable {
    let id = UUID()
    let name: String
    let description: String
    let triggerType: WorkflowTriggerType
    let schedule: String? // Cron expression
    let enabled: Bool
    let nodes: [WorkflowNode]
}

enum WorkflowTriggerType: String, Codable, CaseIterable {
    case manual = "manual"
    case scheduled = "scheduled"
    case webhook = "webhook"
    case event = "event"
    
    var displayName: String {
        switch self {
        case .manual: return "手動觸發"
        case .scheduled: return "定時觸發"
        case .webhook: return "Webhook觸發"
        case .event: return "事件觸發"
        }
    }
}

struct WorkflowNode: Codable {
    let id: String
    let name: String
    let type: String
    let parameters: [String: Any]
    
    enum CodingKeys: String, CodingKey {
        case id, name, type, parameters
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
        
        let jsonData = try JSONSerialization.data(withJSONObject: parameters)
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            try container.encode(jsonString, forKey: .parameters)
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(String.self, forKey: .type)
        
        let jsonString = try container.decode(String.self, forKey: .parameters)
        if let jsonData = jsonString.data(using: .utf8),
           let params = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
            parameters = params
        } else {
            parameters = [:]
        }
    }
    
    init(id: String, name: String, type: String, parameters: [String: Any]) {
        self.id = id
        self.name = name
        self.type = type
        self.parameters = parameters
    }
}