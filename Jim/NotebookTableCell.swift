import Cocoa

class StackView: NSStackView {
    override func addArrangedSubview(_ view: NSView) {
        super.addArrangedSubview(view)
        view.widthAnchor.constraint(equalTo: widthAnchor).isActive = true
        view.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
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

class NotebookTableCell: NSTableCellView, SyntaxTextViewDelegate {
    var stackView: NSStackView!
    var outputStackView: NSStackView!
    var cell: Cell!
    var tableView: NSTableView!
    var row: Int!
    
    let lexer = Python3Lexer()
    
    func lexerForSource(_ source: String) -> Lexer {
        lexer
    }
    
    func updateOutputs() {
        // TODO: Add one output at a time, as it streams in
        for view in outputStackView.arrangedSubviews {
            view.removeFromSuperview()
        }
        guard let outputs = cell.outputs else { return }
        for output in outputs {
            switch output {
            case .stream(let output): addText(output.text)
            case .displayData(let output):
                if let text = output.data.text { addText(text.value) }
                if let image = output.data.image { addImage(image.value) }
            case .executeResult(let output):
                if let text = output.data.text { addText(text.value) }
                if let image = output.data.image { addImage(image.value) }
            case .error(let output): addText(output.traceback.joined(separator: "\n"))
            }
        }
    }
    
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
    
    func update(cell: Cell, row: Int, tableView: NSTableView) {
        self.cell = cell
        self.row = row
        self.tableView = tableView
        
        stackView = StackView()
        stackView.orientation = .vertical
        stackView.distribution = .gravityAreas
        addSubview(stackView)
        
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        stackView.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        stackView.topAnchor.constraint(equalTo: topAnchor).isActive = true
        stackView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        
        let syntaxTextView = SyntaxTextView()
        syntaxTextView.text = cell.source.value
        syntaxTextView.theme = JimSourceCodeTheme()
        syntaxTextView.delegate = self
        stackView.addArrangedSubview(syntaxTextView)
        
        outputStackView = StackView()
        outputStackView.orientation = .vertical
        outputStackView.distribution = .gravityAreas
        stackView.addArrangedSubview(outputStackView)
        
        updateOutputs()
    }
    
    func didChangeText(_ syntaxTextView: SyntaxTextView) {
        cell.source.value = syntaxTextView.text
    }
    
    func didCommit(_ syntaxTextView: SyntaxTextView) {
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
