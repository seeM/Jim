import Cocoa

class OutputStackView: NSStackView {
    override func addArrangedSubview(_ view: NSView) {
        super.addArrangedSubview(view)
        view.setContentHuggingPriority(.required, for: .vertical)
    }
}
