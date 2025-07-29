import SwiftUI

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject private var githubService = GitHubService.shared
    @ObservedObject private var gmailService = GmailService.shared
    @ObservedObject private var taskManager = TaskManagerService.shared
    @ObservedObject private var obsidianService = ObsidianService.shared
    @ObservedObject private var attendanceService = AttendanceService.shared
    @ObservedObject private var configManager = ConfigurationManager.shared
    
    @State private var isRefreshing = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                HeaderView()
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    DashboardCard(
                        title: "今日提交",
                        value: githubService.isLoading ? "載入中..." : "\(githubService.commits.count)",
                        icon: "arrow.up.circle.fill",
                        color: .blue,
                        isLoading: githubService.isLoading
                    )
                    
                    DashboardCard(
                        title: "待辦事項",
                        value: "\(taskManager.tasks.filter { !$0.isCompleted }.count)",
                        icon: "checkmark.circle.fill",
                        color: .green,
                        isLoading: false
                    )
                    
                    DashboardCard(
                        title: "郵件摘要",
                        value: gmailService.isLoading ? "載入中..." : "\(gmailService.emails.count)",
                        icon: "envelope.fill",
                        color: .orange,
                        isLoading: gmailService.isLoading
                    )
                    
                    DashboardCard(
                        title: "筆記同步",
                        value: obsidianService.isLoading ? "載入中..." : "\(obsidianService.todayNotes.count)",
                        icon: "doc.text.fill",
                        color: .purple,
                        isLoading: obsidianService.isLoading
                    )
                }
                .padding(.horizontal)
                
                Spacer()
                
                VStack(spacing: 12) {
                    NavigationLink(destination: GitCommitView()) {
                        ActionButton(title: "查看Git活動", icon: "square.and.arrow.up")
                    }
                    
                    NavigationLink(destination: TaskManagerView()) {
                        ActionButton(title: "任務管理", icon: "list.bullet")
                    }
                    
                    NavigationLink(destination: WorkJournalView()) {
                        ActionButton(title: "生成工作日誌", icon: "doc.richtext")
                    }
                    
                    NavigationLink(destination: SettingsView()) {
                        ActionButton(title: "設置", icon: "gear")
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("UltraThink")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await refreshAllData()
            }
            .onAppear {
                Task {
                    await loadInitialData()
                }
            }
        }
    }
    
    private func loadInitialData() async {
        if configManager.isGitHubConfigured() {
            await githubService.fetchTodayCommits(
                username: configManager.githubUsername,
                token: configManager.githubToken
            )
        }
        
        if configManager.isGmailConfigured() {
            await gmailService.fetchTodayEmails()
        }
        
        if configManager.isObsidianConfigured() {
            await obsidianService.fetchTodayNotes()
        }
        
        taskManager.loadTasks()
    }
    
    private func refreshAllData() async {
        isRefreshing = true
        await loadInitialData()
        isRefreshing = false
    }
}

struct HeaderView: View {
    var body: some View {
        VStack {
            Text("今日工作摘要")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(Date().formatted(date: .abbreviated, time: .omitted))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.top)
    }
}

struct DashboardCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let isLoading: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            if isLoading {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
            }
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(height: 80)
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
        .animation(.easeInOut(duration: 0.3), value: isLoading)
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
            
            Text(title)
                .font(.body)
                .fontWeight(.medium)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
        .foregroundColor(.primary)
    }
}

struct GitCommitView: View {
    @ObservedObject private var githubService = GitHubService.shared
    @ObservedObject private var configManager = ConfigurationManager.shared
    @State private var selectedTimeRange = 0
    private let timeRanges = ["今日", "本週", "本月"]
    
    var body: some View {
        VStack(spacing: 0) {
            // Time Range Picker
            Picker("時間範圍", selection: $selectedTimeRange) {
                ForEach(0..<timeRanges.count, id: \.self) { index in
                    Text(timeRanges[index]).tag(index)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            if !configManager.isGitHubConfigured() {
                VStack(spacing: 16) {
                    Image(systemName: "gear")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    
                    Text("請先配置GitHub設置")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Button("前往設置") {
                        // TODO: Navigate to settings
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if githubService.isLoading {
                VStack {
                    ProgressView("載入中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else if githubService.commits.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    
                    Text("今日還沒有提交記錄")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Button("刷新") {
                        Task {
                            await refreshCommits()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    Section(header: HStack {
                        Text("提交記錄 (\(githubService.commits.count))")
                        Spacer()
                        Button("刷新") {
                            Task {
                                await refreshCommits()
                            }
                        }
                        .font(.caption)
                    }) {
                        ForEach(githubService.commits) { commit in
                            CommitRowView(commit: commit)
                        }
                    }
                    
                    Section(header: Text("統計資訊")) {
                        StatRowView(
                            title: "總提交數",
                            value: "\(githubService.commits.count)",
                            icon: "arrow.up.circle"
                        )
                        
                        StatRowView(
                            title: "最後提交時間",
                            value: lastCommitTime,
                            icon: "clock"
                        )
                        
                        StatRowView(
                            title: "涉及倉庫",
                            value: "\(uniqueRepositories.count)",
                            icon: "folder"
                        )
                    }
                }
            }
        }
        .navigationTitle("Git活動")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await refreshCommits()
        }
        .onAppear {
            Task {
                if configManager.isGitHubConfigured() {
                    await refreshCommits()
                }
            }
        }
    }
    
    private var lastCommitTime: String {
        guard let lastCommit = githubService.commits.first,
              let date = lastCommit.commit?.author?.date else {
            return "無"
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private var uniqueRepositories: Set<String> {
        Set(githubService.commits.compactMap { $0.repository })
    }
    
    private func refreshCommits() async {
        await githubService.fetchTodayCommits(
            username: configManager.githubUsername,
            token: configManager.githubToken
        )
    }
}

struct CommitRowView: View {
    let commit: GitHubCommit
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(commit.commit?.message ?? "No message")
                        .font(.headline)
                        .lineLimit(2)
                    
                    if let author = commit.commit?.author?.name {
                        Text("by \(author)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(commitTime)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let sha = commit.sha {
                        Text(String(sha.prefix(7)))
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
            }
            
            if let repository = commit.repository {
                HStack {
                    Image(systemName: "folder")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text(repository)
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private var commitTime: String {
        guard let date = commit.commit?.author?.date else { return "Unknown" }
        
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct StatRowView: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(title)
                .font(.body)
            
            Spacer()
            
            Text(value)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
        .padding(.vertical, 2)
    }
}

struct TaskManagerView: View {
    var body: some View {
        Text("任務管理視圖")
            .navigationTitle("任務管理")
    }
}

struct WorkJournalView: View {
    var body: some View {
        Text("工作日誌視圖")
            .navigationTitle("工作日誌")
    }
}


#Preview {
    ContentView()
}