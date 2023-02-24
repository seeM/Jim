import Cocoa

class NotebookTableCell: NSTableCellView, SyntaxTextViewDelegate {
    @IBOutlet var syntaxTextView: SyntaxTextView!
    var cell: Cell!
    var tableView: NSTableView!
    var row: Int!
    
    let lexer = Python3Lexer()
    
    func lexerForSource(_ source: String) -> Lexer {
        lexer
    }
    
    func update(cell: Cell, row: Int, tableView: NSTableView, verticalPadding: CGFloat) {
        self.cell = cell
        self.row = row
        self.tableView = tableView

        syntaxTextView.text = cell.source.value
        syntaxTextView.theme = JimSourceCodeTheme()
        syntaxTextView.delegate = self
        
        let textView = syntaxTextView.textView
        textView.textContainerInset.height = verticalPadding
    }
    
    func didChangeText(_ syntaxTextView: SyntaxTextView) {
        cell.source.value = syntaxTextView.text
        // Disable the animation since it causes a bobble on newlines
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0
            tableView.noteHeightOfRows(withIndexesChanged: .init(integer: row))
        }
    }
}
