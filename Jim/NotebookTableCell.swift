import Cocoa

class StackView: NSStackView {
    override func addArrangedSubview(_ view: NSView) {
        super.addArrangedSubview(view)
        view.widthAnchor.constraint(equalTo: widthAnchor).isActive = true
        view.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
    }
}

class NotebookTableCell: NSTableCellView, SyntaxTextViewDelegate {
    var stackView: NSStackView!
    var cell: Cell!
    var tableView: NSTableView!
    var row: Int!
    
    let lexer = Python3Lexer()
    
    func lexerForSource(_ source: String) -> Lexer {
        lexer
    }
    
    func addText(_ text: String) {
        let string = text.trimmingCharacters(in: Foundation.CharacterSet.whitespacesAndNewlines)
        let textField = NSTextField(wrappingLabelWithString: string)
        stackView.addArrangedSubview(textField)
    }
    
    func addImage(_ image: NSImage) {
        let imageView = NSImageView(image: image)
        imageView.imageAlignment = .alignTopLeft
        stackView.addArrangedSubview(imageView)
    }
    
    func update(cell: Cell, row: Int, tableView: NSTableView, verticalPadding: CGFloat) {
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
    
    func didChangeText(_ syntaxTextView: SyntaxTextView) {
        cell.source.value = syntaxTextView.text
        // Disable the animation since it causes a bobble on newlines
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0
            tableView.noteHeightOfRows(withIndexesChanged: .init(integer: row))
        }
    }
}
