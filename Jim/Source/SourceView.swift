import Foundation
import CoreGraphics
import AppKit

public protocol SourceViewDelegate: AnyObject {

    func didChangeText(_ sourceView: SourceView)
    
    func didCommit(_ sourceView: SourceView)
    
    func previousCell(_ sourceView: SourceView)
    
    func nextCell(_ sourceView: SourceView)

    func didBecomeFirstResponder(_ sourceView: SourceView)
    
    func endEditMode(_ sourceView: SourceView)
    
    func save()
}

open class SourceView: NSScrollView {
    var uniqueUndoManager: UndoManager?
    let textView: SourceTextView
    
    public weak var delegate: SourceViewDelegate?
    
    var ignoreShouldChange = false
    var padding = CGFloat(5)  // TODO: Ideally this should be passed in
    
    public var theme: Theme?
    
    public override init(frame: CGRect) {
        textView = SourceTextView()
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
        _ = textView.layoutManager
        scrollView.borderType = .noBorder
        scrollView.autohidesScrollers = true
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = true
        scrollView.horizontalScrollElasticity = .automatic
        scrollView.verticalScrollElasticity = .none
        
        scrollView.drawsBackground = true
        scrollView.backgroundColor = Theme.shared.backgroundColor
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
        
        // TODO: Create my own textview base class?
        textView.usesFontPanel = false
        textView.isRichText = false
        textView.smartInsertDeleteEnabled = false
        textView.isAutomaticTextCompletionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.allowsCharacterPickerTouchBarItem = false
        
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
}

extension SourceView: NSTextViewDelegate {
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
