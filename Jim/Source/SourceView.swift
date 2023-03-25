import Foundation
import CoreGraphics
import AppKit

protocol SourceViewDelegate: AnyObject {

    func didChangeText(_ sourceView: SourceView)
    
    func didCommit(_ sourceView: SourceView)
    
    func previousCell(_ sourceView: SourceView)
    
    func nextCell(_ sourceView: SourceView)

    func didBecomeFirstResponder(_ sourceView: SourceView)
    
    func endEditMode(_ sourceView: SourceView)
    
    func save()
}

class SourceView: NSScrollView {
    var uniqueUndoManager: UndoManager?
    let textView: SourceTextView
    
    
    weak var delegate: SourceViewDelegate?
    
    override init(frame: CGRect) {
        textView = SourceTextView()
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setup() {
        _ = textView.layoutManager
        borderType = .noBorder
        autohidesScrollers = true
        hasVerticalScroller = false
        hasHorizontalScroller = true
        horizontalScrollElasticity = .automatic
        verticalScrollElasticity = .none
        
        drawsBackground = true
        backgroundColor = Theme.shared.backgroundColor
        //        wantsLayer = true
        //        layer?.cornerRadius = 3
        //        layer?.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
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
        
        documentView = textViewContainer
        
        textViewContainer.translatesAutoresizingMaskIntoConstraints = false
        
        textView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textViewContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            textViewContainer.trailingAnchor.constraint(greaterThanOrEqualTo: contentView.trailingAnchor),
            textViewContainer.topAnchor.constraint(equalTo: contentView.topAnchor),
            textViewContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            textView.leadingAnchor.constraint(equalTo: textViewContainer.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: textViewContainer.trailingAnchor),
            textView.topAnchor.constraint(equalTo: textViewContainer.topAnchor, constant: 5),
            textView.bottomAnchor.constraint(equalTo: textViewContainer.bottomAnchor, constant: -5),
        ])
        textView.setContentHuggingPriority(.required, for: .vertical)
        
        textView.delegate = self
    }
    
    override func scrollWheel(with event: NSEvent) {
        if abs(event.deltaX) < abs(event.deltaY) {
            super.nextResponder?.scrollWheel(with: event)
        } else {
            super.scrollWheel(with: event)
        }
    }
}

extension SourceView: NSTextViewDelegate {
    func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
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
    
    func undoManager(for view: NSTextView) -> UndoManager? {
        uniqueUndoManager
    }
    
    public func textDidChange(_ notification: Notification) {
        guard let textView = notification.object as? SourceTextView, textView == self.textView else { return }
        delegate?.didChangeText(self)
    }
}
