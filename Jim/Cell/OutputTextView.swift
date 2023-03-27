import Cocoa

protocol OutputTextViewDelegate {
    func didBecomeFirstResponder(_ textView: OutputTextView)
}

class OutputTextView: MinimalTextView {
    override var isOpaque: Bool { true }
    
    var customDelegate: OutputTextViewDelegate?
    
    override init() {
        super.init()
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        textContainer?.widthTracksTextView = true
        textContainer?.heightTracksTextView = false
        font = Theme.shared.monoFont
        drawsBackground = true
        backgroundColor = .white
        isEditable = false
        
        // NOTE: We might need this if layout has bugs
//        isVerticallyResizable = true
//        isHorizontallyResizable = false
    }
    
    public override var intrinsicContentSize: NSSize {
        NSSize(width: -1, height: super.intrinsicContentSize.height)
    }
    
    override func resize(withOldSuperviewSize oldSize: NSSize) {
        invalidateIntrinsicContentSize()
        super.resize(withOldSuperviewSize: oldSize)
    }
    
    override func keyDown(with event: NSEvent) {
        nextResponder?.keyDown(with: event)
    }
    
    override func becomeFirstResponder() -> Bool {
        customDelegate?.didBecomeFirstResponder(self)
        return super.becomeFirstResponder()
    }
}
