import AppKit

protocol SourceScrollerDelegate {
    func didMouseDown(_ scroller: SourceScroller)
}

class SourceScroller: NSScroller {
    var delegate: SourceScrollerDelegate?
    
    override func mouseDown(with event: NSEvent) {
        delegate?.didMouseDown(self)
        super.mouseDown(with: event)
    }
}
