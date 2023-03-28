import Combine
import Foundation
import Down

class CellViewModel: ObservableObject {
    let cell: Cell
    let notebookViewModel: NotebookViewModel

    let undoManager = UndoManager()
    var selectedRange = NSRange(location: 0, length: 0)
    
    @Published var isExecuting = false
    @Published var isEditingMarkdown = false
    @Published var renderedMarkdown = NSAttributedString()
    
    var outputs: [Output]? {
        cell.outputs
    }
    
    private let appendedOutputSubject = PassthroughSubject<Output, Never>()
    var appendedOutput: AnyPublisher<Output, Never> {
        appendedOutputSubject.eraseToAnyPublisher()
    }
    
    var dirty = false
    
    var source: String {
        get { cell.source.value }
        set {
            dirty = dirty || (newValue != cell.source.value)
            cell.source.value = newValue
        }
    }
    
    @Published var cellType: CellType {
        didSet {
            if cellType != oldValue && cellType == .markdown {
                isEditingMarkdown = true
            }
            cell.cellType = cellType
        }
    }

    init(cell: Cell, notebookViewModel: NotebookViewModel) {
        self.cell = cell
        self.notebookViewModel = notebookViewModel
        self.cellType = cell.cellType
        if cellType == .markdown {
            renderMarkdown()
        }
    }
    
    func renderMarkdown() {
        renderedMarkdown = NSAttributedString(string: source)
//        let down = Down(markdownString: source)
//        if let attributedString = try? down.toAttributedString() {
//            renderedMarkdown = attributedString
//        } else {
//            print("Error parsing markdown: \(source)")
//        }
    }
    
    func appendOutput(_ output: Output) {
        cell.outputs?.append(output)
        appendedOutputSubject.send(output)
    }
    
    func clearOutputs() {
        cell.outputs?.removeAll()
    }
}
