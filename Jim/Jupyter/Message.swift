import AnyCodable
import Foundation

struct Message: Codable {
//    let buffers: []  // TODO: need?
    let header: MessageHeader
    let parentHeader: MessageHeader?
    let content: MessageContent
    let channel: MessageChannel
    let metadata: [String: AnyCodable]
        
    init(header: MessageHeader, parentHeader: MessageHeader?, content: MessageContent, channel: MessageChannel, metadata: [String: AnyCodable] = [:]) {
        self.header = header
        self.parentHeader = parentHeader
        self.content = content
        self.channel = channel
        self.metadata = metadata
    }
    
    enum CodingKeys: String, CodingKey {
        case header, parentHeader, content, channel, metadata
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let parentHeader = try? container.decode(MessageHeader.self, forKey: .parentHeader) {
            self.parentHeader = parentHeader
        } else {
            let parentHeader = try container.decode([String: String].self, forKey: .parentHeader)
            if parentHeader == [:] {
                self.parentHeader = nil
            } else {
                throw DecodingError.dataCorruptedError(forKey: .parentHeader, in: container, debugDescription: "MessageHeader value cannot be decoded")
            }
        }
        self.channel = try container.decode(MessageChannel.self, forKey: .channel)
        self.metadata = try container.decode([String: AnyCodable].self, forKey: .metadata)
        self.header = try container.decode(MessageHeader.self, forKey: .header)
        switch self.header.msgType {
        case .executeRequest: self.content = .executeRequest(try container.decode(ExecuteRequestContent.self, forKey: .content))
        case .executeReply: self.content = .executeReply(try container.decode(ExecuteReplyContent.self, forKey: .content))
        case .executeResult: self.content = .executeResult(try container.decode(ExecuteResultOutput.self, forKey: .content))
        case .status: self.content = .status(try container.decode(StatusContent.self, forKey: .content))
        case .kernelInfoRequest: self.content = .kernelInfoRequest(try container.decode(KernelInfoRequestContent.self, forKey: .content))
        case .executeInput: self.content = .executeInput(try container.decode(ExecuteInputContent.self, forKey: .content))
        case .stream: self.content = .stream(try container.decode(StreamOutput.self, forKey: .content))
        case .error: self.content = .error(try container.decode(ErrorOutput.self, forKey: .content))
        case .displayData: self.content = .displayData(try container.decode(DisplayDataOutput.self, forKey: .content))
        case .commOpen: self.content = .commOpen(try container.decode(CommOpenContent.self, forKey: .content))
        case .commMessage: self.content = .commMessage(try container.decode(CommMessageContent.self, forKey: .content))
        case .shutdownRequest: self.content = .shutdownRequest(try container.decode(ShutdownRequestContent.self, forKey: .content))
        case .shutdownReply: self.content = .shutdownReply(try container.decode(ShutdownReplyContent.self, forKey: .content))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if self.parentHeader == nil {
            try container.encode(AnyCodable([:]), forKey: .parentHeader)
        } else {
            try container.encode(self.parentHeader, forKey: .parentHeader)
        }
        try container.encode(self.channel, forKey: .channel)
        try container.encode(self.metadata, forKey: .metadata)
        try container.encode(self.header, forKey: .header)
        switch self.content {
        case .executeRequest(let content): try container.encode(content, forKey: .content)
        case .executeReply(let content): try container.encode(content, forKey: .content)
        case .executeResult(let content): try container.encode(content, forKey: .content)
        case .status(let content): try container.encode(content, forKey: .content)
        case .kernelInfoRequest(let content): try container.encode(content, forKey: .content)
        case .executeInput(let content): try container.encode(content, forKey: .content)
        case .stream(let content): try container.encode(content, forKey: .content)
        case .error(let content): try container.encode(content, forKey: .content)
        case .displayData(let content): try container.encode(content, forKey: .content)
        case .commOpen(let content): try container.encode(content, forKey: .content)
        case .commMessage(let content): try container.encode(content, forKey: .content)
        case .shutdownRequest(let content): try container.encode(content, forKey: .content)
        case .shutdownReply(let content): try container.encode(content, forKey: .content)
        }
    }
}

enum MessageChannel: String, Codable {
    case shell, iopub
}

struct MessageHeader: Codable {
    let msgId: String
    let session: String
    let username: String
    let version: String
    let date: Date
    let msgType: MessageType
    
