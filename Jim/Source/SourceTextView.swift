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
