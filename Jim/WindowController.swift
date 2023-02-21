//
//  WindowController.swift
//  Jim
//
//  Created by Wasim Lorgat on 2023/02/21.
//

import Cocoa

class WindowController: NSWindowController { }

// MARK: Toolbar -
private extension NSToolbarItem.Identifier {
    static let back = NSToolbarItem.Identifier(rawValue: "Back")
}

extension WindowController: NSToolbarDelegate {
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [
            .back,
            .sidebarTrackingSeparator,
            .showFonts,
            .print,
            .space,
            .flexibleSpace
        ]
    }
    
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        switch itemIdentifier {
        case .back:
            let toolbarItem = NSToolbarItem(itemIdentifier: .back)
            toolbarItem.label = "Back"
            toolbarItem.paletteLabel = "Back"
            toolbarItem.toolTip = "Go back"
            toolbarItem.target = self
            toolbarItem.action = #selector(self.goBack)
//            toolbarItem.action = nil
            toolbarItem.image = NSImage(systemSymbolName: "chevron.left", accessibilityDescription: nil)
            toolbarItem.isEnabled = false
            
            let menuItem = NSMenuItem()
            menuItem.submenu = nil
            menuItem.title = "Back"
            
            toolbarItem.menuFormRepresentation = menuItem
            return toolbarItem
        default: return NSToolbarItem(itemIdentifier: itemIdentifier)
        }
    }
    
    @objc func goBack() {
        print("Go back")
    }
}
