import AppKit
import Down

class MarkdownStyler: DownStyler {
    static let shared = MarkdownStyler()

    init() {
        let headingStyle = NSMutableParagraphStyle()
        let bodyStyle = NSMutableParagraphStyle()
        let codeStyle = NSMutableParagraphStyle()

        var listItemOptions = ListItemOptions()
        var quoteStripeOptions = QuoteStripeOptions()
        var thematicBreakOptions = ThematicBreakOptions()
        var codeBlockOptions = CodeBlockOptions()

//        headingStyle.paragraphSpacingBefore = 0
//        headingStyle.paragraphSpacing = 0
//
//        bodyStyle.lineSpacing = 0
//        bodyStyle.paragraphSpacing = 0
//
//        codeStyle.lineSpacing = 0
//        codeStyle.paragraphSpacing = 0
//
//        listItemOptions.maxPrefixDigits = 1
//        listItemOptions.spacingAfterPrefix = 4
//        listItemOptions.spacingAbove = 2
//        listItemOptions.spacingBelow = 4
//
        quoteStripeOptions.thickness = 5
        quoteStripeOptions.spacingAfter = 8
//
//        thematicBreakOptions.thickness = 1
//        thematicBreakOptions.indentation = 0
//
//        codeBlockOptions.containerInset = 8

        var paragraphStyles = StaticParagraphStyleCollection()
//        paragraphStyles.body = bodyStyle
//        paragraphStyles.heading1 = headingStyle
//        paragraphStyles.heading2 = headingStyle
//        paragraphStyles.heading3 = headingStyle
//        paragraphStyles.code = codeStyle

        let downStylerConfiguration = DownStylerConfiguration(
            fonts: MarkdownStyler.fontCollection(),
            colors: MarkdownStyler.colorCollection,
            paragraphStyles: paragraphStyles,
            listItemOptions: listItemOptions,
            quoteStripeOptions: quoteStripeOptions,
            thematicBreakOptions: thematicBreakOptions,
            codeBlockOptions: codeBlockOptions
        )

        super.init(configuration: downStylerConfiguration)
    }

    static func fontCollection() -> FontCollection {
        var fonts = StaticFontCollection()
//        fonts.body = .preferredFont(forTextStyle: .body).withSize(14)
//        fonts.heading1 = .preferredFont(forTextStyle: .title1)
//        fonts.heading2 = .preferredFont(forTextStyle: .title2)
//        fonts.heading3 = .preferredFont(forTextStyle: .title3)
//        let monospaced = font(
//            for: NSFontDescriptor.preferredFontDescriptor(forTextStyle: .body).withDesign(.monospaced),
//            fallback: NSFont.preferredFont(forTextStyle: .body)
//        )
//        fonts.code = monospaced
//        fonts.listItemPrefix = monospaced
        return fonts
    }

    private static func font(for descriptor: NSFontDescriptor?, fallback fallbackFont: NSFont) -> NSFont {
        if let descriptor = descriptor {
            return NSFont(descriptor: descriptor, size: 0)!
        } else {
            return fallbackFont
        }
    }

    static var colorCollection: ColorCollection {
        var colors = StaticColorCollection()
//        colors.body = .labelColor
//        colors.heading1 = .labelColor
//        colors.heading2 = .labelColor
//        colors.heading3 = .labelColor
//        colors.code = .labelColor
//        colors.link = .linkColor
//        colors.listItemPrefix = .controlAccentColor
//        colors.quote = .secondaryLabelColor
        colors.quoteStripe = .init(red: 0.933, green: 0.933, blue: 0.933, alpha: 1)
//        colors.thematicBreak = .black
        return colors
    }

//    override func style(text string: NSMutableAttributedString) {
//        super.style(text: string)
//        string.addAttributes([.kern: NSFont.body.kerning(6)], range: NSRange(location: 0, length: string.count))
//    }
//
//    func style(seeMore string: NSMutableAttributedString) {
//        self.style(text: string)
//    }
}
