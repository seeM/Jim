import Cocoa

class NotebookViewController: NSViewController {
    @IBOutlet var tableView: NotebookTableView!
    
    var viewModels = [String: NotebookViewModel]()
    var viewModel: NotebookViewModel!
    
    let jupyter = JupyterService.shared
    
    var notebook: Notebook { viewModel!.notebook }
    
    let inputLineHeight: CGFloat = {
        let string = NSAttributedString(string: "A", attributes: [.font: SourceCodeTheme.shared.font])
        return string.size().height + 2
    }()
    
    let outputLineHeight: CGFloat = {
        let string = NSAttributedString(string: "A", attributes: [.font: SourceCodeTheme.shared.font])
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
                self.viewModel = NotebookViewModel(notebook)
                self.viewModels[notebook.path] = self.viewModel
                tableView.reloadData()
                view.window?.makeFirstResponder(tableView)
                view.window?.title = viewModel.notebook.name
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
        viewModel?.cells.count ?? 0
    }
}

extension NotebookViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let view = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "notebookCell"), owner: self) as? CellView else { return nil }
        let cell = viewModel.cells[row]
        let cellViewModel = viewModel.cellViewModel(for: cell)
        view.update(cell: cell, tableView: tableView as! NotebookTableView, notebook: viewModel.notebook, with: cellViewModel)
        return view
    }
    
    func textHeight(_ text: String, lineHeight: CGFloat) -> CGFloat {
        CGFloat(text.components(separatedBy: "\n").count) * lineHeight
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        let cell = viewModel.cells[row]
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
        NotebookTableRowView()
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
                        self.viewModel.notebook = diskNotebook
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

extension NotebookViewController: NSToolbarItemValidation {
    func validateToolbarItem(_ item: NSToolbarItem) -> Bool {
        viewModel != nil
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
        tableView.moveCellUp()
    }
    
    @IBAction func moveDownClicked(_ sender: NSView) {
        tableView.moveCellDown()
    }
    
    @IBAction func runClicked(_ sender: NSView) {
        tableView.runCellSelectBelow()
    }

    @IBAction func interruptClicked(_ sender: NSView) {
        tableView.interruptKernel()
    }
    
    @IBAction func restartClicked(_ sender: NSView) {
        tableView.restartKernel()
    }
    
    @IBAction func restartAndRerunAllClicked(_ sender: NSView) {
        // TODO
        print("restart kernel and rerun all cells")
    }
    
    @IBAction func setCellTypeClicked(_ sender: NSComboBox) {
        // TODO: is there a way for the sender to use an enum directly?
        let rawValue = (sender.objectValueOfSelectedItem as! String).lowercased()
        let cellType = CellType.init(rawValue: rawValue)!
        tableView.setCellType(cellType)
    }
}
