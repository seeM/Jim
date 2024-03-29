import Combine
import AnyCodable
import SwiftUI

enum JupyterError: Error {
    case notAuthenticated, unknownError, decodeError, encodeError
    case serverError(JupyterServerError)
}

struct JupyterServerError: Codable {
    let message: String
    let reason: String?
}

class JupyterService {
    static let shared = JupyterService()

    var baseUrl: String?
    private var token: String?
    private var xsrf: String?
    
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    
    private var activeSession: Session?
    private var sessions = [Session: URLSessionWebSocketTask?]()
    private var executeRequests = [String: (Cancellable, PassthroughSubject<Message, Never>)]()
    
    static var nbformatUserInfoKey: CodingUserInfoKey {
        .init(rawValue: "nbformat")!
    }
    
    init() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"
        encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .formatted(dateFormatter)
        decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .formatted(dateFormatter)
    }
    
    func login(baseUrl: String, token: String) async -> Bool {
        let url = URL(string: baseUrl)!
        var request = URLRequest(url: url)
        request.setValue("token \(token)", forHTTPHeaderField: "Authorization")
        if let _ = try? await URLSession.shared.data(for: request),
           let xsrf = HTTPCookieStorage.shared.cookies?.first(where: { $0.name == "_xsrf" })?.value {
            self.baseUrl = baseUrl
            self.xsrf = xsrf
            return true
        }
        return false
    }

    private func makeRequest(path: String, method: String, json: [String: Any]? = nil, jsonData: Data? = nil) -> URLRequest? {
        guard let baseUrl, let xsrf else { return nil }
        assert(!(json != nil && jsonData != nil), "Cannot accept both json and jsonData")
        
        let timestamp = Int(1000 * Date().timeIntervalSince1970)
        let urlText = baseUrl + path + "?" + String(timestamp)
        let url = URL(string: urlText)!
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(xsrf, forHTTPHeaderField: "X-XSRFToken")

        if let jsonData {
            request.httpBody = jsonData
        } else if let json {
            request.httpBody = try! JSONSerialization.data(withJSONObject: json)
        }
        if request.httpBody != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        
        return request
    }
    
    func request(path: String, method: String = "GET", json: [String: Any]? = nil, jsonData: Data? = nil) async -> Result<Data,JupyterError> {
        guard let request = makeRequest(path: path, method: method, json: json, jsonData: jsonData) else {
            return .failure(JupyterError.notAuthenticated)
        }
        
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            print("Error on request \(request):", error)
            return .failure(JupyterError.unknownError)
        }
        
        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 500 {
                let result = try! decoder.decode(JupyterServerError.self, from: data)
                return .failure(JupyterError.serverError(result))
            }
        }
        
        return .success(data)
    }

    func decode<T: Decodable>(type: T.Type, data: Data) -> Result<T,JupyterError> {
        do {
            let result = try decoder.decode(T.self, from: data)
            return .success(result)
        } catch {
            print("Error decoding response of type \(T.self):", error)
            print("Data:", String(data: data, encoding: .utf8)!.prefix(1000))
            return .failure(JupyterError.decodeError)
        }
    }

    func getContent<T: Decodable>(_ path: String = "", type: T.Type) async -> Result<T,JupyterError> {
        let data = await request(path: "api/contents/" + path.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!)
        return data.flatMap { decode(type: type, data: $0) }
    }
    
    func updateContent<T: Encodable>(_ path: String, content: T) async -> Result<Content,JupyterError> {
        let contentJson: Data
        do {
            if let notebook = content as? Notebook {
                encoder.userInfo[JupyterService.nbformatUserInfoKey] = (notebook.content.nbformat, notebook.content.nbformatMinor)
            }
            contentJson = try encoder.encode(content)
        } catch {
            print("Error encoding content of type \(T.self)")
            return .failure(JupyterError.encodeError)
        }
        let data = await request(path: "api/contents/" + path.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!, method: "PUT", jsonData: contentJson)
        return data.flatMap { decode(type: Content.self, data: $0) }
    }

    func createSession(name: String, path: String) async -> Result<Session,JupyterError> {
        // TODO: make kernel an arg
        let data = await request(path: "api/sessions", method: "POST", json: ["kernel": ["name": "python3"], "name": name, "path": path, "type": ContentType.notebook.rawValue])
        let result = data.flatMap { decode(type: Session.self, data: $0) }
        if case let .success(session) = result {
            self.activeSession = session
            if self.sessions[session] == nil {
                self.sessions[session] = nil
            }
        }
        return result
    }
    
    func interruptKernel() async -> JupyterError? {
        switch await request(path: "api/kernels/\(activeSession!.kernel.id)/interrupt", method: "POST") {
        case .success(_): return nil
        case .failure(let error):
            print("Failed to interrupt:", error)
            return error
        }
    }
    
    func restartKernel() async -> Result<Kernel,JupyterError> {
        let data = await request(path: "api/kernels/\(activeSession!.kernel.id)/restart", method: "POST")
        return data.flatMap { decode(type: Kernel.self, data: $0) }
    }
    
    func webSocketTask(_ session: Session) {
        guard let baseUrl else { return }
        if self.sessions[session] != nil { return }
        // TODO: why don't I need xsrf here?
        let url = URL(string: baseUrl + "api/kernels/\(session.kernel.id)/channels?session_id=\(session.id)")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        let task = URLSession.shared.webSocketTask(with: request)
        self.sessions[session] = task
        task.resume()
        recieveAll(task)
    }
    
    private func recieveAll(_ task: URLSessionWebSocketTask) {
        task.receive { result in
            switch result {
            case .failure(let error):
                print("Failed to receive message, exiting recieve handler: \(error)")
                return
            case .success(let message):
                switch message {
                case .string(let text):
                    do {
                        let msg = try self.decoder.decode(Message.self, from: text.data(using: .utf8)!)
                        if let msgId = msg.parentHeader?.msgId,
                           let subject = self.executeRequests[msgId]?.1 {
                            subject.send(msg)
                        }
                    } catch {
                        print("Error decoding data. Error: \(error), Data: \(text)")
                    }
                case .data(let data):
                    print("Received binary message: \(data)")
                @unknown default:
                    fatalError()
                }
            }
            self.recieveAll(task)
        }
    }

    func webSocketSend(code: String, handler: @escaping (Message) -> ()) {
        // TODO: Where does username come from?
        let msgId = UUID().uuidString // TODO: move into Message?
        let msg = Message(header: MessageHeader(msgId: msgId, session: self.activeSession!.id, username: "seem", version: "5.3", date: Date(), msgType: .executeRequest), parentHeader: nil, content: MessageContent.executeRequest(.init(code: code, silent: false)), channel: .shell)
        let msgD: Data
        do {
            msgD = try self.encoder.encode(msg)
        } catch {
            print("Error decoding message to send: \(error)")
            return
        }
        let msgS = String(data: msgD, encoding: .utf8)!
        let codeMsgD = URLSessionWebSocketTask.Message.string(msgS)
        let subject = PassthroughSubject<Message, Never>()
        let cancellable = subject.sink { msg in
            handler(msg)
        }
        self.executeRequests[msgId] = (cancellable, subject)
        self.sessions[self.activeSession!]!!.send(codeMsgD) { error in
            if let error = error {
                print("Error: \(error)")
                return
            }
        }
    }
}
