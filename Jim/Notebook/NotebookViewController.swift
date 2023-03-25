import Cocoa

class NotebookViewController: NSViewController {
    @IBOutlet var tableView: NotebookTableView!
    
    var viewModels = [String: NotebookViewModel]()
    var viewModel: NotebookViewModel!
    
    let jupyter = JupyterService.shared
    
    var notebook: Notebook { viewModel!.notebook }
    
    let inputLineHeight: CGFloat = {
        let string = NSAttributedString(string: "A", attributes: [.font: Theme.shared.font])
        return string.size().height
    }()
    
    let outputLineHeight: CGFloat = {
        let string = NSAttributedString(string: "A", attributes: [.font: Theme.shared.font])
        return string.size().height
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.rowHeight = 20
    }
    
    func notebookSelected(path: String) {
        Task {
            switch await jupyter.getContent(path, type: Notebook.self) {
            case .success(let notebook):
                self.viewModel = NotebookViewModel(notebook)
                self.viewModels[notebook.path] = self.viewModel
                tableView.viewModel = self.viewModel
                tableView.reloadData()
                switch await jupyter.createSession(name: notebook.name, path: notebook.path) {
                case .success(let session):
                    Task(priority: .background) { jupyter.webSocketTask(session) }
                case .failure(let error):
                    print("Error creating session:", error)
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
        view.update(with: cellViewModel, tableView: tableView as! NotebookTableView)
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
        if let title = viewModel.cell(at: tableView.selectedRow)?.cellType.rawValue.capitalized {
            windowController.cellTypeComboBox.cell?.title = title
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
