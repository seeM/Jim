import SwiftUI

struct Base64Image: Codable, Hashable {
    let text: String
    let value: NSImage
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(text)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.text = try container.decode(String.self)
        guard let data = Data(base64Encoded: self.text.trimmingCharacters(in: .whitespacesAndNewlines)),
              let nsImage = NSImage(data: data) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid Base64Image")
        }
        self.value = nsImage
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(text)
    }
}
