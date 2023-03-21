import Foundation

class CellViewModel {
    private let cell: Cell
    
    var isExecuting = false
    let undoManager = UndoManager()
    
    init(cell: Cell) {
        self.cell = cell
    }
    
//    func run() {
//        guard cell.cellType == .code else { return }
//        let jupyter = JupyterService.shared
//        notebook.dirty = true
//        setIsExecuting(cell, isExecuting: true)
//
//        clearOutputs()
//        cell.outputs = []
//        jupyter.webSocketSend(code: cell.source.value) { [row] msg in
//            let cell = self.notebook.content.cells[row]
//            switch msg.channel {
//            case .iopub:
//                var output: Output?
//                switch msg.content {
//                case .stream(let content):
//                    output = .stream(content)
//                case .executeResult(let content):
//                    output = .executeResult(content)
//                case .displayData(let content):
//                    output = .displayData(content)
//                case .error(let content):
//                    output = .error(content)
//                default: break
//                }
//                if let output {
//                    Task.detached { @MainActor in
//                        // TODO: feels hacky...
//                        if cell == self.cell {
//                            self.appendOutputSubview(output)
//                        }
//                    }
//                    cell.outputs!.append(output)
//                }
//            case .shell:
//                switch msg.content {
//                case .executeReply(_):
//                    Task.detached { @MainActor in
//                        self.setIsExecuting(cell, isExecuting: false)
//                    }
//                default: break
//                }
//            }
//        }
//    }
}
