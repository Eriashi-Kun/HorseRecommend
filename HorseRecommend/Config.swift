import Foundation

enum Config {
    #if DEBUG
    static let backendURL = "http://localhost:8000"
    #else
    static let backendURL = "https://horse-recommend.onrender.com"
    #endif
}
