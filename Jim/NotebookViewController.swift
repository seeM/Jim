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
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        cells.count
    }
    
    func tableView(_ tableView: NSTableView, didAdd rowView: NSTableRowView, forRow row: Int) {
        rowView.translatesAutoresizingMaskIntoConstraints = false
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let view = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "notebookCell"), owner: self) as? NotebookTableCell else { return nil }
        view.update(cell: cells[row], row: row, tableView: tableView)
        return view
    }
    
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        false
    }
}

struct JimSourceCodeTheme: SourceCodeTheme {
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
