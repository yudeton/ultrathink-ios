import SwiftUI

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
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
                        value: "0",
                        icon: "arrow.up.circle.fill",
                        color: .blue
                    )
                    
                    DashboardCard(
                        title: "待辦事項",
                        value: "0",
                        icon: "checkmark.circle.fill",
                        color: .green
                    )
                    
                    DashboardCard(
                        title: "郵件摘要",
                        value: "0",
                        icon: "envelope.fill",
                        color: .orange
                    )
                    
                    DashboardCard(
                        title: "筆記同步",
                        value: "同步中",
                        icon: "doc.text.fill",
                        color: .purple
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
        }
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
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(height: 80)
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
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
    var body: some View {
        Text("Git活動視圖")
            .navigationTitle("Git活動")
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

struct SettingsView: View {
    var body: some View {
        Text("設置視圖")
            .navigationTitle("設置")
    }
}

#Preview {
    ContentView()
}