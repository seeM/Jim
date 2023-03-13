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
    
    private var session: Session?
    private var task: URLSessionWebSocketTask?
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

    func request<T: Decodable>(type: T.Type, path: String, method: String = "GET", json: [String: Any]? = nil, jsonData: Data? = nil) async -> Result<T,JupyterError> {
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
        return await request(type: type, path: "api/contents/" + path.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!)
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
        return await request(type: Content.self, path: "api/contents/" + path.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!, method: "PUT", jsonData: contentJson)
    }

    func createSession(name: String, path: String) async -> Result<Session,JupyterError> {
        // TODO: make kernel an arg
        let result = await request(type: Session.self, path: "api/sessions", method: "POST", json: ["kernel": ["name": "python3"], "name": name, "path": path, "type": ContentType.notebook.rawValue])
        switch result {
        case .success(let session): self.session = session
        default: break
        }
        return result
    }
    
    func webSocketTask(_ session: Session) {
        guard let baseUrl else { return }
        // TODO: why don't I need xsrf here?
        let url = URL(string: baseUrl + "api/kernels/\(session.kernel.id)/channels?session_id=\(session.id)")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        let task = URLSession.shared.webSocketTask(with: request)
        self.task = task
        task.resume()
        recieveAll(task)
    }
    
    private func recieveAll(_ task: URLSessionWebSocketTask) {
        task.receive { result in
            switch result {
            case .failure(let error):
                print("Failed to receive message: \(error)")
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
        let msg = Message(header: MessageHeader(msgId: msgId, session: self.session!.id, username: "seem", version: "5.3", date: Date(), msgType: .executeRequest), parentHeader: nil, content: MessageContent.executeRequest(.init(code: code, silent: false)), channel: .shell)
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
        self.task!.send(codeMsgD) { error in
            if let error = error {
                print("Error: \(error)")
                return
            }
        }
    }
}
