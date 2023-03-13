import AnyCodable
import Foundation

class Cell: Codable, Identifiable {
    let id: String
    let cellType: CellType
    var source: StringOrArray
    var outputs: [Output]?
    let metadata: [String: AnyCodable]?
    let executionCount: Int?
    
    init(id: String? = nil, cellType: CellType = .code, source: StringOrArray = StringOrArray(""), outputs: [Output]? = [], metadata: [String: AnyCodable]? = nil) {
        self.id = id ?? UUID().uuidString
        self.cellType = cellType
        self.source = source
        self.outputs = outputs
        self.metadata = metadata
        self.executionCount = nil  // TODO
    }
    
    convenience init(from cell: Cell) {
        self.init(cellType: cell.cellType, source: cell.source, outputs: cell.outputs)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        self.cellType = try container.decode(CellType.self, forKey: .cellType)
        self.source = try container.decode(StringOrArray.self, forKey: .source)
        self.outputs = try container.decodeIfPresent([Output].self, forKey: .outputs)
        self.metadata = try container.decodeIfPresent([String: AnyCodable].self, forKey: .metadata)
        self.executionCount = try container.decodeIfPresent(Int.self, forKey: .executionCount)
    }
    
    enum CodingKeys: CodingKey {
        case id
        case cellType
        case source
        case outputs
        case metadata
        case executionCount
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if encoder.userInfo[JupyterService.nbformatUserInfoKey] as! (Int, Int) >= (4, 5) {
            try container.encode(self.id, forKey: .id)
        }
        try container.encode(self.cellType, forKey: .cellType)
        try container.encode(self.source, forKey: .source)
        try container.encodeIfPresent(self.outputs, forKey: .outputs)
        if let metadata {
            try container.encode(metadata, forKey: .metadata)
        } else {
            try container.encode([String: AnyCodable](), forKey: .metadata)
        }
        // TODO: Make Cell an enum?
        switch self.cellType {
        case .code: try container.encode(self.executionCount, forKey: .executionCount)
        default: break
        }
    }
}

enum CellType: String, Codable {
    case raw, markdown, code
}
