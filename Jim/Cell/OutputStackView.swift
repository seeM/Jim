import Cocoa

class OutputStackView: NSStackView {
    override func addArrangedSubview(_ view: NSView) {
        super.addArrangedSubview(view)
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalTo: widthAnchor),
            view.leadingAnchor.constraint(equalTo: leadingAnchor),
        ])
        view.setContentHuggingPriority(.required, for: .vertical)
    }
}
