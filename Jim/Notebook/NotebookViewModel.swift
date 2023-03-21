import Foundation

class NotebookViewModel {
    var notebook: Notebook
    var cellViewModels: [String: CellViewModel]
    
    let jupyter = JupyterService.shared
    
    var cells: [Cell] { notebook.content.cells }
    
    init(_ notebook: Notebook) {
        self.notebook = notebook
        self.cellViewModels = [String: CellViewModel]()
        for cell in cells {
            self.cellViewModels[cell.id] = .init(cell: cell)
        }
    }
    
    func cellViewModel(for cell: Cell) -> CellViewModel {
        if let cellViewModel = cellViewModels[cell.id] {
            return cellViewModel
        }
        let cellViewModel = CellViewModel(cell: cell)
        cellViewModels[cell.id] = cellViewModel
        return cellViewModel
    }
    
    func openNotebook(path: String) async {
        switch await jupyter.getContent(path, type: Notebook.self) {
        case .success(let notebook):
            self.notebook = notebook
            switch await jupyter.createSession(name: notebook.name, path: notebook.path) {
            case .success(let session): Task(priority: .background) { jupyter.webSocketTask(session) }
            case .failure(let error): print("Error creating session:", error)
            }
        case .failure(let error): print("Error getting notebook:", error)
        }
    }
}
