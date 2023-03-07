import Cocoa

protocol NotebookTableViewDelegate: AnyObject {
    func createCell(_ tableView: NotebookTableView, at row: Int, cell: Cell)
    func cutCell()
    func pasteCell(at row: Int)
    func undoCutCell()
    func executeCell(_ tableView: NotebookTableView)
}

extension NotebookTableViewDelegate {
    func createCell(_ tableView: NotebookTableView, at row: Int, cell: Cell = Cell()) {
        createCell(tableView, at: row, cell: cell)
    }
}

class NotebookTableView: NSTableView {
    var notebookDelegate: NotebookTableViewDelegate?
    
    func focusCell(at tryRow: Int) {
        let row = tryRow < 0 ? 0 : tryRow >= numberOfRows ? numberOfRows - 1: tryRow
        selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        scrollRowToVisible(row)
    }
    
    private func enterEditMode(at row: Int) {
        let cellView = view(atColumn: selectedColumn, row: row, makeIfNecessary: false) as! NotebookTableCell
        let textView = cellView.syntaxTextView.textView
        scrollRowToVisible(row)
        window?.makeFirstResponder(cellView.syntaxTextView.textView)
        textView.scrollRangeToVisible(textView.selectedRange())
    }
    
    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if event.keyCode == 36 && flags == .shift {
            notebookDelegate?.executeCell(self)
            let row = selectedRow + 1
            if row == numberOfRows {
                notebookDelegate?.createCell(self, at: row)
                enterEditMode(at: row)
            } else {
                focusCell(at: row)
            }
            return
        } else if event.keyCode == 36 {
            enterEditMode(at: selectedRow)
            return
        } else if event.keyCode == 40 {  // k
            focusCell(at: selectedRow - 1)
            return
        } else if event.keyCode == 38 {  // j
            focusCell(at: selectedRow + 1)
            return
        } else if event.keyCode == 0 {   // a
            notebookDelegate?.createCell(self, at: selectedRow)
            focusCell(at: selectedRow - 1)
            return
        } else if event.keyCode == 11 {  // b
            let row = selectedRow + 1
            notebookDelegate?.createCell(self, at: row)
            focusCell(at: row)
            return
        } else if event.keyCode == 7 {
            notebookDelegate?.cutCell()
            return
        } else if event.keyCode == 9 && flags == .shift {
            notebookDelegate?.pasteCell(at: selectedRow)
            focusCell(at: selectedRow - 1)
            return
        } else if event.keyCode == 9 {
            notebookDelegate?.pasteCell(at: selectedRow + 1)
            focusCell(at: selectedRow + 1)
            return
        } else if event.keyCode == 6 {
            notebookDelegate?.undoCutCell()
            return
        } else {
            print(event.keyCode)
        }
        
        super.keyDown(with: event)
    }
}

class NotebookTableRowView: NSTableRowView {
//    override func drawSelection(in dirtyRect: NSRect) {
//        if self.selectionHighlightStyle != .none {
//            let selectionRect = NSInsetRect(self.bounds, 2.5, 2.5)
//            NSColor(calibratedWhite: 0.65, alpha: 1).setStroke()
//            NSColor(calibratedWhite: 0.82, alpha: 1).setFill()
//            let selectionPath = NSBezierPath.init(roundedRect: selectionRect, xRadius: 6, yRadius: 6)
//            selectionPath.fill()
//            selectionPath.stroke()
//        }
//    }
}

class NotebookViewController: NSViewController {
    @IBOutlet var tableView: NotebookTableView!
    
    let jupyter = JupyterService.shared
    var notebook: Notebook? {
        didSet {
            guard let notebook = notebook else { return }
            tableView.reloadData()
            view.window?.makeFirstResponder(tableView)
            view.window?.title = notebook.name
        }
    }
    var cells: [Cell] { notebook?.content.cells ?? []}
    
    var previouslyRemovedCell: Cell?
    var previouslyRemovedRow: Int?
    
    let inputLineHeight: CGFloat = {
        let string = NSAttributedString(string: "A", attributes: [.font: JimSourceCodeTheme.shared.font])
        return string.size().height + 2
    }()
    
    let outputLineHeight: CGFloat = {
        let string = NSAttributedString(string: "A")
        return string.size().height
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.notebookDelegate = self
        tableView.usesAutomaticRowHeights = true
    }
    
