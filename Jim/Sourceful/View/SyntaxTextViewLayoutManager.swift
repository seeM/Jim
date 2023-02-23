//
//  SyntaxTextViewLayoutManager.swift
//  SavannaKit iOS
//
//  Created by Louis D'hauwe on 09/03/2018.
//  Copyright © 2018 Silver Fox. All rights reserved.
//

import Foundation
import CoreGraphics
import AppKit

public enum EditorPlaceholderState {
    case active
    case inactive
}

public extension NSAttributedString.Key {
    
    static let editorPlaceholder = NSAttributedString.Key("editorPlaceholder")
    
}

class SyntaxTextViewLayoutManager: NSLayoutManager {
    
    override func drawGlyphs(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {
        
        guard let context = NSGraphicsContext.current else {
            return
        }
        
        let range = characterRange(forGlyphRange: glyphsToShow, actualGlyphRange: nil)
        
        var placeholders = [(CGRect, EditorPlaceholderState)]()
        
        textStorage?.enumerateAttribute(.editorPlaceholder, in: range, options: [], using: { (value, range, stop) in
            
            if let state = value as? EditorPlaceholderState {
                
                // the color set above
                let glyphRange = self.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
                let container = self.textContainer(forGlyphAt: glyphRange.location, effectiveRange: nil)
                
                let rect = self.boundingRect(forGlyphRange: glyphRange, in: container ?? NSTextContainer())
                
                placeholders.append((rect, state))
                
            }
            
        })
        
        context.saveGraphicsState()
        context.cgContext.translateBy(x: origin.x, y: origin.y)
        
        for (rect, state) in placeholders {
            
            // UIBezierPath with rounded
            
            let color: NSColor
            
            switch state {
            case .active:
                color = NSColor.white.withAlphaComponent(0.8)
            case .inactive:
                color = .darkGray
            }
            
            color.setFill()
            
            let radius: CGFloat = 4.0
            
            let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
            
            path.fill()
            
        }
        
        context.restoreGraphicsState()
        
        super.drawGlyphs(forGlyphRange: glyphsToShow, at: origin)
        
    }
    
}
