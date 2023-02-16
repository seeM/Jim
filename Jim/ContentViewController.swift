import Cocoa

class ContentViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {
    @IBOutlet var tableView: NSTableView!
    var jupyter: JupyterService!
    var content: Content?
    var contents = [Content]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        jupyter = JupyterService()
        Task {
            _ = await jupyter.login(baseUrl: "http://localhost:8999/", token: "testtoken123")
            getContent()
        }
        tableView.action = #selector(onClick)
        tableView.delegate = self
        tableView.dataSource = self
    }
    
    func getContent(_ path: String = "") {
        Task {
            switch await jupyter.getContent(path, type: Content.self) {
            case .success(let content):
                self.content = content
                self.contents = content.content?.sorted() ?? []
                tableView.reloadData()
            case .failure(let error):
                print("Error getting content for path '\(path)':", error)
            }
        }
    }
    
    // See: https://stackoverflow.com/questions/18560509/nstableview-detecting-a-mouse-click-together-with-the-row-and-column
    @objc private func onClick() {
        let item = contents[tableView.clickedRow]
        if item.type == .directory {
            getContent(item.path)
        }
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return self.contents.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let view = tableView.makeView(withIdentifier: tableColumn!.identifier, owner: self) as? NSTableCellView else { return nil }
        let item = contents[row]
        let systemSymbolName = item.type == .directory ? "folder" : item.type == .notebook ? "text.book.closed" : "doc"
        view.imageView?.image = NSImage(systemSymbolName: systemSymbolName, accessibilityDescription: nil)!
        view.textField?.stringValue = item.name
        return view
    }
}
