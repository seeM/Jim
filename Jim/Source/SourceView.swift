import Foundation
import CoreGraphics
import AppKit

public protocol sourceViewDelegate: AnyObject {

    func didChangeText(_ sourceView: SourceView)
    
    func didCommit(_ sourceView: SourceView)

    func textViewDidBeginEditing(_ sourceView: SourceView)

    func lexerForSource(_ source: String) -> Lexer
    
    func previousCell(_ sourceView: SourceView)
    
    func nextCell(_ sourceView: SourceView)

    func didBecomeFirstResponder(_ sourceView: SourceView)
    
    func endEditMode(_ sourceView: SourceView)
    
    func save()
}

// Provide default empty implementations of methods that are optional.
public extension sourceViewDelegate {
    func didChangeText(_ sourceView: SourceView) { }

    func textViewDidBeginEditing(_ sourceView: SourceView) { }
}

struct ThemeInfo {

    let theme: SourceCodeTheme

    /// Width of a space character in the theme's font.
    /// Useful for calculating tab indent size.
    let spaceWidth: CGFloat

}

public class SourceTextView: NSTextView {
    public override var intrinsicContentSize: NSSize {
        guard let textContainer = textContainer, let layoutManager = layoutManager else { return super.intrinsicContentSize }
        layoutManager.ensureLayout(for: textContainer)
        return layoutManager.usedRect(for: textContainer).size
    }
    
    public override func invalidateIntrinsicContentSize() {
        // TODO: needed?
        super.invalidateIntrinsicContentSize()
        enclosingScrollView?.invalidateIntrinsicContentSize()
    }

    public override func didChangeText() {
        super.didChangeText()
        invalidateIntrinsicContentSize()
    }
    
    public override func becomeFirstResponder() -> Bool {
        let sourceView = enclosingScrollView as! SourceView
        sourceView.delegate?.didBecomeFirstResponder(sourceView)
        return super.becomeFirstResponder()
    }
}

open class SourceView: NSScrollView {
    var uniqueUndoManager: UndoManager?
    let textView: SourceTextView

    public weak var delegate: sourceViewDelegate? {
        didSet {
            refreshColors()
        }
    }

    var ignoreShouldChange = false
    var padding = CGFloat(5)  // TODO: Ideally this should be passed in

    public var tintColor: NSColor! {
        set {
            textView.insertionPointColor = newValue
        }
        get {
            return textView.insertionPointColor
        }
    }
    
    public override init(frame: CGRect) {
        textView = SourceTextView(frame: .zero)
        super.init(frame: frame)
        setup()
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public var scrollView: NSScrollView { self }
    
    public override func scrollWheel(with event: NSEvent) {
        if abs(event.deltaX) < abs(event.deltaY) {
            super.nextResponder?.scrollWheel(with: event)
        } else {
            super.scrollWheel(with: event)
        }
    }

    private func setup() {
        scrollView.borderType = .noBorder
        scrollView.autohidesScrollers = true
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = true
        scrollView.horizontalScrollElasticity = .automatic
        scrollView.verticalScrollElasticity = .none

        scrollView.drawsBackground = true
//        scrollView.wantsLayer = true
//        scrollView.layer?.cornerRadius = 3
//        scrollView.layer?.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        textView.drawsBackground = false
        
        // Infinite max size text view and container + resizable text view allows for horizontal scrolling.
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.allowsUndo = true
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = true
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.heightTracksTextView = false
        textView.textContainer?.size = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.lineFragmentPadding = padding

        let textViewContainer = NSView()
        textViewContainer.addSubview(textView)

        scrollView.documentView = textViewContainer

        textViewContainer.translatesAutoresizingMaskIntoConstraints = false
        
        textView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textViewContainer.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            textViewContainer.trailingAnchor.constraint(greaterThanOrEqualTo: scrollView.contentView.trailingAnchor),
            textViewContainer.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            textViewContainer.bottomAnchor.constraint(equalTo: scrollView.contentView.bottomAnchor),

            textView.leadingAnchor.constraint(equalTo: textViewContainer.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: textViewContainer.trailingAnchor),
            textView.topAnchor.constraint(equalTo: textViewContainer.topAnchor, constant: padding),
            textView.bottomAnchor.constraint(equalTo: textViewContainer.bottomAnchor, constant: -padding),
        ])
        textView.setContentHuggingPriority(.required, for: .vertical)

