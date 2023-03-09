import Foundation

struct StringOrArray: Codable, Hashable, Equatable {
    var value: String
    
    init(_ value: String) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let array = try? container.decode([String].self) {
            self.value = array.joined()
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "StringOrArray value cannot be decoded")
        }
    }
    
    enum CodingKeys: CodingKey {
        case value
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.value)
    }
}
