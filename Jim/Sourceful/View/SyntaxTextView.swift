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

    func didChangeSelectedRange(_ syntaxTextView: SyntaxTextView, selectedRange: NSRange)

    func textViewDidBeginEditing(_ syntaxTextView: SyntaxTextView)

    func lexerForSource(_ source: String) -> Lexer

}

// Provide default empty implementations of methods that are optional.
public extension SyntaxTextViewDelegate {
    func didChangeText(_ syntaxTextView: SyntaxTextView) { }

    func didChangeSelectedRange(_ syntaxTextView: SyntaxTextView, selectedRange: NSRange) { }

    func textViewDidBeginEditing(_ syntaxTextView: SyntaxTextView) { }
}

struct ThemeInfo {

    let theme: SyntaxColorTheme

    /// Width of a space character in the theme's font.
    /// Useful for calculating tab indent size.
    let spaceWidth: CGFloat

}

public class CellScrollView: NSScrollView {
    public override func scrollWheel(with event: NSEvent) {
        if abs(event.deltaX) < abs(event.deltaY) {
            super.nextResponder?.scrollWheel(with: event)
        } else {
            super.scrollWheel(with: event)
        }
    }
}

@IBDesignable
open class SyntaxTextView: NSView {

    var previousSelectedRange: NSRange?

    private var textViewSelectedRangeObserver: NSKeyValueObservation?

    let textView: NSTextView

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

    private static func createInnerTextView() -> NSTextView {
        // We'll set the container size and text view frame later
        return NSTextView(frame: .zero)
    }

    public let scrollView = CellScrollView()

    private func setup() {

        addSubview(scrollView)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
        scrollView.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
        scrollView.leadingAnchor.constraint(equalTo: self.leadingAnchor).isActive = true
        scrollView.trailingAnchor.constraint(equalTo: self.trailingAnchor).isActive = true

        scrollView.hasVerticalScroller = false
        scrollView.verticalScrollElasticity = .none

        scrollView.documentView = textView
        
        // Using the scroll view's background is better than the text view's since we want the rounded background
        // to stay rounded even while scrolling.
        scrollView.drawsBackground = true
        scrollView.wantsLayer = true
        scrollView.layer?.cornerRadius = 7
        textView.backgroundColor = .clear
        
        // Infinite max size text view and container + resizable text view allows for horizontal scrolling.
        // Height is currently controlled by the table view.
        textView.textContainer?.size = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.minSize = NSSize(width: 0.0, height: self.bounds.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = true
        textView.isEditable = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.allowsUndo = true

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
        paragraphStyle.paragraphSpacing = 2.0 // TODO: This might be why the tableView doesn't correctly estimate the height
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
