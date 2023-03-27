import AppKit
import Foundation

struct Theme {
    static let shared = Theme()
    let monoFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    let font = NSFont.systemFont(ofSize: 12)
    let backgroundColor = NSColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0)
}
