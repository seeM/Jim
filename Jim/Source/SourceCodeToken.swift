import Foundation

public enum SourceCodeTokenType {
	case plain
	case number
	case string
	case identifier
	case keyword
	case comment
}

protocol SourceCodeToken: Token {
	
	var type: SourceCodeTokenType { get }
	
}

extension SourceCodeToken {
	
	var isPlain: Bool {
		return type == .plain
	}
	
}

struct SimpleSourceCodeToken: SourceCodeToken {
	
	let type: SourceCodeTokenType
	
	let range: Range<String.Index>
	
}
