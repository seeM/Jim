import AppKit

class SourceTextView: MinimalTextView {
    override var isOpaque: Bool { true }
    
    override init() {
        super.init()
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        font = Theme.shared.monoFont
        drawsBackground = true
        backgroundColor = Theme.shared.backgroundColor
        allowsUndo = true
        setWraps(false, invalidate: false)
    }

    // NOTE: We might need this to fix vertical size on table cell reuse
    override func invalidateIntrinsicContentSize() {
        super.invalidateIntrinsicContentSize()
        enclosingScrollView?.invalidateIntrinsicContentSize()
    }
    
    override func becomeFirstResponder() -> Bool {
        let sourceView = enclosingScrollView as! SourceView
        sourceView.delegate?.didBecomeFirstResponder(sourceView)
        return super.becomeFirstResponder()
    }
}
