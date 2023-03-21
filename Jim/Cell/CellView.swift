import Cocoa

class CellViewModel {
    private let cell: Cell
    
    init(cell: Cell) {
        self.cell = cell
    }
}

class CellView: NSTableCellView {
    let sourceView = SourceView()
    let outputStackView = OutputStackView()
    var cell: Cell!
    var tableView: NotebookTableView!
    var row: Int { tableView.row(for: self) }
    var notebook: Notebook!
    let lexer = Python3Lexer()
    
    var viewModel: CellViewModel?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect); create()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder); create()
    }

    private func create() {
        let containerView = NSView()
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = .white
        containerView.layer?.masksToBounds = true
        containerView.layer?.cornerRadius = 5
        
        shadow = NSShadow()
        shadow?.shadowBlurRadius = 3
        shadow?.shadowOffset = .init(width: 0, height: -2)
        shadow?.shadowColor = .black.withAlphaComponent(0.2)
        
        outputStackView.wantsLayer = true
        outputStackView.layer?.backgroundColor = .white
        
        sourceView.theme = SourceCodeTheme.shared
        sourceView.delegate = self
        
        outputStackView.spacing = 0
        outputStackView.orientation = .vertical
        
        addSubview(containerView)
        containerView.addSubview(sourceView)
        containerView.addSubview(outputStackView)
        
        containerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])

        sourceView.translatesAutoresizingMaskIntoConstraints = false
        sourceView.setContentHuggingPriority(.required, for: .vertical)
        NSLayoutConstraint.activate([
            sourceView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            sourceView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            sourceView.topAnchor.constraint(equalTo: containerView.topAnchor),
        ])

        outputStackView.translatesAutoresizingMaskIntoConstraints = false
        outputStackView.setHuggingPriority(.required, for: .vertical)
        NSLayoutConstraint.activate([
            outputStackView.leadingAnchor.constraint(equalTo: sourceView.leadingAnchor),
            outputStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            outputStackView.topAnchor.constraint(equalTo: sourceView.bottomAnchor),
            outputStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        ])
    }
    
    func update(cell: Cell, tableView: NotebookTableView, notebook: Notebook, undoManager: UndoManager, with viewModel: CellViewModel) {
        // Store previous cell state
        // TODO: there must be a better pattern for this
        self.cell?.selectedRange = sourceView.textView.selectedRange()
        
        self.viewModel = viewModel
        
        self.cell = cell
        self.tableView = tableView
        self.notebook = notebook
        sourceView.uniqueUndoManager = undoManager
        sourceView.text = cell.source.value
        clearOutputs()
        if let outputs = cell.outputs {
            for output in outputs {
                appendOutputSubview(output)
            }
        }
        
        // Apply new cell state
        sourceView.textView.setSelectedRange(cell.selectedRange)
        setIsExecuting(cell, isExecuting: cell.isExecuting)
    }
    
    func clearOutputs() {
        for view in outputStackView.arrangedSubviews {
            outputStackView.removeArrangedSubview(view)
            NSLayoutConstraint.deactivate(view.constraints)
            view.removeFromSuperview()
        }
    }
    
    func appendOutputSubview(_ output: Output) {
        switch output {
        case .stream(let output): appendOutputTextSubview(output.text)
        case .displayData(let output):
            if let plainText = output.data.plainText { appendOutputTextSubview(plainText.value) }
            if let markdownText = output.data.markdownText { appendOutputTextSubview(markdownText.value) }
            if let htmlText = output.data.markdownText { appendOutputTextSubview(htmlText.value) }
            if let image = output.data.image { appendOutputImageSubview(image.value) }
        case .executeResult(let output):
            if let plainText = output.data.plainText { appendOutputTextSubview(plainText.value) }
            if let markdownText = output.data.markdownText { appendOutputTextSubview(markdownText.value) }
            if let htmlText = output.data.markdownText { appendOutputTextSubview(htmlText.value) }
            if let image = output.data.image { appendOutputImageSubview(image.value) }
        case .error(let output): appendOutputTextSubview(output.traceback.joined(separator: "\n"))
        }
    }
    
    func appendOutputTextSubview(_ text: String) {
        let textView = OutputTextView(cellView: self, verticalPadding: 5)
        textView.string = text.trimmingCharacters(in: Foundation.CharacterSet.whitespacesAndNewlines).replacing(/\[\d+[\d;]*m/, with: "")
        outputStackView.addArrangedSubview(textView)
    }
    
    func appendOutputImageSubview(_ image: NSImage) {
        let imageView = NSImageView(image: image)
        imageView.imageAlignment = .alignTopLeft
        outputStackView.addArrangedSubview(imageView)
    }
    
    func setIsExecuting(_ cell: Cell, isExecuting: Bool) {
        cell.isExecuting = isExecuting
        alphaValue = isExecuting ? 0.5 : 1.0
    }
    
    func runCell() {
        guard cell.cellType == .code else { return }
        let jupyter = JupyterService.shared
        notebook.dirty = true
        setIsExecuting(cell, isExecuting: true)

        clearOutputs()
        cell.outputs = []
        jupyter.webSocketSend(code: cell.source.value) { [row] msg in
            let cell = self.notebook.content.cells[row]
            switch msg.channel {
            case .iopub:
                var output: Output?
                switch msg.content {
                case .stream(let content):
                    output = .stream(content)
                case .executeResult(let content):
                    output = .executeResult(content)
                case .displayData(let content):
                    output = .displayData(content)
                case .error(let content):
                    output = .error(content)
                default: break
                }
                if let output {
                    Task.detached { @MainActor in
                        // TODO: feels hacky...
                        if cell == self.cell {
                            self.appendOutputSubview(output)
                        }
                    }
                    cell.outputs!.append(output)
                }
            case .shell:
                switch msg.content {
                case .executeReply(_):
                    Task.detached { @MainActor in
                        self.setIsExecuting(cell, isExecuting: false)
                    }
                default: break
                }
            }
        }
    }
}

extension CellView: sourceViewDelegate {
    func lexerForSource(_ source: String) -> Lexer {
        lexer
    }
    
    func didChangeText(_ sourceView: SourceView) {
        cell.source.value = sourceView.text
        notebook.dirty = true
    }
    
    func didCommit(_ sourceView: SourceView) {
        endEditMode(sourceView)
        tableView.runCellSelectBelow()
    }
    
    func previousCell(_ sourceView: SourceView) {
        if row == 0 { return }
        tableView.selectCellAbove()
        let textView = tableView.selectedCellView!.sourceView.textView
        textView.setSelectedRange(NSRange(location: textView.string.count, length: 0))
    }
    
    func nextCell(_ sourceView: SourceView) {
        if row == tableView.numberOfRows - 1 { return }
        tableView.selectCellBelow()
        let textView = tableView.selectedCellView!.sourceView.textView
        textView.setSelectedRange(NSRange(location: 0, length: 0))
    }
    
    func didBecomeFirstResponder(_ sourceView: SourceView) {
        tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
    }
    
    func endEditMode(_ sourceView: SourceView) {
        window?.makeFirstResponder(tableView)
    }
    
    func save() {
        tableView.notebookDelegate?.save()
    }
}
