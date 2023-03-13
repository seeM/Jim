import Cocoa

class InnerRunButton: NSButton {
    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .pointingHand)
    }
    
    override func becomeFirstResponder() -> Bool {
        print("Heyo")
        return super.becomeFirstResponder()
    }
}

class RunButton: NSView {
    let button = InnerRunButton()
    let progress = NSProgressIndicator()
    var callback: (() -> ())?
    
    init() {
        super.init(frame: .zero)

        button.target = self
        button.action = #selector(onClick)
        button.bezelStyle = .recessed
        button.showsBorderOnlyWhileMouseInside = true
        
        progress.isIndeterminate = true
        progress.startAnimation(self)
        progress.style = .spinning
        progress.controlSize = .small
        progress.isHidden = true
        
        addSubview(button)
        addSubview(progress)
        
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalTo: button.widthAnchor).isActive = true
        heightAnchor.constraint(equalTo: button.heightAnchor).isActive = true
        
        button.translatesAutoresizingMaskIntoConstraints = false
        button.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
        button.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
        
        progress.translatesAutoresizingMaskIntoConstraints = false
        progress.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
        progress.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func toggle() {
        button.isHidden = !button.isHidden
        progress.isHidden = !progress.isHidden
    }
    
    @objc private func onClick() {
        callback?()
    }
}
