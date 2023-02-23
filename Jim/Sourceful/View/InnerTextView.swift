//
//  InnerTextView.swift
//  SavannaKit
//
//  Created by Louis D'hauwe on 09/07/2017.
//  Copyright © 2017 Silver Fox. All rights reserved.
//

import Foundation
import CoreGraphics
import AppKit

protocol InnerTextViewDelegate: AnyObject {
    func didUpdateCursorFloatingState()
}

class InnerTextView: NSTextView {
    
    weak var innerDelegate: InnerTextViewDelegate?
    
    var theme: SyntaxColorTheme?
    
    func hideGutter() {
        gutterWidth = theme?.gutterStyle.minimumWidth ?? 0.0
    }
    
    func updateGutterWidth(for numberOfCharacters: Int) {
        
        let leftInset: CGFloat = 4.0
        let rightInset: CGFloat = 4.0
        
        let charWidth: CGFloat = 10.0
        
        gutterWidth = max(theme?.gutterStyle.minimumWidth ?? 0.0, CGFloat(numberOfCharacters) * charWidth + leftInset + rightInset)
        
    }
    
    var gutterWidth: CGFloat {
        set {
            
            textContainerInset = NSSize(width: newValue, height: 0)
            
        }
        get {
            
            return textContainerInset.width
            
        }
    }
    //	var gutterWidth: CGFloat = 0.0 {
    //		didSet {
    //
    //			textContainer.exclusionPaths = [UIBezierPath(rect: CGRect(x: 0.0, y: 0.0, width: gutterWidth, height: .greatestFiniteMagnitude))]
    //
    //		}
    //
    //	}
    
}
