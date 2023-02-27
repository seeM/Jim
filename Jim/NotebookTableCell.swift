import Cocoa

class NotebookTableCell: NSTableCellView, SyntaxTextViewDelegate {
    var cell: Cell!
    var tableView: NSTableView!
    var row: Int!
    
    let lexer = Python3Lexer()
    
    func lexerForSource(_ source: String) -> Lexer {
        lexer
    }
    
//    func outputText(_ text: String) {
//        let outputTextView = NSTextView()
//        stackView.addArrangedSubview(outputTextView)
////        outputTextView.autoresizingMask = [.width, .height]
//        outputTextView.string = text.trimmingCharacters(in: Foundation.CharacterSet.whitespacesAndNewlines)
//        outputTextView.font = NSFont(name: "Menlo", size: 12)!
//        outputTextView.backgroundColor = .red
//        outputTextView.drawsBackground = true
//        print("render output text: \(text)")
//    }
    
//    override var intrinsicContentSize: NSSize {
//        return NSSize(width: 100, height: 24)
//    }
    
    func update(cell: Cell, row: Int, tableView: NSTableView, verticalPadding: CGFloat) {
        self.cell = cell
        self.row = row
        self.tableView = tableView
        
//        let stackView = NSStackView()
//        stackView.orientation = .vertical
//        stackView.alignment = .leading
//        stackView.distribution = .gravityAreas
//        addSubview(stackView)
//
//        stackView.translatesAutoresizingMaskIntoConstraints = false
//        stackView.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
//        stackView.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
//        stackView.topAnchor.constraint(equalTo: topAnchor).isActive = true
//        stackView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        
//        let tf1 = NSTextField(labelWithString: "Hello world!")
//        stackView.addArrangedSubview(tf1)
        
        let syntaxTextView = SyntaxTextView()
//        stackView.addArrangedSubview(syntaxTextView)
        addSubview(syntaxTextView)
        syntaxTextView.text = cell.source.value
        syntaxTextView.theme = JimSourceCodeTheme()
        syntaxTextView.delegate = self
        
        syntaxTextView.translatesAutoresizingMaskIntoConstraints = false
        syntaxTextView.topAnchor.constraint(equalTo: topAnchor).isActive = true
        syntaxTextView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        syntaxTextView.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        syntaxTextView.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
//        syntaxTextView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
//        syntaxTextView.setContentHuggingPriority(.fittingSizeCompression, for: .vertical)
        
//        let textView = syntaxTextView.textView
        
//        syntaxTextView.heightAnchor.constraint(equalTo: textView.heightAnchor).isActive = true
        
//        guard let outputs = cell.outputs else { return }
//        for output in outputs {
//            switch output {
//            case .stream(let output): outputText(output.text)
//            case .displayData(let output):
//                if let text = output.data.text {
//                    outputText(text.value)
//                }
//                if let image = output.data.image {
//                    let imageView = NSImageView(image: image.value)
//                    stackView.addArrangedSubview(imageView)
//                }
//            case .executeResult(let output):
//                if let text = output.data.text {
//                    outputText(text.value)
//                }
//                if let image = output.data.image {
//                    let imageView = NSImageView(image: image.value)
//                    stackView.addArrangedSubview(imageView)
//                }
//            case .error(let output): outputText(output.traceback.joined(separator: "\n"))
//            }
//        }
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
