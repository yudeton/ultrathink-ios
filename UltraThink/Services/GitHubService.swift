import Foundation

class GitHubService: ObservableObject {
    static let shared = GitHubService()
    
    @Published var commits: [GitHubCommit] = []
    @Published var isLoading = false
    
    private let apiService = APIService.shared
    private let baseURL = "https://api.github.com"
    
    private init() {}
    
    func fetchTodayCommits(username: String, token: String) async {
        await MainActor.run {
            isLoading = true
        }
        
        do {
            let today = Calendar.current.startOfDay(for: Date())
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
            
            let dateFormatter = ISO8601DateFormatter()
            let sinceDate = dateFormatter.string(from: today)
            let untilDate = dateFormatter.string(from: tomorrow)
            
            guard let url = URL(string: "\(baseURL)/search/commits?q=author:\(username)+committer-date:\(sinceDate)..\(untilDate)") else {
                throw APIError.invalidURL
            }
            
            let headers = [
                "Authorization": "token \(token)",
                "Accept": "application/vnd.github.cloak-preview+json"
            ]
            
            let response: GitHubCommitSearchResponse = try await apiService.makeRequest(
                url: url,
                headers: headers,
                responseType: GitHubCommitSearchResponse.self
            )
            
            await MainActor.run {
                self.commits = response.items
                self.isLoading = false
            }
            
        } catch {
            await MainActor.run {
                self.isLoading = false
            }
            print("Error fetching commits: \(error)")
        }
    }
    
    func fetchRepositoryCommits(owner: String, repo: String, token: String) async -> [GitHubCommit] {
        do {
            let today = Calendar.current.startOfDay(for: Date())
            let dateFormatter = ISO8601DateFormatter()
            let sinceDate = dateFormatter.string(from: today)
            
            guard let url = URL(string: "\(baseURL)/repos/\(owner)/\(repo)/commits?since=\(sinceDate)") else {
                throw APIError.invalidURL
            }
            
            let headers = [
                "Authorization": "token \(token)"
            ]
            
            let commits: [GitHubCommit] = try await apiService.makeRequest(
                url: url,
                headers: headers,
                responseType: [GitHubCommit].self
            )
            
            return commits
            
        } catch {
            print("Error fetching repository commits: \(error)")
            return []
        }
    }
    
    func generateCommitSummary() -> String {
        let totalCommits = commits.count
        let repositories = Set(commits.map { $0.repository ?? "Unknown" })
        
        var summary = "今日Git活動摘要:\n"
        summary += "總提交次數: \(totalCommits)\n"
        summary += "涉及倉庫: \(repositories.joined(separator: ", "))\n\n"
        
        summary += "提交詳情:\n"
        for commit in commits {
            let shortHash = String(commit.sha?.prefix(7) ?? "unknown")
            summary += "• [\(shortHash)] \(commit.commit?.message ?? "No message")\n"
        }
        
        return summary
    }
}

struct GitHubCommitSearchResponse: Codable {
    let totalCount: Int
    let incompleteResults: Bool
    let items: [GitHubCommit]
    
    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case incompleteResults = "incomplete_results"
        case items
    }
}

struct GitHubCommit: Codable, Identifiable {
    let id = UUID()
    let sha: String?
    let commit: GitHubCommitDetail?
    let repository: String?
    
    enum CodingKeys: String, CodingKey {
        case sha, commit, repository
    }
}

struct GitHubCommitDetail: Codable {
    let message: String?
    let author: GitHubCommitAuthor?
    let committer: GitHubCommitAuthor?
}

struct GitHubCommitAuthor: Codable {
    let name: String?
    let email: String?
    let date: Date?
}