import Foundation

struct Session: Codable, Hashable {
    let id: String
    let name: String
    let path: String
    let type: ContentType
    let notebook: Self.Notebook
    let kernel: Kernel
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Session, rhs: Session) -> Bool {
        lhs.id == rhs.id
    }
    
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
