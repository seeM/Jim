import Foundation

public class Python3Lexer: SourceCodeRegexLexer {
	
	public init() {
		
	}
	
	lazy var generators: [TokenGenerator] = {
		
		var generators = [TokenGenerator?]()
		// Functions
		generators.append(regexGenerator("\\bprint(?=\\()", tokenType: .identifier))
		
		generators.append(regexGenerator("(?<=[^a-zA-Z])\\d+", tokenType: .number))
		
		generators.append(regexGenerator("\\.\\w+", tokenType: .identifier))
		
		let keywords = "False None True and as assert break class continue def del elif else except finally for from global if import in is lambda nonlocal not or pass raise return try while with yield".components(separatedBy: " ")
        
		generators.append(keywordGenerator(keywords, tokenType: .keyword))
		
		// Line comment
        generators.append(regexGenerator("#(.*)", tokenType: .comment))
		
		// Block comment or multi-line string literal
		generators.append(regexGenerator("(\"\"\".*\"\"\")|(\'\'\'.*\'\'\')", options: [.dotMatchesLineSeparators], tokenType: .comment))

		// Single-line string literal
		generators.append(regexGenerator("('.*')|(\".*\")", tokenType: .string))

		return generators.compactMap( { $0 })
	}()
	
	public func generators(source: String) -> [TokenGenerator] {
		return generators
	}
	
}