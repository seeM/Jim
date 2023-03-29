import Cocoa
import Combine
import Foundation

class OpaqueView: NSView {
    override var isOpaque: Bool { true }
}

class CellView: NSTableCellView {
    let sourceView = SourceView()
    let richTextView = RichTextView()
    let outputStackView = NSStackView()
    var tableView: NotebookTableView!
    var row: Int { tableView.row(for: self) }
    
    // Caching
    private var reusableImageViews = [NSImageView]()
    private var reusableTextViews = [OutputTextView]()
    
    override var isOpaque: Bool { true }
    
    var viewModel: CellViewModel!
    
    // For switching between edit and rich text mode
    private var sourceViewVerticalConstraints: [NSLayoutConstraint]!
    private var richTextViewVerticalConstraints: [NSLayoutConstraint]!
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        outputStackView.orientation = .vertical
        
        sourceView.delegate = self
        
        richTextView.customDelegate = self
        
        addSubview(sourceView)
        addSubview(richTextView)
        addSubview(outputStackView)
        
        sourceView.translatesAutoresizingMaskIntoConstraints = false
        richTextView.translatesAutoresizingMaskIntoConstraints = false
        outputStackView.translatesAutoresizingMaskIntoConstraints = false
        richTextView.setContentHuggingPriority(.required, for: .vertical)
        sourceView.setContentHuggingPriority(.required, for: .vertical)
        outputStackView.setHuggingPriority(.required, for: .vertical)
        NSLayoutConstraint.activate([
            outputStackView.bottomAnchor.constraint(equalTo: bottomAnchor),
            outputStackView.leadingAnchor.constraint(equalTo: sourceView.leadingAnchor),
            outputStackView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        sourceViewVerticalConstraints = [
            sourceView.topAnchor.constraint(equalTo: topAnchor),
            outputStackView.topAnchor.constraint(equalTo: sourceView.bottomAnchor),
            sourceView.leadingAnchor.constraint(equalTo: leadingAnchor),
            sourceView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ]
        richTextViewVerticalConstraints = [
            richTextView.topAnchor.constraint(equalTo: topAnchor),
            outputStackView.topAnchor.constraint(equalTo: richTextView.bottomAnchor),
            richTextView.leadingAnchor.constraint(equalTo: leadingAnchor),
            richTextView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ]
        
        showSourceView()
    }
    
    func showSourceView() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0
            context.allowsImplicitAnimation = false
            
            sourceView.isHidden = false
            richTextView.isHidden = true
            NSLayoutConstraint.deactivate(richTextViewVerticalConstraints)
            NSLayoutConstraint.activate(sourceViewVerticalConstraints)
//            needsLayout = true
        }
    }
    
    func showRichTextView() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0
            context.allowsImplicitAnimation = false
            
            sourceView.isHidden = true
            richTextView.isHidden = false
            NSLayoutConstraint.deactivate(sourceViewVerticalConstraints)
            NSLayoutConstraint.activate(richTextViewVerticalConstraints)
        }
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    func update(with viewModel: CellViewModel, tableView: NotebookTableView) {
        // Store previous cell state
        // Note that this must happen before self.viewModel is updated
        self.viewModel?.selectedRange = sourceView.textView.selectedRange()
        
        // Note that this must happen before all subscribers
        self.viewModel = viewModel
        
        self.tableView = tableView
    
        // MARK: - Update views based on viewModel
        sourceView.uniqueUndoManager = viewModel.undoManager
        sourceView.textView.string = viewModel.source
        sourceView.textView.setSelectedRange(viewModel.selectedRange)
        
        clearOutputSubviews()
        if let outputs = viewModel.outputs {
            for output in outputs {
                appendOutputSubview(output)
            }
        }
        
        // MARK: - Subscribers
        
        cancellables.removeAll()
        
        viewModel.appendedOutput
            .sink { [weak self] output in
                self?.appendOutputSubview(output)
            }
            .store(in: &cancellables)
        
        viewModel.$cellType
            .removeDuplicates()
            .sink { [weak self] cellType in
                self?.showSourceView()
                self?.sourceView.textView.setWraps(cellType != .code)
            }
            .store(in: &cancellables)
        
        viewModel.$isEditingMarkdown
            .sink { [weak self] isEditingMarkdown in
                if self?.viewModel.cellType == .markdown && isEditingMarkdown {
                    self?.showSourceView()
                }
            }
            .store(in: &cancellables)
        
        viewModel.$renderedMarkdown
            .sink { [weak self] renderedMarkdown in
                if self?.viewModel.cellType == .markdown {
                    self?.richTextView.textStorage?.setAttributedString(renderedMarkdown)
                    self?.showRichTextView()
                }
            }
            .store(in: &cancellables)
        
        viewModel.$isExecuting
            .sink { [weak self] isExecuting in
                self?.alphaValue = isExecuting ? 0.5 : 1.0
            }
            .store(in: &cancellables)
    }
    
    func clearOutputSubviews() {
        for view in outputStackView.arrangedSubviews {
            view.removeFromSuperview()
            if let imageView = view as? NSImageView {
                reusableImageViews.append(imageView)
            } else if let textView = view as? OutputTextView {
                reusableTextViews.append(textView)
            }
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
        let textView: OutputTextView
        if let reusedTextView = reusableTextViews.popLast() {
            textView = reusedTextView
        } else {
            textView = OutputTextView()
            textView.customDelegate = self
            textView.translatesAutoresizingMaskIntoConstraints = false
            textView.setContentHuggingPriority(.required, for: .vertical)
        }
        
        textView.string = text.trimmingCharacters(in: Foundation.CharacterSet.whitespacesAndNewlines).replacing(/\[\d+[\d;]*m/, with: "")
        outputStackView.addArrangedSubview(textView)
    }
    
    func appendOutputImageSubview(_ image: NSImage) {
        let imageView: NSImageView
        if let reusedImageView = reusableImageViews.popLast() {
            imageView = reusedImageView
        } else {
            imageView = NSImageView()
            imageView.imageAlignment = .alignTopLeft
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.setContentHuggingPriority(.required, for: .vertical)
        }
        imageView.image = image
        outputStackView.addArrangedSubview(imageView)
        imageView.leadingAnchor.constraint(equalTo: outputStackView.leadingAnchor).isActive = true
    }
    
    func runCell() {
        if viewModel.cellType == .markdown && viewModel.isEditingMarkdown {
            viewModel.renderMarkdown()
            viewModel.isEditingMarkdown = false
        } else if viewModel.cellType == .code {
            viewModel.notebookViewModel.notebook.dirty = true
            viewModel.isExecuting = true
            
            clearOutputSubviews()
            viewModel.clearOutputs()
            JupyterService.shared.webSocketSend(code: viewModel.cell.source.value) { [weak viewModel] msg in
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
                            viewModel!.appendOutput(output)
                        }
                    }
                case .shell:
                    switch msg.content {
                    case .executeReply(_):
                        Task.detached { @MainActor in
                            viewModel!.isExecuting = false
                        }
                    default: break
                    }
                }
            }
        }
    }
    
    private func selectCurrentRow() {
        tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
    }
}

