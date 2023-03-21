import Cocoa

protocol NotebookTableViewDelegate: AnyObject {
    func insertCell(_ cell: Cell, at row: Int)
    func removeCell(at row: Int) -> Cell
    func selectedCell() -> Cell?
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
    var selectedCellView: CellView? {
        view(atColumn: selectedColumn, row: selectedRow, makeIfNecessary: false) as? CellView
    }
    
    func selectCell(at tryRow: Int) {
        let row = tryRow < 0 ? 0 : tryRow >= numberOfRows ? numberOfRows - 1: tryRow
        selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        scrollRowToVisible(row)
    }
    
    func selectCellAbove(_ n: Int = 1) {
        selectCell(at: selectedRow - n)
    }
    
    func selectCellBelow(_ n: Int = 1) {
        selectCell(at: selectedRow + n)
    }
    
    func selectFirstCell() {
        selectCell(at: 0)
    }
    
    func selectLastCell() {
        selectCell(at: numberOfRows - 1)
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
    
    func removeCell(at row: Int) -> Cell {
        removeRows(at: .init(integer: row))
        return notebookDelegate!.removeCell(at: row)
    }
    
    func moveCell(at row: Int, to: Int) {
        if to < 0 || to >= numberOfRows { return }
        let cell = removeCell(at: row)
        insertCell(at: to, cell: cell)
        selectCell(at: to)
    }
    
    func moveCellUp() {
        moveCell(at: selectedRow, to: selectedRow - 1)
    }
    
    func moveCellDown() {
        moveCell(at: selectedRow, to: selectedRow + 1)
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
        previouslyRemovedCell = removeCell(at: row)
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
    
    func interruptKernel() {
        Task { await JupyterService.shared.interruptKernel() }
    }
    
    func restartKernel() {
        Task { await JupyterService.shared.restartKernel() }
    }
    
    func setCellType(_ cellType: CellType) {
        // TODO: update the cell's outputs etc to match type...
        // TODO: make this undoable too?
        // TODO: more consistent way to access the cell?
        selectedCellView?.cell.cellType = cellType
        // TODO: very ugly
        let windowController = window!.windowController as! WindowController
        let title = cellType.rawValue.capitalized
        windowController.cellTypeComboBox.cell?.title = title
    }
    
    var keys = [UInt16]()
    var timer: Timer?
    
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
        } else if event.keyCode == 46 {  // m
            setCellType(.markdown)
        } else if event.keyCode == 15 {  // r
            setCellType(.raw)
        } else if event.keyCode == 16 {  // y
            setCellType(.code)
        } else if event.keyCode == 1 && flags == .command { // cmd + s
            notebookDelegate?.save()
        } else if event.keyCode == 5 && flags == .shift {
            selectLastCell()
        } else if event.keyCode == 2 && flags == .control { // ctrl + d
            selectCellBelow(10)
        } else if event.keyCode == 32 && flags == .control { // ctrl + u
            selectCellAbove(10)
        } else if [34, 5, 29].contains(where: { $0 == event.keyCode }) { // i, g, 00
            // TODO: Think we should rather keep a keymap.
            //       Make it a nested dict and somehow use that to determine whether to wait for more keys.
            keys.append(event.keyCode)
            if let timer {
                timer.invalidate()
            }
            if keys == [34, 34] { // i, i
                interruptKernel()
            } else if keys == [29, 29] {
                restartKernel()
            } else if keys == [5, 5] {
                selectFirstCell()
            } else {
                timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: false) { timer in
                    self.keys = []
                }
                return
            }
            keys = []
        } else {
            print(event.keyCode)
            super.keyDown(with: event)
        }
    }
}
