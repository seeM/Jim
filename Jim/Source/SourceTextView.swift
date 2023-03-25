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
        allowsUndo = true
        
        // Needed else reused views may retain previous height
        isVerticallyResizable = true
        
        // Needed else horizontal scrollbar shows when the content doesn't overflow horizontally
        isHorizontallyResizable = true
    }

    // NOTE: We might need this to fix vertical size on table cell reuse
//    override func invalidateIntrinsicContentSize() {
//        super.invalidateIntrinsicContentSize()
//        enclosingScrollView?.invalidateIntrinsicContentSize()
//    }

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
