import Foundation

class ObsidianService: ObservableObject {
    static let shared = ObsidianService()
    
    @Published var notes: [ObsidianNote] = []
    @Published var todayNotes: [ObsidianNote] = []
    @Published var isLoading = false
    
    private let apiService = APIService.shared
    private var obsidianRestAPIURL: String {
        return "http://localhost:27123" // Default Obsidian REST API plugin port
    }
    
    private init() {}
    
    func fetchTodayNotes() async {
        await MainActor.run {
            isLoading = true
        }
        
        do {
            let today = Calendar.current.startOfDay(for: Date())
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let todayString = dateFormatter.string(from: today)
            
            // Fetch notes modified today
            let allNotes = try await fetchAllNotes()
            let todaysNotes = allNotes.filter { note in
                guard let modifiedDate = note.stat?.mtime else { return false }
                let noteDate = Date(timeIntervalSince1970: modifiedDate / 1000)
                return Calendar.current.isDate(noteDate, inSameDayAs: today)
            }
            
            await MainActor.run {
                self.todayNotes = todaysNotes
                self.isLoading = false
            }
            
        } catch {
            await MainActor.run {
                self.isLoading = false
            }
            print("Error fetching today's notes: \(error)")
        }
    }
    
    func fetchAllNotes() async throws -> [ObsidianNote] {
        guard let url = URL(string: "\(obsidianRestAPIURL)/vault/") else {
            throw APIError.invalidURL
        }
        
        let response: ObsidianVaultResponse = try await apiService.makeRequest(
            url: url,
            responseType: ObsidianVaultResponse.self
        )
        
        return response.files.compactMap { file in
            guard file.path.hasSuffix(".md") else { return nil }
            return ObsidianNote(
                path: file.path,
                name: file.name,
                stat: file.stat,
                content: nil
            )
        }
    }
    
    func fetchNoteContent(path: String) async -> String? {
        do {
            let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
            guard let url = URL(string: "\(obsidianRestAPIURL)/vault/\(encodedPath)") else {
                return nil
            }
            
            let response: ObsidianNoteContent = try await apiService.makeRequest(
                url: url,
                responseType: ObsidianNoteContent.self
            )
            
            return response.content
            
        } catch {
            print("Error fetching note content: \(error)")
            return nil
        }
    }
    
    func createDailyNote(content: String) async -> Bool {
        do {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let today = dateFormatter.string(from: Date())
            let notePath = "Daily Notes/\(today).md"
            
            let encodedPath = notePath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? notePath
            guard let url = URL(string: "\(obsidianRestAPIURL)/vault/\(encodedPath)") else {
                return false
            }
            
            let body = ["content": content]
            let bodyData = try JSONSerialization.data(withJSONObject: body)
            
            let _: ObsidianResponse = try await apiService.makeRequest(
                url: url,
                method: .PUT,
                body: bodyData,
                responseType: ObsidianResponse.self
            )
            
            return true
            
        } catch {
            print("Error creating daily note: \(error)")
            return false
        }
    }
    
    func appendToNote(path: String, content: String) async -> Bool {
        do {
            // First, fetch existing content
            let existingContent = await fetchNoteContent(path: path) ?? ""
            let newContent = existingContent + "\n\n" + content
            
            let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
            guard let url = URL(string: "\(obsidianRestAPIURL)/vault/\(encodedPath)") else {
                return false
            }
            
            let body = ["content": newContent]
            let bodyData = try JSONSerialization.data(withJSONObject: body)
            
            let _: ObsidianResponse = try await apiService.makeRequest(
                url: url,
                method: .PUT,
                body: bodyData,
                responseType: ObsidianResponse.self
            )
            
            return true
            
        } catch {
            print("Error appending to note: \(error)")
            return false
        }
    }
    
    func searchNotes(query: String) async -> [ObsidianNote] {
        do {
            let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
            guard let url = URL(string: "\(obsidianRestAPIURL)/search?query=\(encodedQuery)") else {
                return []
            }
            
            let response: ObsidianSearchResponse = try await apiService.makeRequest(
                url: url,
                responseType: ObsidianSearchResponse.self
            )
            
            return response.results.map { result in
                ObsidianNote(
                    path: result.filename,
                    name: result.filename.replacingOccurrences(of: ".md", with: ""),
                    stat: nil,
                    content: result.content
                )
            }
            
        } catch {
            print("Error searching notes: \(error)")
            return []
        }
    }
    
    func generateNoteSummary() -> String {
        let totalNotes = todayNotes.count
        let noteTypes = Set(todayNotes.map { $0.getType() })
        
        var summary = "今日Obsidian筆記摘要:\n"
        summary += "修改筆記數: \(totalNotes)\n"
        summary += "筆記類型: \(noteTypes.joined(separator: ", "))\n\n"
        
        summary += "主要筆記:\n"
        for note in todayNotes.prefix(10) {
            summary += "• \(note.name)\n"
        }
        
        return summary
    }
}

struct ObsidianVaultResponse: Codable {
    let files: [ObsidianFile]
}

struct ObsidianFile: Codable {
    let path: String
    let name: String
    let stat: ObsidianFileStat?
}

struct ObsidianFileStat: Codable {
    let ctime: Double
    let mtime: Double
    let size: Int
}

struct ObsidianNote: Identifiable, Codable {
    let id = UUID()
    let path: String
    let name: String
    let stat: ObsidianFileStat?
    var content: String?
    
    func getType() -> String {
        if path.contains("Daily Notes") {
            return "日記"
        } else if path.contains("Projects") {
            return "專案"
        } else if path.contains("Ideas") {
            return "想法"
        } else if path.contains("Meeting") {
            return "會議"
        } else {
            return "筆記"
        }
    }
}

struct ObsidianNoteContent: Codable {
    let content: String
}

struct ObsidianResponse: Codable {
    let success: Bool?
    let message: String?
}

struct ObsidianSearchResponse: Codable {
    let results: [ObsidianSearchResult]
}

struct ObsidianSearchResult: Codable {
    let filename: String
    let content: String
    let score: Double?
}