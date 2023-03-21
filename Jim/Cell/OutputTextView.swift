import Cocoa

class OutputTextView: NSTextView {
    var cellView: CellView
    
    init(cellView: CellView, verticalPadding: CGFloat) {
        self.cellView = cellView

        let textContentStorage = NSTextContentStorage()
        let textLayoutManager = NSTextLayoutManager()
        let textContainer = NSTextContainer()
        textContentStorage.addTextLayoutManager(textLayoutManager)
        textLayoutManager.textContainer = textContainer
        
        super.init(frame: .zero, textContainer: textContainer)
        
        font = JimSourceCodeTheme.shared.font
        drawsBackground = false
        isEditable = false
        textContainerInset = .init(width: 0, height: verticalPadding)
        
        // Horizontally fixed with wrapping, vertically fitting content
        minSize = .zero
        maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        isVerticallyResizable = true
        isHorizontallyResizable = false
        textContainer.widthTracksTextView = true
        textContainer.heightTracksTextView = false
        textContainer.size.height = CGFloat.greatestFiniteMagnitude
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override var intrinsicContentSize: NSSize {
        guard let textContainer = textContainer,
              let layoutManager = layoutManager else {
            return super.intrinsicContentSize
        }
        layoutManager.ensureLayout(for: textContainer)
        let size = layoutManager.usedRect(for: textContainer).size
        return .init(width: -1, height: size.height + 2 * textContainerInset.height)
    }
    
    override func resize(withOldSuperviewSize oldSize: NSSize) {
        invalidateIntrinsicContentSize()
        super.resize(withOldSuperviewSize: oldSize)
    }
    
    override func keyDown(with event: NSEvent) {
        nextResponder?.keyDown(with: event)
    }
    
    override func becomeFirstResponder() -> Bool {
        cellView.tableView!.selectRowIndexes(IndexSet(integer: cellView.row), byExtendingSelection: false)
        return super.becomeFirstResponder()
    }
}
