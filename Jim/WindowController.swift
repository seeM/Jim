import Cocoa

// MARK: Toolbar -
extension NSToolbarItem.Identifier {
    static let back = NSToolbarItem.Identifier(rawValue: "Back")
}

extension NSWindowController: NSToolbarDelegate {
    public func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [
            .back,
            .sidebarTrackingSeparator
        ]
    }
}
