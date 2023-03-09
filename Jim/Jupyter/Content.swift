import Foundation

struct Content: Codable, Hashable, Comparable {
    let name: String
    let path: String
    let lastModified: Date
    let created: Date
    let content: [Content]?
    let size: Int?
    let type: ContentType
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(path)
    }
    
    static func <(lhs: Self, rhs: Self) -> Bool {
        (lhs.type, lhs.name.lowercased()) < (rhs.type, rhs.name.lowercased())
    }
}

enum ContentType: String, Codable, Comparable {
    case directory, notebook, file

    private static func minimum(_ lhs: Self, _ rhs: Self) -> Self {
        switch (lhs, rhs) {
        case (.directory, _), (_, .directory):
            return .directory
        case (.notebook, _), (_, .notebook):
            return .notebook
        case (.file, _), (_, .file):
            return .file
        }
    }
    
    static func <(lhs: Self, rhs: Self) -> Bool {
        (lhs != rhs) && (lhs == Self.minimum(lhs, rhs))
    }
}
