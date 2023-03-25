import Cocoa
import Combine
import Foundation

class OpaqueView: NSView {
    override var isOpaque: Bool { true }
}

class CellView: NSTableCellView {
    let sourceView = SourceView()
    let outputStackView = NSStackView()
    var tableView: NotebookTableView!
    var row: Int { tableView.row(for: self) }
    
    private let containerView = OpaqueView()
    private let shadowLayer = CALayer()
    
    // Caching
    private var previousBounds = CGRect.zero
    private var reusableImageViews = [NSImageView]()
    private var reusableTextViews = [OutputTextView]()
    
    let cornerRadius = 5.0
    
    var viewModel: CellViewModel!
    private var isExecutingCancellable: AnyCancellable?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        layer?.masksToBounds = false

        shadowLayer.shadowColor = NSColor.black.cgColor
        shadowLayer.shadowOpacity = 0.3
        shadowLayer.shadowOffset = CGSize(width: 0, height: -2)
        shadowLayer.shadowRadius = 3
        layer?.addSublayer(shadowLayer)

        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = cornerRadius
        containerView.layer?.masksToBounds = true
        containerView.layer?.backgroundColor = .white
        
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
            outputStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            outputStackView.leadingAnchor.constraint(equalTo: sourceView.leadingAnchor),
            outputStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
        ])
    }
    
    override func layout() {
        super.layout()
        if !NSEqualRects(containerView.bounds, previousBounds) {
            shadowLayer.shadowPath = CGPath(roundedRect: containerView.bounds, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
            previousBounds = containerView.bounds
        }
    }
    
    func update(with viewModel: CellViewModel, tableView: NotebookTableView) {
        // Store previous cell state
        // TODO: there must be a better pattern for this
        self.viewModel?.selectedRange = sourceView.textView.selectedRange()
        
        for view in outputStackView.arrangedSubviews {
            view.removeFromSuperview()
            if let imageView = view as? NSImageView {
                reusableImageViews.append(imageView)
            } else if let textView = view as? OutputTextView {
                reusableTextViews.append(textView)
            }
        }
        
        isExecutingCancellable = viewModel.$isExecuting
            .sink { [weak self] isExecuting in
                self?.alphaValue = isExecuting ? 0.5 : 1.0
            }
        
        self.tableView = tableView
        self.viewModel = viewModel
        sourceView.uniqueUndoManager = viewModel.undoManager
        sourceView.textView.string = viewModel.source
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
        let textView: OutputTextView
        if let reusedTextView = reusableTextViews.popLast() {
            textView = reusedTextView
        } else {
            textView = OutputTextView()
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
    func didChangeText(_ sourceView: SourceView) {
        viewModel.source = sourceView.textView.string
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
