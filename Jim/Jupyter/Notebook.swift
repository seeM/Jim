import AnyCodable
import Foundation

class Notebook: Codable {
    let name: String
    var id: String { name }
    let path: String
    var lastModified: Date
    let created: Date
    var content: NotebookContent
    var size: Int?
    let type: ContentType
    var dirty = false
    
    enum CodingKeys: CodingKey {
        case name
        case path
        case lastModified
        case created
        case content
        case size
        case type
    }
}

class NotebookContent: Codable {
    var cells: [Cell]
    let nbformat: Int
    let nbformatMinor: Int
    let metadata: [String: AnyCodable]
}

//struct NotebookMetadata: Codable {
//    let widgets: NotebookMetadataWidgets?
//}
//
//struct NotebookMetadataWidgets: Codable {
//    let widgetState: NotebookMetadataWidgetState
//
//    enum CodingKeys: String, CodingKey {
//        case widgetState = "application/vnd.jupyter.widget-state+json"
//    }
//}
//
//struct NotebookMetadataWidgetState: Codable {
//    let state: [String: WidgetModel]
//    let versionMajor: Int
//    let versionMinor: Int
//}
//
//struct WidgetModel: Codable {
//    let modelModule: String
//    let modelModuleVersion: String
//    let modelName: String
//    let state: AnyCodable
//}
