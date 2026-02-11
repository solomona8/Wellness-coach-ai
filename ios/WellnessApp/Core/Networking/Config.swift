import Foundation

enum Config {
    // MARK: - Supabase
    static let supabaseUrl = "https://rlaplngwvnqzpfxtuhuj.supabase.co"
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJsYXBsbmd3dm5xenBmeHR1aHVqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzAzMDk1MTYsImV4cCI6MjA4NTg4NTUxNn0.FMMn322Wu2dgnUvb1JMGorwsuGRyprW518iprmniclg"

    // MARK: - API
    // For development, use your local IP address or ngrok tunnel
    // For production, use your deployed API URL
    static let apiBaseUrl = "https://wellness-coach-ai.onrender.com/api/v1"

    // MARK: - App
    static let appName = "Wellness Coach AI"
    static let deviceId: String = {
        if let id = UserDefaults.standard.string(forKey: "deviceId") {
            return id
        }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: "deviceId")
        return id
    }()
}