    init(msgId: String, session: String, username: String, version: String, date: Date, msgType: MessageType) {
        self.msgId = msgId
        self.session = session
        self.username = username
        self.version = version
        self.date = date
        self.msgType = msgType
    }
}

enum MessageType: String, Codable {
    case executeRequest = "execute_request"
    case executeReply = "execute_reply"
    case executeResult = "execute_result"
    case status
    case kernelInfoRequest = "kernel_info_request"
    case executeInput = "execute_input"
    case stream
    case error
    case displayData = "display_data"
    case commOpen = "comm_open"
    case commMessage = "comm_msg"
    case shutdownRequest = "shutdown_request"
    case shutdownReply = "shutdown_reply"
    //    case execute_reply, inspect_request, inspect_reply, complete_request, complete_reply, history_request, history_reply, is_complete_request, is_complete_reply, connect_request, connect_reply, comm_info_request, comm_info_reply, kernel_info_request, kernel_info_reply, shutdown_request, shutdown_reply, interrupt_request, interrupt_reply, debug_request, debug_reply, stream, display_data, update_display_data, execute_input, execute_result, error, status, clear_output, debug_event, input_request, input_reply, comm_msg, comm_close
}

enum MessageContent {
    case executeRequest(ExecuteRequestContent)
    case executeReply(ExecuteReplyContent)
    case executeResult(ExecuteResultOutput)
    case displayData(DisplayDataOutput)
    case status(StatusContent)
    case kernelInfoRequest(KernelInfoRequestContent)
    case executeInput(ExecuteInputContent)
    case stream(StreamOutput)
    case error(ErrorOutput)
    case commOpen(CommOpenContent)
    case commMessage(CommMessageContent)
    case shutdownRequest(ShutdownRequestContent)
    case shutdownReply(ShutdownReplyContent)
    
    enum CodingKeys: String, CodingKey {
        case msgType
    }
    
//    init(from decoder: Decoder) throws {
//        let container = try decoder.container(keyedBy: CodingKeys.self)
//        let msgType = try container.decode(MessageType.self, forKey: .msgType)
//        let typeContainer = try decoder.singleValueContainer()
//        switch msgType {
//        case .executeRequest: self = .executeRequest(try typeContainer.decode(ExecuteRequestContent.self))
//        case .status: self = .status(try typeContainer.decode(StatusContent.self))
//        case .kernelInfoRequest: self = .kernelInfoRequest(try typeContainer.decode(KernelInfoRequestContent.self))
//        }
//    }
//
//    func encode(to encoder: Encoder) throws {
//        var container = encoder.container(keyedBy: CodingKeys.self)
//        var typeContainer = encoder.singleValueContainer()
//        switch self {
//        case .executeRequest(let content):
//            try typeContainer.encode(content)
//            try container.encode(MessageType.executeRequest, forKey: .msgType)
//        case .status(let content):
//            try typeContainer.encode(content)
//            try container.encode(MessageType.status, forKey: .msgType)
//        case .kernelInfoRequest(let content):
//            try typeContainer.encode(content)
//            try container.encode(MessageType.kernelInfoRequest, forKey: .msgType)
//
//        }
//    }
}

struct CommOpenContent: Codable {
    let data: AnyCodable
    let commId: String
    let targetName: String
    let targetModule: String?
}

struct CommMessageContent: Codable {
    let data: AnyCodable
    let commId: String
}

struct ExecuteRequestContent: Codable {
    let code: String
    let silent: Bool// = false
    let storeHistory: Bool?
    let userExpressions: [String: AnyCodable]?
    let allowStdin: Bool?
    let stopOnError: Bool?
    
    init(code: String, silent: Bool, storeHistory: Bool? = nil, userExpressions: [String: AnyCodable]? = nil, allowStdin: Bool? = nil, stopOnError: Bool? = nil) {
        self.code = code
        self.silent = silent
        self.storeHistory = storeHistory
        self.userExpressions = userExpressions
        self.allowStdin = allowStdin
        self.stopOnError = stopOnError
    }
}

struct ExecuteReplyContent: Codable {
    let status: String // TODO: Make enum?
    let executionCount: Int
    let userExpressions: [String: AnyCodable]?
    let payload: [AnyCodable] // TODO: need?
}

struct StatusContent: Codable {
    let executionState: ExecutionState
    
    init(executionState: ExecutionState) {
        self.executionState = executionState
    }
}

enum ExecutionState: String, Codable {
    case busy, idle, starting
}

struct KernelInfoRequestContent: Codable {
    init() { }
}

struct ExecuteInputContent: Codable {
    let code: String
    let executionCount: Int
}

struct ShutdownRequestContent: Codable {
    let restart: Bool
}

struct ShutdownReplyContent: Codable {
    let status: String  // TODO: make enum?
    let restart: Bool
}
