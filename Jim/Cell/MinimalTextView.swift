import AppKit

class MinimalTextView: NSTextView {
    var verticalPadding: CGFloat = 5
    
    var wraps = true {
        didSet {
            didSetWraps(wraps)
            // Only perform layout changes if the value actually changed
            if wraps != oldValue {
                // If we don't reset the container width it maintains the old width and wraps, despite
                // isHorizontallyResizable changing.
                textContainer?.size.width = .greatestFiniteMagnitude
                invalidateIntrinsicContentSize()
            }
        }
    }
    
    private func didSetWraps(_ wraps: Bool) {
        textContainer?.widthTracksTextView = wraps
        // Needed else horizontal scrollbar shows when the content doesn't overflow horizontally
        isHorizontallyResizable = !wraps
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
        
        didSetWraps(wraps)
    }
    
    public override var intrinsicContentSize: NSSize {
        guard let textContainer = textContainer,
              let layoutManager = layoutManager else {
            return .zero
        }
        layoutManager.ensureLayout(for: textContainer)
        let size = layoutManager.usedRect(for: textContainer).size
        return .init(width: wraps ? -1 : size.width + 2 * textContainerInset.width,
                     height: size.height + 2 * textContainerInset.height)
    }
    
    // I'm not sure why, but this is needed to correctly vertically size text views in the table
    override func resize(withOldSuperviewSize oldSize: NSSize) {
        invalidateIntrinsicContentSize()
        super.resize(withOldSuperviewSize: oldSize)
    }

}