    func notebookSelected(path: String) {
        Task {
            switch await jupyter.getContent(path, type: Notebook.self) {
            case .success(let notebook):
                self.notebook = notebook
                switch await jupyter.createSession(name: notebook.name, path: notebook.path) {
                case .success(let session): Task(priority: .background) { jupyter.webSocketTask(session) }
                case .failure(let error): print("Error creating session:", error)
                }
            case .failure(let error): print("Error getting notebook:", error)
            }
        }
    }
}

extension NotebookViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        cells.count
    }
}

extension NotebookViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let view = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "notebookCell"), owner: self) as? NotebookTableCell else { return nil }
        view.update(cell: cells[row], tableView: tableView, notebook: notebook!)
        return view
    }
    
    func textHeight(_ text: String, lineHeight: CGFloat) -> CGFloat {
        CGFloat(text.components(separatedBy: "\n").count) * lineHeight
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        let cell = cells[row]
        let inputVerticalPadding = CGFloat(5)
        let inputHeight = 2 * inputVerticalPadding + textHeight(cell.source.value, lineHeight: inputLineHeight)
        var outputHeights = [CGFloat]()
        if let outputs = cell.outputs {
            for output in outputs {
                switch output {
                case .stream(let output): outputHeights.append(textHeight(output.text, lineHeight: outputLineHeight))
                case .displayData(let output):
                    if let text = output.data.text { outputHeights.append(textHeight(text.value, lineHeight: outputLineHeight)) }
                    if let image = output.data.image { outputHeights.append(image.value.size.height) }
                case .executeResult(let output):
                    if let text = output.data.text { outputHeights.append(textHeight(text.value, lineHeight: outputLineHeight)) }
                    if let image = output.data.image { outputHeights.append(image.value.size.height) }
                case .error(let output): outputHeights.append(CGFloat(output.traceback.count)*outputLineHeight)
                }
            }
        }
        let outputHeight = outputHeights.reduce(0, { $0 + $1 })
        let height = inputHeight + outputHeight
        return height
    }
    
    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        NotebookTableRowView()
    }
}

extension NotebookViewController: NotebookTableViewDelegate {
    func cutCell() {
        let row = tableView.selectedRow
        previouslyRemovedRow = row
        previouslyRemovedCell = notebook!.content.cells!.remove(at: row)
        tableView.removeRows(at: .init(integer: row))
        if tableView.numberOfRows == 0 {
            createCell(tableView, at: row)
        }
        tableView.focusCell(at: row)
    }
    
    func pasteCell(at row: Int) {
        guard let cell = previouslyRemovedCell else { return }
        createCell(tableView, at: row, cell: cell)
    }
    
    func undoCutCell() {
        guard let cell = previouslyRemovedCell,
              let row = previouslyRemovedRow else { return }
        createCell(tableView, at: row, cell: cell)
    }
    
    func createCell(_ tableView: NotebookTableView, at row: Int, cell: Cell = Cell()) {
        notebook!.content.cells!.insert(cell, at: row)
        tableView.insertRows(at: .init(integer: row))
    }
    
    func executeCell(_ tableView: NotebookTableView) {
        let cellView = tableView.view(atColumn: tableView.selectedColumn, row: tableView.selectedRow, makeIfNecessary: false) as! NotebookTableCell
        let syntaxTextView = cellView.syntaxTextView
        cellView.didCommit(syntaxTextView)
    }
}

struct JimSourceCodeTheme: SourceCodeTheme {
    static let shared = JimSourceCodeTheme()
    public let font = NSFont(name: "Menlo", size: 12)!
    public let backgroundColor = NSColor(red: 0, green: 0, blue: 0, alpha: 0.05)
    public func color(for syntaxColorType: SourceCodeTokenType) -> NSColor {
        switch syntaxColorType {
        case .plain: return .black
        case .number: return NSColor(red: 0, green: 136/255, blue: 0, alpha: 1.0)
        case .string: return NSColor(red: 186/255, green: 33/255, blue: 33/255, alpha: 1.0)
        case .identifier: return .black
        case .keyword: return NSColor(red: 0, green: 128/255, blue: 0, alpha: 1.0)
        case .comment: return NSColor(red: 0, green: 121/255, blue: 121/255, alpha: 1.0)
        }
    }
}
