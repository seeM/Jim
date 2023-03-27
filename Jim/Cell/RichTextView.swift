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
        
        textContainer?.widthTracksTextView = true
        textContainer?.heightTracksTextView = false
    }
    
    public override var intrinsicContentSize: NSSize {
        NSSize(width: -1, height: super.intrinsicContentSize.height)
    }
    
    override func resize(withOldSuperviewSize oldSize: NSSize) {
        invalidateIntrinsicContentSize()
        super.resize(withOldSuperviewSize: oldSize)
    }
    
//    override func keyDown(with event: NSEvent) {
//        nextResponder?.keyDown(with: event)
//    }
    
//    override func becomeFirstResponder() -> Bool {
//        customDelegate?.didBecomeFirstResponder(self)
//        return super.becomeFirstResponder()
//    }
}
