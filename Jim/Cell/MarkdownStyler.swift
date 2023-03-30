import AppKit
import Down

class MarkdownStyler: DownStyler {
    static let shared = MarkdownStyler()

    init() {
        var listItemOptions = ListItemOptions()
        var quoteStripeOptions = QuoteStripeOptions()
        let thematicBreakOptions = ThematicBreakOptions()
        let codeBlockOptions = CodeBlockOptions()

        listItemOptions.spacingAbove = 0
        listItemOptions.spacingBelow = 0

        quoteStripeOptions.thickness = 5
        quoteStripeOptions.spacingAfter = 16

        let bodyStyle = NSMutableParagraphStyle()
        bodyStyle.paragraphSpacingBefore = 14
        bodyStyle.paragraphSpacing = 14

        let heading1Style = NSMutableParagraphStyle()
        heading1Style.paragraphSpacingBefore = 9
        heading1Style.paragraphSpacing = 9
        
        let secondaryHeadingStyle = NSMutableParagraphStyle()
        secondaryHeadingStyle.paragraphSpacingBefore = 14
        secondaryHeadingStyle.paragraphSpacing = 14
        
        let codeStyle = NSMutableParagraphStyle()

        var paragraphStyles = StaticParagraphStyleCollection()
        paragraphStyles.body = bodyStyle
        paragraphStyles.code = codeStyle
        paragraphStyles.heading1 = heading1Style
        paragraphStyles.heading2 = secondaryHeadingStyle
        paragraphStyles.heading3 = secondaryHeadingStyle
        paragraphStyles.heading4 = secondaryHeadingStyle
        paragraphStyles.heading5 = secondaryHeadingStyle
        paragraphStyles.heading6 = secondaryHeadingStyle

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
        fonts.body = fonts.body.withSize(14)
        fonts.heading1 = fonts.heading1.withSize(26)
        fonts.heading2 = fonts.heading2.withSize(22)
        fonts.heading3 = fonts.heading3.withSize(18)
        fonts.heading4 = fonts.heading4.withSize(14)
        fonts.heading5 = NSFontManager.shared.convert(fonts.heading5.withSize(14), toHaveTrait: .italicFontMask)
        fonts.heading6 = NSFontManager.shared.convert(fonts.heading6.withSize(14), toHaveTrait: .italicFontMask)
        fonts.code = fonts.code.withSize(14)
        fonts.listItemPrefix = fonts.body
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
        colors.body = .labelColor
        colors.heading1 = .labelColor
        colors.heading2 = .labelColor
        colors.heading3 = .labelColor
        colors.code = .labelColor
        colors.link = .linkColor
        colors.listItemPrefix = .labelColor
        colors.quote = .labelColor
        colors.quoteStripe = .init(red: 0.933, green: 0.933, blue: 0.933, alpha: 1)
        colors.codeBlockBackground = .clear
        colors.thematicBreak = .init(red: 0.933, green: 0.933, blue: 0.933, alpha: 1)
        return colors
    }
}
