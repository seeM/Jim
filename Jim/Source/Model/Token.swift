import Foundation

public protocol Token {
	
	/// When true, no attributes will be requested for this token.
	/// This causes a performance win for a large amount of tokens
	/// that don't require any attributes.
	var isPlain: Bool { get }
	
	/// The range of the token in the source string.
	var range: Range<String.Index> { get }
	
}

struct CachedToken {
	
	let token: Token
	let nsRange: NSRange
	
}
