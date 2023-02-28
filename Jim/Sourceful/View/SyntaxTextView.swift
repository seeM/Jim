//
//  SyntaxTextView.swift
//  SavannaKit
//
//  Created by Louis D'hauwe on 23/01/2017.
//  Copyright © 2017 Silver Fox. All rights reserved.
//

import Foundation
import CoreGraphics
import AppKit

public protocol SyntaxTextViewDelegate: AnyObject {

    func didChangeText(_ syntaxTextView: SyntaxTextView)
    
    func didCommit(_ syntaxTextView: SyntaxTextView)

    func textViewDidBeginEditing(_ syntaxTextView: SyntaxTextView)

    func lexerForSource(_ source: String) -> Lexer

}

// Provide default empty implementations of methods that are optional.
public extension SyntaxTextViewDelegate {
    func didChangeText(_ syntaxTextView: SyntaxTextView) { }

    func textViewDidBeginEditing(_ syntaxTextView: SyntaxTextView) { }
}

struct ThemeInfo {

    let theme: SyntaxColorTheme

    /// Width of a space character in the theme's font.
    /// Useful for calculating tab indent size.
    let spaceWidth: CGFloat

}

public class HuggingTextView: NSTextView {
    public override var intrinsicContentSize: NSSize {
        guard let textContainer = textContainer, let layoutManager = layoutManager else { return super.intrinsicContentSize }
        layoutManager.ensureLayout(for: textContainer)
        return layoutManager.usedRect(for: textContainer).size
    }

    public override func didChangeText() {
        super.didChangeText()
        invalidateIntrinsicContentSize()
        enclosingScrollView?.invalidateIntrinsicContentSize()
    }
}


public class CellScrollView: NSScrollView {
    override public init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }

    public override func scrollWheel(with event: NSEvent) {
        if abs(event.deltaX) < abs(event.deltaY) {
            super.nextResponder?.scrollWheel(with: event)
        } else {
            super.scrollWheel(with: event)
        }
    }
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

@IBDesignable
open class SyntaxTextView: NSView {

    var previousSelectedRange: NSRange?

    private var textViewSelectedRangeObserver: NSKeyValueObservation?

    let textView: HuggingTextView

    public weak var delegate: SyntaxTextViewDelegate? {
        didSet {
            refreshColors()
        }
    }

    var ignoreSelectionChange = false
    var ignoreShouldChange = false

    public var tintColor: NSColor! {
        set {
            textView.insertionPointColor = newValue
        }
        get {
            return textView.insertionPointColor
        }
    }
    
    public override init(frame: CGRect) {
        textView = SyntaxTextView.createInnerTextView()
        super.init(frame: frame)
        setup()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        textView = SyntaxTextView.createInnerTextView()
        super.init(coder: aDecoder)
        setup()
    }

    private static func createInnerTextView() -> HuggingTextView {
        // We'll set the container size and text view frame later
        return HuggingTextView(frame: .zero)
    }

    public let scrollView = CellScrollView()

    private func setup() {
        addSubview(scrollView)
        
        scrollView.borderType = .lineBorder
        scrollView.autohidesScrollers = true
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = true
        scrollView.horizontalScrollElasticity = .automatic
        scrollView.verticalScrollElasticity = .none

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.topAnchor.constraint(equalTo: topAnchor).isActive = true
        scrollView.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        scrollView.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        scrollView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true

        scrollView.drawsBackground = true
        scrollView.wantsLayer = true
        scrollView.layer?.cornerRadius = 3
        textView.drawsBackground = false
        
        // Infinite max size text view and container + resizable text view allows for horizontal scrolling.
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.allowsUndo = true
        textView.minSize = NSSize(width: 0, height: scrollView.bounds.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = true
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.heightTracksTextView = false
        textView.textContainer?.size = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        let textViewContainer = NSView()
        textViewContainer.addSubview(textView)

        scrollView.documentView = textViewContainer

        textViewContainer.translatesAutoresizingMaskIntoConstraints = false
        textViewContainer.translatesAutoresizingMaskIntoConstraints = false
        textViewContainer.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor).isActive = true
        textViewContainer.trailingAnchor.constraint(greaterThanOrEqualTo: scrollView.contentView.trailingAnchor).isActive = true
        textViewContainer.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor).isActive = true
        textViewContainer.bottomAnchor.constraint(equalTo: scrollView.contentView.bottomAnchor).isActive = true

        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.leadingAnchor.constraint(equalTo: textViewContainer.leadingAnchor).isActive = true
        textView.trailingAnchor.constraint(equalTo: textViewContainer.trailingAnchor).isActive = true
        textView.topAnchor.constraint(equalTo: textViewContainer.topAnchor, constant: 5).isActive = true
        textView.bottomAnchor.constraint(equalTo: textViewContainer.bottomAnchor, constant: -5).isActive = true

        textView.delegate = self
    }

    @IBInspectable
    public var text: String {
        get {
            return textView.string
        }
        set {
            textView.layer?.isOpaque = true
            textView.string = newValue
            refreshColors()
        }
    }

    public func insertText(_ text: String) {
        if shouldChangeText(insertingText: text) {
            textView.insertText(text, replacementRange: textView.selectedRange())
        }
    }

    public var theme: SyntaxColorTheme? {
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
        let cachedTokens = tokens.map { CachedToken(token: $0, nsRange: source.nsRange(fromRange: $0.range)) }
        self.cachedTokens = cachedTokens
        
        createAttributes(theme: theme, themeInfo: themeInfo, textStorage: textStorage, cachedTokens: cachedTokens, source: source)
    }

    func createAttributes(theme: SyntaxColorTheme, themeInfo: ThemeInfo, textStorage: NSTextStorage, cachedTokens: [CachedToken], source: String) {

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
