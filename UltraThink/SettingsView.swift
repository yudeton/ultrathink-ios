import SwiftUI

struct SettingsView: View {
    @ObservedObject private var configManager = ConfigurationManager.shared
    @State private var showingAPITest = false
    @State private var testResults: [String: Bool] = [:]
    @State private var showingSecureFields = Set<String>()
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("GitHub 設置")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("用戶名")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("GitHub用戶名", text: $configManager.githubUsername)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Personal Access Token")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button(action: {
                                toggleSecureField("github")
                            }) {
                                Image(systemName: showingSecureFields.contains("github") ? "eye.slash" : "eye")
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        if showingSecureFields.contains("github") {
                            TextField("GitHub Token", text: $configManager.githubToken)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        } else {
                            SecureField("GitHub Token", text: $configManager.githubToken)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                    }
                    
                    HStack {
                        Button("測試連接") {
                            testGitHubConnection()
                        }
                        .disabled(configManager.githubToken.isEmpty || configManager.githubUsername.isEmpty)
                        
                        Spacer()
                        
                        if let result = testResults["github"] {
                            Image(systemName: result ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(result ? .green : .red)
                        }
                    }
                }
                
                Section(header: Text("Gmail 設置")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Client ID")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Gmail Client ID", text: Binding(
                            get: { configManager.gmailCredentials?.clientId ?? "" },
                            set: { newValue in
                                if configManager.gmailCredentials != nil {
                                    configManager.gmailCredentials?.clientId = newValue
                                } else {
                                    configManager.gmailCredentials = GmailCredentials(
                                        accessToken: "",
                                        refreshToken: "",
                                        clientId: newValue,
                                        clientSecret: ""
                                    )
                                }
                            }
                        ))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Client Secret")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button(action: {
                                toggleSecureField("gmail")
                            }) {
                                Image(systemName: showingSecureFields.contains("gmail") ? "eye.slash" : "eye")
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        if showingSecureFields.contains("gmail") {
                            TextField("Gmail Client Secret", text: Binding(
                                get: { configManager.gmailCredentials?.clientSecret ?? "" },
                                set: { newValue in
                                    if configManager.gmailCredentials != nil {
                                        configManager.gmailCredentials?.clientSecret = newValue
                                    }
                                }
                            ))
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        } else {
                            SecureField("Gmail Client Secret", text: Binding(
                                get: { configManager.gmailCredentials?.clientSecret ?? "" },
                                set: { newValue in
                                    if configManager.gmailCredentials != nil {
                                        configManager.gmailCredentials?.clientSecret = newValue
                                    }
                                }
                            ))
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                    }
                    
                    Button("OAuth 授權設置") {
                        // TODO: Implement OAuth flow
                    }
                    .foregroundColor(.blue)
                }
                
                Section(header: Text("Obsidian 設置")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Vault 路徑")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Obsidian Vault路徑", text: $configManager.obsidianVaultPath)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    HStack {
                        Button("測試連接") {
                            testObsidianConnection()
                        }
                        .disabled(configManager.obsidianVaultPath.isEmpty)
                        
                        Spacer()
                        
                        if let result = testResults["obsidian"] {
                            Image(systemName: result ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(result ? .green : .red)
                        }
                    }
                }
                
                Section(header: Text("OpenAI 設置")) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("API Key")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button(action: {
                                toggleSecureField("openai")
                            }) {
                                Image(systemName: showingSecureFields.contains("openai") ? "eye.slash" : "eye")
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        if showingSecureFields.contains("openai") {
                            TextField("OpenAI API Key", text: $configManager.openAIAPIKey)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        } else {
                            SecureField("OpenAI API Key", text: $configManager.openAIAPIKey)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                    }
                    
                    HStack {
                        Button("測試連接") {
                            testOpenAIConnection()
                        }
                        .disabled(configManager.openAIAPIKey.isEmpty)
                        
                        Spacer()
                        
                        if let result = testResults["openai"] {
                            Image(systemName: result ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(result ? .green : .red)
                        }
                    }
                }
                
                Section(header: Text("自動打卡設置")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("考勤系統URL")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("考勤系統URL", text: $configManager.attendanceSystemURL)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("用戶名")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("考勤用戶名", text: Binding(
                            get: { configManager.attendanceCredentials?.username ?? "" },
                            set: { newValue in
                                if configManager.attendanceCredentials != nil {
                                    configManager.attendanceCredentials?.username = newValue
                                } else {
                                    configManager.attendanceCredentials = AttendanceCredentials(
                                        username: newValue,
                                        password: "",
                                        employeeId: nil,
                                        additionalParams: nil
                                    )
                                }
                            }
                        ))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    NavigationLink(destination: LocationSettingsView()) {
                        Label("辦公室位置設置", systemImage: "location")
                    }
                    
                    NavigationLink(destination: AttendanceHistoryView()) {
                        Label("打卡記錄", systemImage: "clock")
                    }
                }
                
                Section(header: Text("N8N 工作流")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Webhook URL")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("N8N Webhook URL", text: $configManager.n8nWebhookURL)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    HStack {
                        Button("測試Webhook") {
                            testN8NConnection()
                        }
                        .disabled(configManager.n8nWebhookURL.isEmpty)
                        
                        Spacer()
                        
                        if let result = testResults["n8n"] {
                            Image(systemName: result ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(result ? .green : .red)
                        }
                    }
                }
                
                Section(header: Text("操作")) {
                    Button("保存設置") {
                        configManager.saveConfiguration()
                    }
                    .foregroundColor(.blue)
                    
                    Button("重置所有設置") {
                        showingResetAlert = true
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("設置")
            .navigationBarTitleDisplayMode(.inline)
            .alert("重置設置", isPresented: $showingResetAlert) {
                Button("取消", role: .cancel) { }
                Button("重置", role: .destructive) {
                    resetAllSettings()
                }
            } message: {
                Text("這將清除所有API密鑰和配置。此操作無法撤銷。")
            }
        }
    }
    
    @State private var showingResetAlert = false
    
    private func toggleSecureField(_ field: String) {
        if showingSecureFields.contains(field) {
            showingSecureFields.remove(field)
        } else {
            showingSecureFields.insert(field)
        }
    }
    
    private func testGitHubConnection() {
        Task {
            await GitHubService.shared.fetchTodayCommits(
                username: configManager.githubUsername,
                token: configManager.githubToken
            )
            
            await MainActor.run {
                testResults["github"] = !GitHubService.shared.commits.isEmpty || !GitHubService.shared.isLoading
            }
        }
    }
    
    private func testObsidianConnection() {
        Task {
            await ObsidianService.shared.fetchTodayNotes()
            
            await MainActor.run {
                testResults["obsidian"] = !ObsidianService.shared.isLoading
            }
        }
    }
    
    private func testOpenAIConnection() {
        Task {
            do {
                await AIAnalysisService.shared.generateInsights()
                await MainActor.run {
                    testResults["openai"] = !AIAnalysisService.shared.isGenerating
                }
            }
        }
    }
    
    private func testN8NConnection() {
        Task {
            await N8NService.shared.triggerDailyWorkflow()
            
            await MainActor.run {
                testResults["n8n"] = !N8NService.shared.isExecuting
            }
        }
    }
    
    private func resetAllSettings() {
        configManager.githubToken = ""
        configManager.githubUsername = ""
        configManager.gmailCredentials = nil
        configManager.obsidianVaultPath = ""
        configManager.attendanceSystemURL = ""
        configManager.attendanceCredentials = nil
        configManager.openAIAPIKey = ""
        configManager.n8nWebhookURL = ""
        configManager.saveConfiguration()
        testResults.removeAll()
    }
}

