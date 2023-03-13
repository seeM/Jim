import AnyCodable
import Foundation

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
        
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .stream(_): try container.encode(OutputType.stream, forKey: .outputType)
        case .displayData(_): try container.encode(OutputType.displayData, forKey: .outputType)
        case .executeResult(_): try container.encode(OutputType.executeResult, forKey: .outputType)
        case .error(_): try container.encode(OutputType.error, forKey: .outputType)
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
    let data: OutputData
    var metadata: [String: AnyCodable]?
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.data, forKey: .data)
        if let metadata {
            try container.encode(metadata, forKey: .metadata)
        } else {
            try container.encode([String: AnyCodable](), forKey: .metadata)
        }
    }
}

struct ExecuteResultOutput: Codable, Hashable {
    let data: OutputData
    var metadata: [String: AnyCodable]?
    let executionCount: Int?
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.data, forKey: .data)
        if let metadata {
            try container.encode(metadata, forKey: .metadata)
        } else {
            try container.encode([String: AnyCodable](), forKey: .metadata)
        }
        try container.encode(executionCount, forKey: .executionCount)
    }
}

struct OutputData: Codable, Hashable {
    let plainText: StringOrArray?
    let markdownText: StringOrArray?
    let htmlText: StringOrArray?
    let widgetView: WidgetView?
    let image: Base64Image?
    
    enum CodingKeys: String, CodingKey {
        case plainText = "text/plain"
        case markdownText = "text/markdown"
        case htmlText = "text/html"
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
