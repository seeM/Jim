import AppKit
import Foundation
import CoreGraphics

public protocol SyntaxColorTheme {
	
	var font: NSFont { get }
	
	var backgroundColor: NSColor { get }

	func globalAttributes() -> [NSAttributedString.Key: Any]

	func attributes(for token: Token) -> [NSAttributedString.Key: Any]
}
