import AppKit
import Foundation

public struct SourceCodeTheme {
    static let shared = SourceCodeTheme()
    public let font = NSFont(name: "Menlo", size: 12)!
    public let backgroundColor = NSColor(red: 0, green: 0, blue: 0, alpha: 0.05)
    
    public func color(for syntaxColorType: SourceCodeTokenType) -> NSColor {
        switch syntaxColorType {
        case .plain: return .black
        case .number: return NSColor(red: 0, green: 136/255, blue: 0, alpha: 1.0)
        case .string: return NSColor(red: 186/255, green: 33/255, blue: 33/255, alpha: 1.0)
        case .identifier: return .black
        case .keyword: return NSColor(red: 0, green: 128/255, blue: 0, alpha: 1.0)
        case .comment: return NSColor(red: 0, green: 121/255, blue: 121/255, alpha: 1.0)
        }
    }
	
	public func globalAttributes() -> [NSAttributedString.Key: Any] {
        [.font: font, .foregroundColor: color(for: .plain)]
	}
	
	public func attributes(for token: Token) -> [NSAttributedString.Key: Any] {
		var attributes = [NSAttributedString.Key: Any]()
		if let token = token as? SimpleSourceCodeToken {
			attributes[.foregroundColor] = color(for: token.type)
		}
		return attributes
	}
}
