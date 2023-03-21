import Foundation

public protocol Lexer {
	
	func getSavannaTokens(input: String) -> [Token]
	
}
