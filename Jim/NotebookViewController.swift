import Cocoa

class NotebookTableRowView: NSTableRowView {
    // Never render the selected row's children as "emphasized"
    override var isEmphasized: Bool { get { false } set {} }
    
    override func drawSelection(in dirtyRect: NSRect) {
        // TODO: How do I get these values programmatically?
        let borderRect = NSInsetRect(self.bounds, 5, 7)
        
        let leftMarginRect = NSRect(x: borderRect.minX, y: borderRect.minY, width: 5, height: borderRect.height)
        NSColor(red: 0, green: 125/255, blue: 250/255, alpha: 1).setFill()
        NSBezierPath.init(roundedRect: leftMarginRect, xRadius: 2, yRadius: 2).fill()
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let view = (self.view(atColumn: 0) as! NotebookTableCell)
        if view.isExecuting {
            let borderRect = NSInsetRect(self.bounds, 5, 7)
            let rightMarginRect = NSRect(x: borderRect.maxX-5, y: borderRect.minY, width: 5, height: borderRect.height)
            NSColor(red: 0, green: 125/255, blue: 250/255, alpha: 1).setFill()
            NSBezierPath.init(roundedRect: rightMarginRect, xRadius: 2, yRadius: 2).fill()
        }
    }
}

class NotebookViewController: NSViewController {
    @IBOutlet var tableView: NotebookTableView!
    
    let jupyter = JupyterService.shared
    var notebook: Notebook! {
        didSet {
            guard let notebook = notebook else { return }
            tableView.reloadData()
            view.window?.makeFirstResponder(tableView)
            view.window?.title = notebook.name
        }
    }
    var cells: [Cell] { notebook?.content.cells ?? []}
    var undoManagers = [String: UndoManager]()
    
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
        let cell = cells[row]
        
        var undoManager: UndoManager! = undoManagers[cell.id]
        if undoManager == nil {
            undoManager = UndoManager()
            undoManagers[cell.id] = undoManager
        }
        
        view.update(cell: cells[row], tableView: tableView as! NotebookTableView, notebook: notebook, undoManager: undoManager)
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
                    if let plainText = output.data.plainText { outputHeights.append(textHeight(plainText.value, lineHeight: outputLineHeight)) }
                    if let markdownText = output.data.markdownText { outputHeights.append(textHeight(markdownText.value, lineHeight: outputLineHeight)) }
                    if let htmlText = output.data.markdownText { outputHeights.append(textHeight(htmlText.value, lineHeight: outputLineHeight)) }
                    if let image = output.data.image { outputHeights.append(image.value.size.height) }
                case .executeResult(let output):
                    if let plainText = output.data.plainText { outputHeights.append(textHeight(plainText.value, lineHeight: outputLineHeight)) }
                    if let markdownText = output.data.markdownText { outputHeights.append(textHeight(markdownText.value, lineHeight: outputLineHeight)) }
                    if let htmlText = output.data.markdownText { outputHeights.append(textHeight(htmlText.value, lineHeight: outputLineHeight)) }
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
        let rowView = NotebookTableRowView()
        return rowView
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        let windowController = view.window!.windowController as! WindowController
        if let title = selectedCell()?.cellType.rawValue.capitalized {
            windowController.cellTypeComboBox.cell?.title = title
        }
    }
}

extension NotebookViewController: NotebookTableViewDelegate {
    func insertCell(_ cell: Cell, at row: Int) {
        notebook.dirty = true
        notebook.content.cells.insert(cell, at: row)
    }
    
    func removeCell(at row: Int) -> Cell {
        notebook.dirty = true
        return notebook.content.cells.remove(at: row)
    }
    
    func selectedCell() -> Cell? {
        tableView.selectedRow == -1 ? nil : notebook.content.cells[tableView.selectedRow]
    }
    
    func save() {
        Task {
            switch await jupyter.getContent(notebook.path, type: Notebook.self) {
            case .success(let diskNotebook):
                // TODO: need a margin? lab uses 500
                if diskNotebook.lastModified >  notebook.lastModified {
                    let alert = NSAlert()
                    alert.messageText = "Failed to save \(notebook.path)"
                    alert.informativeText = "The content on disk is newer. Do you want to overwrite it with your changes or discard them and revert to the on disk content?"
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "Overwrite")
                    alert.addButton(withTitle: "Discard")
                    alert.addButton(withTitle: "Cancel")
                    let discardButton = alert.buttons[1]
                    discardButton.hasDestructiveAction = true
                    let overwriteButton = alert.buttons[0]
                    overwriteButton.hasDestructiveAction = true
                    let response = alert.runModal()
                    switch response {
                    case .alertFirstButtonReturn:
                        await _save()
                    case .alertSecondButtonReturn:
                        self.notebook = diskNotebook
                    default: break
                    }
                } else {
                    await _save()
                }
            case .failure(let error):
                print("Failed to get content while saving notebook, error:", error)  // TODO: show alert
                return
            }
        }
    }
    
    private func _save() async {
        switch await jupyter.updateContent(notebook.path, content: notebook) {
        case .success(let content):
            print("Saved!")  // TODO: update UI
            self.notebook.lastModified = content.lastModified
            self.notebook.size = content.size
            self.notebook.dirty = false
        case .failure(let error):
            print("Failed to save notebook, error:", error)  // TODO: show alert
        }
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

extension NotebookViewController: NSToolbarItemValidation {
    func validateToolbarItem(_ item: NSToolbarItem) -> Bool {
        notebook != nil
    }
    
    @IBAction func insertClicked(_ sender: NSView) {
        tableView.insertCellBelow()
    }
    
    @IBAction func cutClicked(_ sender: NSView) {
        tableView.cutCell()
    }
    
    @IBAction func copyClicked(_ sender: NSView) {
        tableView.copyCell()
    }
    
    @IBAction func pasteClicked(_ sender: NSView) {
        tableView.pasteCellBelow()
    }
    
    @IBAction func moveUpClicked(_ sender: NSView) {
        // TODO: make a function
        tableView.cutCell()
        tableView.selectCellAbove()
        tableView.pasteCellAbove()
    }
    
    @IBAction func moveDownClicked(_ sender: NSView) {
        // TODO: make a function
        tableView.cutCell()
        tableView.pasteCellBelow()
    }
    
    @IBAction func runClicked(_ sender: NSView) {
        tableView.runCellSelectBelow()
    }

    @IBAction func interruptClicked(_ sender: NSView) {
        // TODO
        print("interrupt")
    }
    
    @IBAction func restartClicked(_ sender: NSView) {
        // TODO
        print("restart kernel")
    }
    
    @IBAction func restartAndRerunAllClicked(_ sender: NSView) {
        // TODO
        print("restart kernel and rerun all cells")
    }
    
    @IBAction func setCellTypeClicked(_ sender: NSComboBox) {
        let rawValue = (sender.objectValueOfSelectedItem as! String).lowercased()
        // TODO: update the cell's outputs etc to match type...
        // TODO: make this undoable too?
        // TODO: make a command for this
        notebook.content.cells[tableView.selectedRow].cellType = .init(rawValue: rawValue)!
    }
}
