import AppKit

class SourceTextView: MinimalTextView {
    override init() {
        super.init()
        font = Theme.shared.font
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
