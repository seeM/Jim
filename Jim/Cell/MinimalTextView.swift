import AppKit

class MinimalTextView: NSTextView {
    var verticalPadding: CGFloat = 5
    
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
    }
    
    public override var intrinsicContentSize: NSSize {
        guard let textContainer = textContainer,
              let layoutManager = layoutManager else {
            return .zero
        }
        layoutManager.ensureLayout(for: textContainer)
        let size = layoutManager.usedRect(for: textContainer).size
        return .init(width: size.width + 2 * textContainerInset.width, height: size.height + 2 * textContainerInset.height)
    }
}
