import Cocoa
import Sourceful

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
        syntaxTextView.scrollView.verticalScrollElasticity = .none
        syntaxTextView.scrollView.hasVerticalScroller = false
        syntaxTextView.contentTextView.delegate = self
    }
    
    func textDidChange(_ notification: Notification) {
        guard let textView = notification.object as? NSTextView else { return }
        cell.source.value = textView.string
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0
            tableView.noteHeightOfRows(withIndexesChanged: .init(integer: row))
        }
    }
}
