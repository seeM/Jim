import Foundation

struct Session: Codable {
    let id: String
    let name: String
    let path: String
    let type: ContentType
    let notebook: Self.Notebook
    let kernel: Kernel
    
    struct Notebook: Codable {
        let name: String
        let path: String
    }
}

struct Kernel: Codable {
    let id: String
    let connections: Int
    let executionState: String
    let lastActivity: Date
    let name: String
}
