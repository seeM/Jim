import AppKit
import Foundation

struct Theme {
    static let shared = Theme()
    let monoFont = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
    let font = NSFont.systemFont(ofSize: 14)
    let backgroundColor = NSColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0)
    
    let sidebarTintColor = NSColor(red: 0.494, green: 0.506, blue: 0.514, alpha: 1.0)
}
