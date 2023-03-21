import AppKit

extension NSMutableAttributedString {
	convenience init(source: String, tokens: [Token], theme: SourceCodeTheme) {
		self.init(string: source)
		
		let spaceWidth = NSAttributedString(string: " ", attributes: [.font: theme.font]).size().width
		let themeInfo = ThemeInfo(theme: theme, spaceWidth: spaceWidth)
		
		let paragraphStyle = NSMutableParagraphStyle()
		paragraphStyle.paragraphSpacing = 2.0
		paragraphStyle.defaultTabInterval = themeInfo.spaceWidth * 4
		paragraphStyle.tabStops = []
		// Improve performance by manually specifying writing direction.
		paragraphStyle.baseWritingDirection = .leftToRight
		paragraphStyle.alignment = .left
		
        let globalAttributes: [NSAttributedString.Key: Any] = [.paragraphStyle: paragraphStyle].merging(theme.globalAttributes(), uniquingKeysWith: { $1 })
        let wholeRange = NSRange(location: 0, length: source.count)
		self.setAttributes(globalAttributes, range: wholeRange)
		
		for token in tokens {
			if token.isPlain {
				continue
			}
            let range = NSRange(token.range, in: source)
			self.setAttributes(theme.attributes(for: token), range: range)
		}
	}
}