extension CellView: SourceViewDelegate {
    func didChangeText(_ sourceView: SourceView) {
        viewModel.source = sourceView.textView.string
    }
    
    func didCommit(_ sourceView: SourceView) {
        tableView.runCellSelectBelow()
        endEditMode(sourceView)
    }
    
    func previousCell(_ sourceView: SourceView) {
        if row == 0 { return }
        tableView.selectCellAbove()
        let textView = tableView.selectedCellView!.sourceView.textView
        textView.setSelectedRange(NSRange(location: textView.string.count, length: 0))
        window?.makeFirstResponder(textView)
    }
    
    func nextCell(_ sourceView: SourceView) {
        if row == tableView.numberOfRows - 1 { return }
        tableView.selectCellBelow()
        let textView = tableView.selectedCellView!.sourceView.textView
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        window?.makeFirstResponder(textView)
    }
    
    func didBecomeFirstResponder(_ sourceView: SourceView) {
        viewModel.isEditingMarkdown = true
        selectCurrentRow()
    }
    
    func endEditMode(_ sourceView: SourceView) {
        window?.makeFirstResponder(tableView)
    }
    
    func save() {
        tableView.save()
    }
}

extension CellView: OutputTextViewDelegate {
    func didBecomeFirstResponder(_ textView: OutputTextView) {
        selectCurrentRow()
    }
}

extension CellView: RichTextViewDelegate {
    func didBecomeFirstResponder(_ textView: RichTextView) {
        selectCurrentRow()
    }
}
