import AppKit

class MinimalTextView: NSTextView {
    var verticalPadding: CGFloat = 5
    
    private var frameObservation: NSKeyValueObservation?
    
    private(set) var wraps = true
    
    func setWraps(_ wraps: Bool, invalidate: Bool = true) {
        textContainer?.widthTracksTextView = wraps
        // Needed else horizontal scrollbar shows when the content doesn't overflow horizontally
        isHorizontallyResizable = !wraps
        // Only perform layout changes if the value actually changed
        if invalidate && wraps != self.wraps {
            // If we don't reset the container width it maintains the old width and wraps, despite
            // isHorizontallyResizable changing.
            if !wraps {
                textContainer?.size.width = .greatestFiniteMagnitude
            }
            invalidateIntrinsicContentSize()
        }
        self.wraps = wraps
    }
    
    init() {
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer()
        textStorage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)
        super.init(frame: .zero, textContainer: textContainer)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private var cachedIntrinsicContentSize = NSSize.zero
    
    private func setup() {
        _ = layoutManager  // Force TextKit 1
        
        usesFontPanel = false
        isRichText = false
        smartInsertDeleteEnabled = false
        isAutomaticTextCompletionEnabled = false
        isAutomaticTextReplacementEnabled = false
        isAutomaticSpellingCorrectionEnabled = false
        isAutomaticQuoteSubstitutionEnabled = false
        allowsCharacterPickerTouchBarItem = false
        
        textContainerInset.height = verticalPadding
        
        // Needed else reused views may retain previous height
        isVerticallyResizable = true
        
        setWraps(wraps, invalidate: false)

        frameObservation = observe(\.frame) { [weak self] (_, _) in
            self?.invalidateIntrinsicContentSize()
        }
    }

    public override var intrinsicContentSize: NSSize {
        guard let textContainer = textContainer,
              let layoutManager = layoutManager else {
            fatalError("Expected textContainer and layoutManager to exist.")
        }
        layoutManager.ensureLayout(for: textContainer)
        let size = layoutManager.usedRect(for: textContainer).size
        return NSSize(width: wraps ? -1 : size.width + 2 * textContainerInset.width,
                      height: size.height + 2 * textContainerInset.height)
    }
    
    override func didChangeText() {
        super.didChangeText()
        invalidateIntrinsicContentSize()
    }
}
