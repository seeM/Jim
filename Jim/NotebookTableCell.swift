import Cocoa

class NotebookTableCell: NSTableCellView, SyntaxTextViewDelegate, NSTextViewDelegate {
    @IBOutlet var syntaxTextView: SyntaxTextView!
    var cell: Cell!
    var tableView: NSTableView!
    var row: Int!
    
    let lexer = Python3Lexer()
    
    func lexerForSource(_ source: String) -> Lexer {
        lexer
    }
    
    func update(cell: Cell, row: Int, tableView: NSTableView) {
        self.cell = cell
        self.row = row
        self.tableView = tableView

        syntaxTextView.text = cell.source.value
        syntaxTextView.theme = JimSourceCodeTheme()
        syntaxTextView.delegate = self
        
        let scrollView = syntaxTextView.scrollView
        scrollView.verticalScrollElasticity = .none
        scrollView.horizontalScrollElasticity = .automatic
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        
        let textView = syntaxTextView.contentTextView
        textView.delegate = self
        
        textView.wantsLayer = true
        textView.layer?.cornerRadius = 7
        
        // Enable horizontal scrolling. See: https://stackoverflow.com/questions/3174140/how-to-disable-word-wrap-of-nstextview
        textView.isHorizontallyResizable = true
        textView.textContainer?.widthTracksTextView = false
        let infiniteSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.maxSize = infiniteSize
        textView.textContainer?.size = infiniteSize
    }
    
    func textDidChange(_ notification: Notification) {
        guard let textView = notification.object as? NSTextView else { return }
        cell.source.value = textView.string
        // Disable the animation since it causes a bobble on newlines
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0
            tableView.noteHeightOfRows(withIndexesChanged: .init(integer: row))
        }
    }
}