struct LocationSettingsView: View {
    @State private var officeLatitude: String = ""
    @State private var officeLongitude: String = ""
    @State private var isPickingLocation = false
    
    var body: some View {
        Form {
            Section(header: Text("辦公室位置")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("緯度")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("緯度", text: $officeLatitude)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.decimalPad)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("經度")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("經度", text: $officeLongitude)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.decimalPad)
                }
                
                Button("使用當前位置") {
                    // TODO: Implement current location detection
                }
                .foregroundColor(.blue)
                
                Button("地圖選擇位置") {
                    isPickingLocation = true
                }
                .foregroundColor(.blue)
            }
            
            Section(header: Text("地理圍欄設置")) {
                HStack {
                    Text("觸發半徑")
                    Spacer()
                    Text("100 公尺")
                        .foregroundColor(.secondary)
                }
                
                Toggle("啟用自動打卡", isOn: .constant(false))
            }
        }
        .navigationTitle("位置設置")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AttendanceHistoryView: View {
    var body: some View {
        List {
            ForEach(0..<10, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("2024年1月15日")
                            .font(.headline)
                        Spacer()
                        Text("自動打卡")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(4)
                    }
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("上班")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("09:00")
                                .font(.body)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("下班")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("18:00")
                                .font(.body)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("打卡記錄")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    SettingsView()
}