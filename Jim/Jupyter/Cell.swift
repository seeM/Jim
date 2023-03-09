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
        try container.encode(self.cellType, forKey: .cellType)
        try container.encode(self.source, forKey: .source)
        try container.encodeIfPresent(self.outputs, forKey: .outputs)
        try container.encodeIfPresent(self.metadata, forKey: .metadata)
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

enum Output: Codable, Hashable, Identifiable {
    var id: Self { self }
    case stream(StreamOutput)
    case displayData(DisplayDataOutput)
    case executeResult(ExecuteResultOutput)
    case error(ErrorOutput)
    
    enum CodingKeys: String, CodingKey {
        case outputType
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let outputType = try container.decode(OutputType.self, forKey: .outputType)
        let typeContainer = try decoder.singleValueContainer()
        switch outputType {
        case .stream: self = .stream(try typeContainer.decode(StreamOutput.self))
        case .displayData: self = .displayData(try typeContainer.decode(DisplayDataOutput.self))
        case .executeResult: self = .executeResult(try typeContainer.decode(ExecuteResultOutput.self))
        case .error: self = .error(try typeContainer.decode(ErrorOutput.self))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var typeContainer = encoder.singleValueContainer()
        switch self {
        case .stream(let output): try typeContainer.encode(output)
        case .displayData(let output): try typeContainer.encode(output)
        case .executeResult(let output): try typeContainer.encode(output)
        case .error(let output): try typeContainer.encode(output)
        }
    }
}

enum OutputType: String, Codable {
    case stream
    case displayData = "display_data"
    case executeResult = "execute_result"
    case error
}

struct StreamOutput: Codable, Hashable {
    let outputType: OutputType
    let name: StreamName
    let text: String
}

enum StreamName: String, Codable {
    case stderr, stdout
}

struct DisplayDataOutput: Codable, Hashable {
    let outputType: OutputType
    let data: OutputData
    var metadata: [String: AnyCodable]?
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.outputType, forKey: .outputType)
        try container.encode(self.data, forKey: .data)
        if let metadata {
            try container.encode(metadata, forKey: .metadata)
        } else {
            try container.encode(AnyCodable([:]), forKey: .metadata)
        }
    }
}

struct ExecuteResultOutput: Codable, Hashable {
    let outputType: OutputType
    let data: OutputData
    var metadata: [String: AnyCodable]?
    let executionCount: Int?
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.outputType, forKey: .outputType)
        try container.encode(self.data, forKey: .data)
        if let metadata {
            try container.encode(metadata, forKey: .metadata)
        } else {
            try container.encode(AnyCodable([:]), forKey: .metadata)
        }
        try container.encode(executionCount, forKey: .executionCount)
    }
}

struct OutputData: Codable, Hashable {
    let plainText: StringOrArray?
    let markdownText: StringOrArray?
    let widgetView: WidgetView?
    let image: Base64Image?
    
    enum CodingKeys: String, CodingKey {
        case plainText = "text/plain"
        case markdownText = "text/markdown"
        case image = "image/png"
        case widgetView = "application/vnd.jupyter.widget-view+json"
    }
}

struct WidgetView: Codable, Hashable {
    let modelId: String
    let versionMajor: Int
    let versionMinor: Int
}

struct ErrorOutput: Codable, Hashable {
    let outputType: OutputType
    let traceback: [String]
    let ename: String
    let evalue: String
}
