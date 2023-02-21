import Cocoa

class NotebookViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {
    @IBOutlet var tableView: NSTableView!
    
    let jupyter = JupyterService.shared
    var notebook: Notebook? {
        didSet {
            guard let notebook = notebook else { return }
            cells = notebook.content.cells ?? []
            tableView.reloadData()
            view.window?.title = notebook.name
        }
    }
    var cells = [Cell]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
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
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        cells.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let view = tableView.makeView(withIdentifier: tableColumn!.identifier, owner: self) as? NSTableCellView else { return nil }
        let item = cells[row]
        view.textField?.stringValue = item.source.value
        return view
    }
}
