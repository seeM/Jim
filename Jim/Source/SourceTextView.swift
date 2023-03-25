import AppKit

class SourceTextView: MinimalTextView {
    override init() {
        super.init()
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        font = Theme.shared.font
        
        drawsBackground = false
        // Infinite max size text view and container + resizable text view allows for horizontal scrolling.
        allowsUndo = true
        minSize = NSSize(width: 0, height: 0)
        maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        isVerticallyResizable = true
        isHorizontallyResizable = true
        textContainer?.widthTracksTextView = false
        textContainer?.heightTracksTextView = false
        textContainer?.size = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
    }

    override func invalidateIntrinsicContentSize() {
        // TODO: needed?
        super.invalidateIntrinsicContentSize()
        enclosingScrollView?.invalidateIntrinsicContentSize()
    }

    override func didChangeText() {
        super.didChangeText()
        invalidateIntrinsicContentSize()
    }
    
    override func becomeFirstResponder() -> Bool {
        let sourceView = enclosingScrollView as! SourceView
        sourceView.delegate?.didBecomeFirstResponder(sourceView)
        return super.becomeFirstResponder()
    }
}
