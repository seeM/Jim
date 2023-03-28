import AppKit

protocol RichTextViewDelegate {
    func didBecomeFirstResponder(_ textView: RichTextView)
}

class RichTextView: MinimalTextView {
    override var isOpaque: Bool { false }
    
    var customDelegate: RichTextViewDelegate?
    
    override init() {
        super.init()
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        isEditable = false
        isRichText = true
        font = Theme.shared.font
    }
    
    override func keyDown(with event: NSEvent) {
        nextResponder?.keyDown(with: event)
    }
    
    override func becomeFirstResponder() -> Bool {
        customDelegate?.didBecomeFirstResponder(self)
        return super.becomeFirstResponder()
    }
}
