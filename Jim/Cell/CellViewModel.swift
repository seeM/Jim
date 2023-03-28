import Foundation
import Down

class CellViewModel: ObservableObject {
    let cell: Cell
    let notebookViewModel: NotebookViewModel

    @Published var isExecuting = false
    let undoManager = UndoManager()
    var selectedRange = NSRange(location: 0, length: 0)
    
    @Published var isEditing: Bool
    @Published var renderedMarkdown = NSAttributedString()
    
    var dirty = false
    
    var source: String {
        get { cell.source.value }
        set {
            dirty = dirty || (newValue != cell.source.value)
            cell.source.value = newValue
        }
    }
    
    var cellType: CellType {
        get { cell.cellType }
        set {
            if newValue != .code {
                cell.outputs = nil
            }
            cell.cellType = newValue
        }
    }
    

    init(cell: Cell, notebookViewModel: NotebookViewModel) {
        self.cell = cell
        self.notebookViewModel = notebookViewModel
        if cell.cellType == .markdown {
            isEditing = false
            renderMarkdown()
        } else {
            isEditing = true
        }
    }
    
    func renderMarkdown() {
        let down = Down(markdownString: source)
        if let attributedString = try? down.toAttributedString() {
            renderedMarkdown = attributedString
        } else {
            print("Error parsing markdown: \(source)")
        }
    }
}
