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
        font = Theme.shared.monoFont
        drawsBackground = true
        backgroundColor = .white
        isEditable = false
    }
    
    override func keyDown(with event: NSEvent) {
        nextResponder?.keyDown(with: event)
    }
    
    override func becomeFirstResponder() -> Bool {
        customDelegate?.didBecomeFirstResponder(self)
        return super.becomeFirstResponder()
    }
}
