import Foundation
import Combine

class TaskManagerService: ObservableObject {
    static let shared = TaskManagerService()
    
    @Published var tasks: [TaskItem] = []
    @Published var upcomingDeadlines: [TaskItem] = []
    @Published var isLoading = false
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        loadTasks()
        setupDeadlineMonitoring()
    }
    
    func loadTasks() {
        // Load from UserDefaults for now (later can be integrated with Core Data)
        if let data = UserDefaults.standard.data(forKey: "saved_tasks"),
           let decodedTasks = try? JSONDecoder().decode([TaskItem].self, from: data) {
            tasks = decodedTasks
        }
        updateUpcomingDeadlines()
    }
    
    func saveTasks() {
        if let encoded = try? JSONEncoder().encode(tasks) {
            UserDefaults.standard.set(encoded, forKey: "saved_tasks")
        }
        updateUpcomingDeadlines()
    }
    
    func addTask(_ task: TaskItem) {
        tasks.append(task)
        saveTasks()
    }
    
    func updateTask(_ task: TaskItem) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = task
            saveTasks()
        }
    }
    
    func deleteTask(_ task: TaskItem) {
        tasks.removeAll { $0.id == task.id }
        saveTasks()
    }
    
    func toggleTaskCompletion(_ task: TaskItem) {
        var updatedTask = task
        updatedTask.isCompleted = !task.isCompleted
        updatedTask.completedAt = updatedTask.isCompleted ? Date() : nil
        updateTask(updatedTask)
    }
    
    private func setupDeadlineMonitoring() {
        Timer.publish(every: 3600, on: .main, in: .common) // Check every hour
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateUpcomingDeadlines()
                self?.checkDeadlineNotifications()
            }
            .store(in: &cancellables)
    }
    
    private func updateUpcomingDeadlines() {
        let now = Date()
        let oneWeekFromNow = Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now
        
        upcomingDeadlines = tasks.filter { task in
            guard let deadline = task.deadline, !task.isCompleted else { return false }
            return deadline >= now && deadline <= oneWeekFromNow
        }.sorted { $0.deadline! < $1.deadline! }
    }
    
    private func checkDeadlineNotifications() {
        let now = Date()
        let calendar = Calendar.current
        
        for task in tasks {
            guard let deadline = task.deadline, !task.isCompleted else { continue }
            
            let timeUntilDeadline = deadline.timeIntervalSince(now)
            let hoursUntilDeadline = timeUntilDeadline / 3600
            
            // Notify if deadline is within 24 hours
            if hoursUntilDeadline > 0 && hoursUntilDeadline <= 24 && !task.notificationSent {
                scheduleDeadlineNotification(for: task)
                var updatedTask = task
                updatedTask.notificationSent = true
                updateTask(updatedTask)
            }
        }
    }
    
    private func scheduleDeadlineNotification(for task: TaskItem) {
        // Here you would implement local notification scheduling
        print("Scheduling notification for task: \(task.title)")
    }
    
    func getTasksByPriority() -> [String: [TaskItem]] {
        let incompleteTasks = tasks.filter { !$0.isCompleted }
        return Dictionary(grouping: incompleteTasks) { task in
            switch task.priority {
            case .high:
                return "高優先級"
            case .medium:
                return "中優先級"
            case .low:
                return "低優先級"
            }
        }
    }
    
    func getTasksByCategory() -> [String: [TaskItem]] {
        let incompleteTasks = tasks.filter { !$0.isCompleted }
        return Dictionary(grouping: incompleteTasks) { $0.category ?? "未分類" }
    }
    
    func getCompletedTasksToday() -> [TaskItem] {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? Date()
        
        return tasks.filter { task in
            guard let completedAt = task.completedAt else { return false }
            return completedAt >= today && completedAt < tomorrow
        }
    }
    
    func generateTaskSummary() -> String {
        let totalTasks = tasks.count
        let completedTasks = tasks.filter { $0.isCompleted }.count
        let pendingTasks = totalTasks - completedTasks
        let overdueTasks = tasks.filter { task in
            guard let deadline = task.deadline, !task.isCompleted else { return false }
            return deadline < Date()
        }.count
        
        var summary = "任務管理摘要:\n"
        summary += "總任務數: \(totalTasks)\n"
        summary += "已完成: \(completedTasks)\n"
        summary += "待處理: \(pendingTasks)\n"
        summary += "逾期任務: \(overdueTasks)\n\n"
        
        if !upcomingDeadlines.isEmpty {
            summary += "即將到期:\n"
            for task in upcomingDeadlines.prefix(5) {
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                formatter.timeStyle = .short
                summary += "• \(task.title) - \(formatter.string(from: task.deadline!))\n"
            }
        }
        
        return summary
    }
    
    // Integration with external task systems
    func syncWithTrello(apiKey: String, token: String) async {
        // Implement Trello API integration
    }
    
    func syncWithTodoist(apiToken: String) async {
        // Implement Todoist API integration
    }
    
    func importFromCalendar() async {
        // Import events from iOS Calendar as tasks
    }
}

struct TaskItem: Identifiable, Codable {
    let id = UUID()
    var title: String
    var description: String?
    var category: String?
    var priority: TaskPriority
    var deadline: Date?
    var isCompleted: Bool = false
    var completedAt: Date?
    var createdAt: Date = Date()
    var tags: [String] = []
    var estimatedDuration: TimeInterval? // in seconds
    var actualDuration: TimeInterval?
    var notificationSent: Bool = false
    
    var isOverdue: Bool {
        guard let deadline = deadline, !isCompleted else { return false }
        return deadline < Date()
    }
    
    var daysUntilDeadline: Int? {
        guard let deadline = deadline else { return nil }
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: Date(), to: deadline).day
        return days
    }
}

enum TaskPriority: String, CaseIterable, Codable {
    case high = "high"
    case medium = "medium"
    case low = "low"
    
    var displayName: String {
        switch self {
        case .high: return "高"
        case .medium: return "中"
        case .low: return "低"
        }
    }
    
    var color: String {
        switch self {
        case .high: return "red"
        case .medium: return "orange"
        case .low: return "green"
        }
    }
}