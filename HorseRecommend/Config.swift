import Foundation

enum Config {
    #if DEBUG
    static let backendURL = "http://localhost:8000"
    #else
    static let backendURL = "https://your-app.onrender.com"  // Renderデプロイ後に更新
    #endif
}
