import Cocoa

class ContentViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {
    @IBOutlet var tableView: NSTableView!
    var content: Content?
    var contents = [Content]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let jupyter = JupyterService()
        Task {
            _ = await jupyter.login(baseUrl: "http://localhost:8999/", token: "testtoken123")
            let path = ""
            switch await jupyter.getContent(path, type: Content.self) {
            case .success(let content):
                print("Got content")
                self.content = content
                self.contents = content.content?.sorted() ?? []
                tableView.reloadData()
            case .failure(let error):
                print("Error getting content for path '\(path)':", error)
            }
        }
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return self.contents.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let view = tableView.makeView(withIdentifier: tableColumn!.identifier, owner: self) as? NSTableCellView else { return nil }
//        let string = NSMutableAttributedString(string: "")
//        let imageAttachment = NSTextAttachment()
//        imageAttachment.image = NSImage(systemSymbolName: "doc", accessibilityDescription: nil)!
//        let imageString = NSAttributedString(attachment: imageAttachment)
//        string.append(imageString)
//        string.append(NSAttributedString(string: " " + contents[row].name))
//        view.textField?.attributedStringValue = string
        let item = contents[row]
        let systemSymbolName = item.type == .directory ? "folder" : item.type == .notebook ? "text.book.closed" : "doc"
        view.imageView?.image = NSImage(systemSymbolName: systemSymbolName, accessibilityDescription: nil)!
        view.textField?.stringValue = contents[row].name
//        let imageView = NSImageView(image: image)
//        view.textField?.addSubview(imageView)
//        view.imageView?.image = NSImage(systemSymbolName: "doc", accessibilityDescription: nil)
        return view
    }
}