        textView.delegate = self
    }

    @IBInspectable
    public var text: String {
        get {
            textView.string
        }
        set {
            textView.layer?.isOpaque = true
            textView.string = newValue
            textView.didChangeText()
            refreshColors()
        }
    }

    public func insertText(_ text: String) {
        if shouldChangeText(insertingText: text) {
            textView.insertText(text, replacementRange: textView.selectedRange())
        }
    }

    public var theme: SourceCodeTheme? {
        didSet {
            guard let theme = theme else {
                return
            }

            cachedThemeInfo = nil
            scrollView.backgroundColor = theme.backgroundColor
            textView.font = theme.font

            refreshColors()
        }
    }

    var cachedThemeInfo: ThemeInfo?

    var themeInfo: ThemeInfo? {
        if let cached = cachedThemeInfo {
            return cached
        }

        guard let theme = theme else {
            return nil
        }

        let spaceAttrString = NSAttributedString(string: " ", attributes: [.font: theme.font])
        let spaceWidth = spaceAttrString.size().width

        let info = ThemeInfo(theme: theme, spaceWidth: spaceWidth)

        cachedThemeInfo = info

        return info
    }

    var cachedTokens: [CachedToken]?

    func invalidateCachedTokens() {
        cachedTokens = nil
    }

    func colorTextView(lexerForSource: (String) -> Lexer) {
        guard cachedTokens == nil, let theme = self.theme, let themeInfo = self.themeInfo else { return }
        
        let source = textView.string
        let textStorage = textView.textStorage!
        
        textView.font = theme.font
        
        let lexer = lexerForSource(source)
        let tokens = lexer.getSavannaTokens(input: source)
        let cachedTokens = tokens.map { CachedToken(token: $0, nsRange: .init($0.range, in: source)) }
        self.cachedTokens = cachedTokens
        
        createAttributes(theme: theme, themeInfo: themeInfo, textStorage: textStorage, cachedTokens: cachedTokens, source: source)
    }

    func createAttributes(theme: SourceCodeTheme, themeInfo: ThemeInfo, textStorage: NSTextStorage, cachedTokens: [CachedToken], source: String) {

        // Buffer a series of changes to the receiver's characters or attributes
        textStorage.beginEditing()

        var attributes = [NSAttributedString.Key: Any]()

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.paragraphSpacing = 2.0
        paragraphStyle.defaultTabInterval = themeInfo.spaceWidth * 4
        paragraphStyle.tabStops = [] // TODO: What does this do?

        attributes[.paragraphStyle] = paragraphStyle

        for (attr, value) in theme.globalAttributes() {
            attributes[attr] = value
        }

        let wholeRange = NSRange(location: 0, length: source.count)
        textStorage.setAttributes(attributes, range: wholeRange)

        for cachedToken in cachedTokens {

            let token = cachedToken.token

            if token.isPlain {
                continue
            }

            let range = cachedToken.nsRange

            textStorage.addAttributes(theme.attributes(for: token), range: range)
        }

        textStorage.endEditing()
    }

}

extension SourceView {
    func didUpdateText() {
        refreshColors()
        delegate?.didChangeText(self)
    }
}

extension SourceView: NSTextViewDelegate {
    
    open func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
        let text = replacementString ?? ""
        return self.shouldChangeText(insertingText: text, shouldChangeTextIn: affectedCharRange)
    }

    open func textDidChange(_ notification: Notification) {
        guard let textView = notification.object as? NSTextView, textView == self.textView else { return }
        didUpdateText()
    }
    
    func refreshColors() {
        self.invalidateCachedTokens()
        
        if let delegate = delegate {
            colorTextView(lexerForSource: { (source) -> Lexer in
                return delegate.lexerForSource(source)
            })
        }
    }
    
    public func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        guard let event = NSApp.currentEvent else { return false }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if event.keyCode == 36 && flags == .shift {
            delegate?.didCommit(self)
            return true
        } else if event.keyCode == 125 {
            if textView.selectedRange().location == textView.string.count {
                delegate?.nextCell(self)
                return true
            }
        } else if event.keyCode == 126 {
            if textView.selectedRange().location == 0 {
                delegate?.previousCell(self)
                return true
            }
        } else if event.keyCode == 53 {
            delegate?.endEditMode(self)
            return true
        } else if event.keyCode == 1 && flags == .command {
            delegate?.save()
            return true
        }
        return false
    }
    
    public func undoManager(for view: NSTextView) -> UndoManager? {
        uniqueUndoManager
    }
}

extension SourceView {

    func shouldChangeText(insertingText: String, shouldChangeTextIn affectedCharRange: NSRange? = nil) -> Bool {
        if ignoreShouldChange { return true }

        let selectedRange = textView.selectedRange
        var location = selectedRange.lowerBound

        let origInsertingText = insertingText

        var insertingText = insertingText
        
        if insertingText == "" && affectedCharRange != nil {
            // TODO: Remove paired
        } else if insertingText == "\n" {
            
            let nsText = textView.string as NSString
            
            var currentLine = nsText.substring(with: nsText.lineRange(for: selectedRange))
            
            // Remove trailing newline to avoid adding it to newLinePrefix
            if currentLine.hasSuffix("\n") {
                currentLine.removeLast()
            }
            
            var newLinePrefix = ""
            
            for char in currentLine {
                
                let tempSet = CharacterSet(charactersIn: "\(char)")
                
                if tempSet.isSubset(of: .whitespacesAndNewlines) {
                    newLinePrefix += "\(char)"
                } else {
                    break
                }
                
            }
            
            insertingText += newLinePrefix
            
            // TODO: Implement auto indent
//            let suffixesToIndent = [":", "[", "("]
//            for s in suffixesToIndent {
//                if currentLine.hasSuffix(s) {
//                    insertingText += "    " // TODO: don't hardcode indent size
//                    break
//                }
//            }

            location += insertingText.count
        } else {
            // TODO: Implement smart paired chars
//            let pairedChars = ["[]", "()"]
//            // If the user is typing a character that has a pair, insert the pair and move the cursor in between
//            for pair in pairedChars {
//                if insertingText == pair.prefix(1) {
//                    insertingText += pair.dropFirst()
//                    location += 1
//                    break
//                }
//            }
        }
        
        if insertingText != origInsertingText {
            ignoreShouldChange = true
            textView.insertText(insertingText, replacementRange: selectedRange)
            ignoreShouldChange = false
            didUpdateText()
            return false
        }
        
        return true
    }
    
}
