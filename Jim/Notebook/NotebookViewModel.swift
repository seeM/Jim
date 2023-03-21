import Foundation
import Cocoa

class NotebookViewModel {
    var notebook: Notebook
    var cellViewModels = [String: CellViewModel]()
    
    let jupyter = JupyterService.shared
    
    var cells: [Cell] { notebook.content.cells }
    
    init(_ notebook: Notebook) {
        self.notebook = notebook
    }
    
    func cellViewModel(for cell: Cell) -> CellViewModel {
        if let cellViewModel = cellViewModels[cell.id] {
            return cellViewModel
        }
        let cellViewModel = CellViewModel(cell: cell, notebookViewModel: self)
        cellViewModels[cell.id] = cellViewModel
        return cellViewModel
    }
    
    // MARK: - Cell management
    
    func insertCell(_ cell: Cell, at row: Int) {
        notebook.dirty = true
        notebook.content.cells.insert(cell, at: row)
    }
    
    func removeCell(at row: Int) -> Cell {
        notebook.dirty = true
        return notebook.content.cells.remove(at: row)
    }

    func cell(at row: Int) -> Cell? {
        if row < 0 || row > notebook.content.cells.count { return nil }
        return notebook.content.cells[row]
    }
    
    // MARK: - Jupyter service management
    
    func getLatestNotebook() async -> Result<Notebook,JupyterError> {
        return await jupyter.getContent(notebook.path, type: Notebook.self)
    }
    
    func updateNotebook() async {
        switch await jupyter.updateContent(notebook.path, content: notebook) {
        case .success(let content):
            print("Saved!")  // TODO: update UI
            notebook.lastModified = content.lastModified
            notebook.size = content.size
            notebook.dirty = false
        case .failure(let error):
            print("Failed to save notebook, error:", error)  // TODO: show alert
        }
    }
}
