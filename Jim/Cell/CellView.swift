import Cocoa
import Combine

class CellView: NSTableCellView {
    let sourceView = SourceView()
    let outputStackView = OutputStackView()
    var tableView: NotebookTableView!
    var row: Int { tableView.row(for: self) }
    let lexer = Python3Lexer()
    
    var viewModel: CellViewModel!
    private var isExecutingCancellable: AnyCancellable?
    
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
        sourceView.translatesAutoresizingMaskIntoConstraints = false
        outputStackView.translatesAutoresizingMaskIntoConstraints = false
        
        sourceView.setContentHuggingPriority(.required, for: .vertical)
        outputStackView.setHuggingPriority(.required, for: .vertical)
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            
            sourceView.topAnchor.constraint(equalTo: containerView.topAnchor),
            sourceView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            sourceView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            
            outputStackView.topAnchor.constraint(equalTo: sourceView.bottomAnchor),
            outputStackView.leadingAnchor.constraint(equalTo: sourceView.leadingAnchor),
            outputStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            outputStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
    }
    
    func update(with viewModel: CellViewModel, tableView: NotebookTableView) {
        // Store previous cell state
        // TODO: there must be a better pattern for this
        self.viewModel?.selectedRange = sourceView.textView.selectedRange()
        
        isExecutingCancellable = viewModel.$isExecuting
            .sink { [weak self] isExecuting in
                self?.alphaValue = isExecuting ? 0.5 : 1.0
            }
        
        self.tableView = tableView
        self.viewModel = viewModel
        sourceView.uniqueUndoManager = viewModel.undoManager
        sourceView.text = viewModel.source
        sourceView.textView.setSelectedRange(viewModel.selectedRange)
        clearOutputs()
        if let outputs = viewModel.cell.outputs {
            for output in outputs {
                appendOutputSubview(output)
            }
        }
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
            if let image = output.data.image { appendOutputImageSubview(image.value) }
            else if let htmlText = output.data.markdownText { appendOutputTextSubview(htmlText.value) }
            else if let markdownText = output.data.markdownText { appendOutputTextSubview(markdownText.value) }
            else if let plainText = output.data.plainText { appendOutputTextSubview(plainText.value) }
        case .executeResult(let output):
            if let image = output.data.image { appendOutputImageSubview(image.value) }
            else if let htmlText = output.data.markdownText { appendOutputTextSubview(htmlText.value) }
            else if let markdownText = output.data.markdownText { appendOutputTextSubview(markdownText.value) }
            else if let plainText = output.data.plainText { appendOutputTextSubview(plainText.value) }
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
    
    func runCell() {
        guard viewModel.cell.cellType == .code else { return }
        viewModel.notebookViewModel.notebook.dirty = true
        viewModel.isExecuting = true

        clearOutputs()
        viewModel.cell.outputs = []
        JupyterService.shared.webSocketSend(code: viewModel.cell.source.value) { [viewModel] msg in
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
                        if viewModel!.cell == self.viewModel.cell {
                            self.appendOutputSubview(output)
                        }
                    }
                    viewModel!.cell.outputs!.append(output)
                }
            case .shell:
                switch msg.content {
                case .executeReply(_):
                    Task.detached { @MainActor in
                        viewModel?.isExecuting = false
                    }
                default: break
                }
            }
        }
    }
}

extension CellView: SourceViewDelegate {
    func lexerForSource(_ source: String) -> Lexer {
        lexer
    }
    
    func didChangeText(_ sourceView: SourceView) {
        viewModel.source = sourceView.text
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
        tableView.save()
    }
}
