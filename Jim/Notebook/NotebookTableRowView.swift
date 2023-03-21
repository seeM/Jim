import Cocoa


class NotebookTableRowView: NSTableRowView {
    // Never render the selected row's children as "emphasized"
    override var isEmphasized: Bool { get { false } set {} }
    
    override func drawSelection(in dirtyRect: NSRect) {
        // TODO: How do I get these values programmatically?
        let borderRect = NSInsetRect(self.bounds, 5, 7)
        
        let leftMarginRect = NSRect(x: borderRect.minX, y: borderRect.minY, width: 5, height: borderRect.height)
        NSColor(red: 0, green: 125/255, blue: 250/255, alpha: 1).setFill()
        NSBezierPath.init(roundedRect: leftMarginRect, xRadius: 2, yRadius: 2).fill()
    }
}
