import AppKit
import Foundation

public struct Theme {
    static let shared = Theme()
    public let font = NSFont(name: "Menlo", size: 12)!
    public let backgroundColor = NSColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0)
}
