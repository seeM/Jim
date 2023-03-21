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
    var inProgress = false {
        didSet {
            progress.isHidden = !inProgress
        }
    }
    
    init() {
        super.init(frame: .zero)

        button.target = self
        button.action = #selector(onClick)
        button.bezelStyle = .recessed
        button.showsBorderOnlyWhileMouseInside = true
        button.isHidden = true
        
        progress.isIndeterminate = true
        progress.startAnimation(self)
        progress.style = .spinning
        progress.controlSize = .small
        progress.isHidden = true
        
        addSubview(button)
        addSubview(progress)
        
        translatesAutoresizingMaskIntoConstraints = false
        button.translatesAutoresizingMaskIntoConstraints = false
        progress.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalTo: button.widthAnchor),
            heightAnchor.constraint(equalTo: button.heightAnchor),
            
            button.centerYAnchor.constraint(equalTo: centerYAnchor),
            button.centerXAnchor.constraint(equalTo: centerXAnchor),
        
            progress.centerYAnchor.constraint(equalTo: centerYAnchor),
            progress.centerXAnchor.constraint(equalTo: centerXAnchor),
        ])
        
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentHuggingPriority(.required, for: .vertical)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func onClick() {
        callback?()
    }
}
