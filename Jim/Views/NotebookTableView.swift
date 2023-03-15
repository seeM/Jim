import Cocoa

protocol NotebookTableViewDelegate: AnyObject {
    func insertCell(_ cell: Cell, at row: Int)
    func removeCell(at row: Int) -> Cell
    func selectedCell() -> Cell
    func save()
}

class NotebookTableView: NSTableView {
    var copyBuffer: Cell?
    var previouslyRemovedCell: Cell? {
        didSet {
            copyBuffer = previouslyRemovedCell
        }
    }
    var previouslyRemovedRow: Int?
    var notebookDelegate: NotebookTableViewDelegate?
    var selectedCellView: NotebookTableCell? {
        view(atColumn: selectedColumn, row: selectedRow, makeIfNecessary: false) as? NotebookTableCell
    }
    
    func selectCell(at tryRow: Int) {
        let row = tryRow < 0 ? 0 : tryRow >= numberOfRows ? numberOfRows - 1: tryRow
        selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        scrollRowToVisible(row)
    }
    
    func selectCellAbove() {
        selectCell(at: selectedRow - 1)
    }
    
    func selectCellBelow() {
        selectCell(at: selectedRow + 1)
    }
    
    func enterEditMode() {
        let textView = selectedCellView!.syntaxTextView.textView
        window?.makeFirstResponder(textView)
        textView.scrollRangeToVisible(textView.selectedRange())
    }
    
    func insertCell(at row: Int, cell: Cell = Cell()) {
        notebookDelegate!.insertCell(cell, at: row)
        insertRows(at: .init(integer: row))
        
        guard let previouslyRemovedRow else { return }
        if row < previouslyRemovedRow {
            self.previouslyRemovedRow = previouslyRemovedRow + 1
        }
    }
    
    func insertCellAbove(cell: Cell = Cell()) {
        insertCell(at: selectedRow, cell: cell)
        selectCellAbove()
    }
    
    func insertCellBelow(cell: Cell = Cell()) {
        insertCell(at: selectedRow + 1, cell: cell)
        selectCellBelow()
    }
    
    func runCell() {
        selectedCellView!.runCell()
    }
    
    func runCellSelectBelow() {
        runCell()
        let row = selectedRow + 1
        if row == numberOfRows {
            insertCell(at: row)
            selectCellBelow()
            enterEditMode()
        } else {
            selectCellBelow()
        }
    }
    
    func cutCell() {
        let row = selectedRow
        previouslyRemovedRow = row
        previouslyRemovedCell = notebookDelegate?.removeCell(at: row)
        removeRows(at: .init(integer: row))
        if numberOfRows == 0 {
            insertCell(at: row)
        }
        selectCell(at: row)
    }
    
    func copyCell() {
        copyBuffer = notebookDelegate?.selectedCell()
    }
    
    func pasteCellAbove() {
        guard let cell = copyBuffer else { return }
        insertCellAbove(cell: Cell(from: cell))
    }
    
    func pasteCellBelow() {
        guard let cell = copyBuffer else { return }
        insertCellBelow(cell: Cell(from: cell))
    }
    
    func undoCellDeletion() {
        guard let cell = previouslyRemovedCell,
              let row = previouslyRemovedRow else { return }
        insertCell(at: row, cell: cell)
    }
    
    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if event.keyCode == 36 && flags == .shift {  // shift+enter
            runCellSelectBelow()
        } else if event.keyCode == 36 {  // enter
            enterEditMode()
        } else if event.keyCode == 40 {  // k
            selectCellAbove()
        } else if event.keyCode == 38 {  // j
            selectCellBelow()
        } else if event.keyCode == 0 {   // a
            insertCellAbove()
        } else if event.keyCode == 11 {  // b
            insertCellBelow()
        } else if event.keyCode == 7 {  // x
            cutCell()
        } else if event.keyCode == 9 && flags == .shift {  // V
            pasteCellAbove()
        } else if event.keyCode == 9 {  // v
            pasteCellBelow()
        } else if event.keyCode == 6 {  // z
            undoCellDeletion()
        } else if event.keyCode == 8 {  // c
            copyCell()
        } else if event.keyCode == 1 && flags == .command { // cmd + s
            notebookDelegate?.save()
        } else {
//            print(event.keyCode)
            super.keyDown(with: event)
        }
    }
}
