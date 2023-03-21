import Foundation

class CellViewModel: ObservableObject {
    let cell: Cell
    let notebookViewModel: NotebookViewModel

    @Published var isExecuting = false
    let undoManager = UndoManager()
    var selectedRange = NSRange(location: 0, length: 0)
    var dirty = false
    
    var source: String {
        get { cell.source.value }
        set {
            dirty = dirty || (newValue != cell.source.value)
            cell.source.value = newValue
        }
    }

    init(cell: Cell, notebookViewModel: NotebookViewModel) {
        self.cell = cell
        self.notebookViewModel = notebookViewModel
    }
}
