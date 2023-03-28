import Cocoa

class SidebarViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {
    @IBOutlet var tableView: NSTableView!
    
    let jupyter = JupyterService.shared
    var content: Content? {
        didSet {
            guard let content = content else { return }
            contents = content.content?.sorted() ?? []
            tableView.reloadData()
            view.window?.title = content.name == "" ? "Files" : content.name
        }
    }
    var contents = [Content]()
    var path = [Content]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        Task {
            _ = await jupyter.login(baseUrl: "http://localhost:8999/", token: "testtoken123")
            getContent()
        }
        tableView.action = #selector(onTableClick)
        tableView.delegate = self
        tableView.dataSource = self
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
    
    @objc private func onTableClick() {
        guard tableView.clickedRow != -1 else { return }
        let item = contents[tableView.clickedRow]
        if item.type == .directory {
            let prev = content
            getContent(item.path)
            if let prev {
                path.append(prev)
            }
        } else if item.type == .notebook {
            if let notebookViewController = (parent as? NSSplitViewController)?.children[1] as? NotebookViewController {
                notebookViewController.notebookSelected(path: item.path)
            }
        }
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        contents.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let view = tableView.makeView(withIdentifier: tableColumn!.identifier, owner: self) as? NSTableCellView else { return nil }
        let item = contents[row]
        let systemSymbolName = item.type == .directory ? "folder.fill" : item.type == .notebook ? "text.book.closed" : "doc"
        view.imageView?.image = NSImage(systemSymbolName: systemSymbolName, accessibilityDescription: nil)!
        // Blue
//        view.imageView?.contentTintColor = item.type == .notebook ? NSColor.init(red: 0.071, green: 0.471, blue: 0.949, alpha: 1.0) : Theme.shared.sidebarTintColor
        // Orange
//        view.imageView?.contentTintColor = item.type == .notebook ? NSColor.init(red: 0.921, green: 0.447, blue: 0.192, alpha: 1.0) : Theme.shared.sidebarTintColor
        view.imageView?.contentTintColor = Theme.shared.sidebarTintColor
        view.textField?.stringValue = item.name
        return view
    }
}

// MARK: Back toolbar item

extension SidebarViewController: NSToolbarItemValidation {
    func validateToolbarItem(_ item: NSToolbarItem) -> Bool {
        path.count > 0
    }
    
    @IBAction func backClicked(_ sender: NSView) {
        content = path.popLast()
    }
}
