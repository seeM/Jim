import Cocoa

class ContentViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {
    @IBOutlet var tableView: NSTableView!
//    @IBOutlet var backButton: NSButton!
    var jupyter: JupyterService!
    var content: Content? {
        didSet {
            contents = content?.content?.sorted() ?? []
            tableView.reloadData()
        }
    }
    var contents = [Content]()
    var path = [Content]() {
        didSet {
//            backButton.isEnabled = path.count > 0
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        jupyter = JupyterService()
        Task {
            _ = await jupyter.login(baseUrl: "http://localhost:8999/", token: "testtoken123")
            getContent()
        }
        tableView.action = #selector(onTableClick)
        tableView.delegate = self
        tableView.dataSource = self
//        backButton.target = self
//        backButton.action = #selector(onBackClick)
//        _ = backButton.leadingAnchor.constraint(equalTo: tableView.leadingAnchor)
//        backButton.isEnabled = false
    }
    
    func getContent(_ path: String = "") {
        Task {
            switch await jupyter.getContent(path, type: Content.self) {
            case .success(let content):
                self.content = content
            case .failure(let error):
                print("Error getting content for path '\(path)':", error)
            }
        }
    }
    
//    @objc private func onBackClick() {
//        content = path.popLast()
//    }
    
    // See: https://stackoverflow.com/questions/18560509/nstableview-detecting-a-mouse-click-together-with-the-row-and-column
    @objc private func onTableClick() {
        if tableView.clickedRow == -1 { return }
        let item = contents[tableView.clickedRow]
        if item.type == .directory {
            let prev = content
            getContent(item.path)
            if let prev {
                path.append(prev)
            }
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
