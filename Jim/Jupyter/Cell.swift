import Foundation

class Cell: Codable, Identifiable {
    let id: String
    let cellType: CellType
    var source: StringOrArray
    var outputs: [Output]?
    
    init(id: String? = nil, cellType: CellType = .code, source: StringOrArray = StringOrArray(""), outputs: [Output]? = []) {
        self.id = id ?? UUID().uuidString
        self.cellType = cellType
        self.source = source
        self.outputs = outputs
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
        var container = encoder.container(keyedBy: CodingKeys.self)
        var typeContainer = encoder.singleValueContainer()
        switch self {
        case .stream(let output):
            try typeContainer.encode(output)
            try container.encode(OutputType.stream, forKey: .outputType)
        case .displayData(let output):
            try typeContainer.encode(output)
            try container.encode(OutputType.displayData, forKey: .outputType)
        case .executeResult(let output):
            try typeContainer.encode(output)
            try container.encode(OutputType.executeResult, forKey: .outputType)
        case .error(let output):
            try typeContainer.encode(output)
            try container.encode(OutputType.error, forKey: .outputType)
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
    let name: StreamName
    let text: String
}

enum StreamName: String, Codable {
    case stderr, stdout
}

struct DisplayDataOutput: Codable, Hashable {
    let data: OutputData
}

struct ExecuteResultOutput: Codable, Hashable {
    let data: OutputData
}

struct OutputData: Codable, Hashable {
    let text: StringOrArray?
    let widgetView: WidgetView?
    let image: Base64Image?
    
    enum CodingKeys: String, CodingKey {
        case text = "text/plain"
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
    let traceback: [String]
    let ename: String
    let evalue: String
}
