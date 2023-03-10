import Cocoa

class StackView: NSStackView {
//    override func draw(_ dirtyRect: NSRect) {
//        super.draw(dirtyRect)
//        NSColor.red.setStroke()
//        NSBezierPath(rect: bounds).stroke()
//    }
    override func addArrangedSubview(_ view: NSView) {
        super.addArrangedSubview(view)
        view.widthAnchor.constraint(equalTo: widthAnchor).isActive = true
        view.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        view.setContentHuggingPriority(.required, for: .vertical)
    }
}

class OutputTextView: NSTextView {
    public override var intrinsicContentSize: NSSize {
        guard let textContainer = textContainer, let layoutManager = layoutManager else { return super.intrinsicContentSize }
        layoutManager.ensureLayout(for: textContainer)
        return NSSize(width: -1, height: layoutManager.usedRect(for: textContainer).size.height)
    }
    
    override func resize(withOldSuperviewSize oldSize: NSSize) {
        invalidateIntrinsicContentSize()
        super.resize(withOldSuperviewSize: oldSize)
    }
}

class NotebookTableCell: NSTableCellView {
    let syntaxTextView = SyntaxTextView()
    let outputStackView = StackView()
    var cell: Cell!
    var tableView: NotebookTableView!
    var row: Int { tableView.row(for: self) }
    var notebook: Notebook!
    
    let lexer = Python3Lexer()
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect); create()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder); create()
    }
    
    private func create() {
        addSubview(syntaxTextView)

        syntaxTextView.translatesAutoresizingMaskIntoConstraints = false
        syntaxTextView.setContentHuggingPriority(.required, for: .vertical)
        syntaxTextView.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        syntaxTextView.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        syntaxTextView.topAnchor.constraint(equalTo: topAnchor).isActive = true
        
        syntaxTextView.theme = JimSourceCodeTheme.shared
        syntaxTextView.delegate = self
        
        addSubview(outputStackView)

        outputStackView.translatesAutoresizingMaskIntoConstraints = false
        outputStackView.setHuggingPriority(.required, for: .vertical)
        outputStackView.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        outputStackView.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        outputStackView.topAnchor.constraint(equalTo: syntaxTextView.bottomAnchor).isActive = true
        outputStackView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        
        outputStackView.spacing = 0
        outputStackView.orientation = .vertical
    }
    
    func updateOutputs() {
        for view in outputStackView.arrangedSubviews {
//            outputStackView.removeArrangedSubview(view)
//            NSLayoutConstraint.deactivate(view.constraints)
            view.removeFromSuperview()
        }

        // TODO: Add one output at a time, as it streams in
        guard let outputs = cell.outputs else { return }
        for output in outputs {
            switch output {
            case .stream(let output): addText(output.text)
            case .displayData(let output):
                if let plainText = output.data.plainText { addText(plainText.value) }
                if let markdownText = output.data.markdownText { addText(markdownText.value) }
                if let image = output.data.image { addImage(image.value) }
            case .executeResult(let output):
                if let plainText = output.data.plainText { addText(plainText.value) }
                if let markdownText = output.data.markdownText { addText(markdownText.value) }
                if let image = output.data.image { addImage(image.value) }
            case .error(let output): addText(output.traceback.joined(separator: "\n"))
            }
        }
    }
    
    // TODO: make reuseable views?
    func addText(_ text: String) {
        let string = text.trimmingCharacters(in: Foundation.CharacterSet.whitespacesAndNewlines)
        // TODO: Extract class?
        let textView = OutputTextView()
        textView.drawsBackground = false
        textView.minSize = .zero
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false
        textView.textContainer?.size.height = CGFloat.greatestFiniteMagnitude
        textView.isEditable = false
        textView.string = string
        outputStackView.addArrangedSubview(textView)
    }
    
    func addImage(_ image: NSImage) {
        let imageView = NSImageView(image: image)
        imageView.imageAlignment = .alignTopLeft
        outputStackView.addArrangedSubview(imageView)
    }
    
    func update(cell: Cell, tableView: NotebookTableView, notebook: Notebook, undoManager: UndoManager) {
        self.cell = cell
        self.tableView = tableView
        self.notebook = notebook
        syntaxTextView.uniqueUndoManager = undoManager
        syntaxTextView.text = cell.source.value
        updateOutputs()
    }
    
    func runCell() {
        let jupyter = JupyterService.shared
        cell.outputs = []
        jupyter.webSocketSend(code: cell.source.value) { msg in
            switch msg.channel {
            case .iopub:
                switch msg.content {
                case .stream(let content): self.cell.outputs!.append(.stream(content))
                case .executeResult(let content): self.cell.outputs!.append(.executeResult(content))
                case .displayData(let content): self.cell.outputs!.append(.displayData(content))
                case .error(let content): self.cell.outputs!.append(.error(content))
                default: break
                }
            case .shell: break
            }
            Task.detached { @MainActor in
                self.updateOutputs()
            }
        }
    }
}

extension NotebookTableCell: SyntaxTextViewDelegate {
    func lexerForSource(_ source: String) -> Lexer {
        lexer
    }
    
    func didChangeText(_ syntaxTextView: SyntaxTextView) {
        cell.source.value = syntaxTextView.text
    }
    
    func didCommit(_ syntaxTextView: SyntaxTextView) {
        endEditMode(syntaxTextView)
        tableView.runCellSelectBelow()
    }
    
    func previousCell(_ syntaxTextView: SyntaxTextView) {
        if row == 0 { return }
        tableView.selectCellAbove()
        let textView = tableView.selectedCellView!.syntaxTextView.textView
        textView.setSelectedRange(NSRange(location: textView.string.count, length: 0))
    }
    
    func nextCell(_ syntaxTextView: SyntaxTextView) {
        if row == tableView.numberOfRows - 1 { return }
        tableView.selectCellBelow()
        let textView = tableView.selectedCellView!.syntaxTextView.textView
        textView.setSelectedRange(NSRange(location: 0, length: 0))
    }
    
    func didBecomeFirstResponder(_ syntaxTextView: SyntaxTextView) {
        tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
    }
    
    func endEditMode(_ syntaxTextView: SyntaxTextView) {
        window?.makeFirstResponder(tableView)
    }
    
    func save() {
        tableView.notebookDelegate?.save()
    }
}
