//
//  SyntaxTextView+TextViewDelegate.swift
//  SavannaKit
//
//  Created by Louis D'hauwe on 17/02/2018.
//  Copyright © 2018 Silver Fox. All rights reserved.
//

import Foundation
import AppKit

extension SyntaxTextView {

	func updateSelectedRange(_ range: NSRange) {
		textView.selectedRange = range
			
		self.textView.scrollRangeToVisible(range)
		
		self.delegate?.didChangeSelectedRange(self, selectedRange: range)
	}
	
    func didUpdateText() {
        
        refreshColors()
        delegate?.didChangeText(self)
        
    }
}

extension SyntaxTextView: NSTextViewDelegate {
    
    open func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
        let text = replacementString ?? ""
        return self.shouldChangeText(insertingText: text, shouldChangeTextIn: affectedCharRange)
    }

    open func textDidChange(_ notification: Notification) {
        guard let textView = notification.object as? NSTextView, textView == self.textView else {
            return
        }

        didUpdateText()
    }
    
    func refreshColors() {
        self.invalidateCachedTokens()
        
        if let delegate = delegate {
            colorTextView(lexerForSource: { (source) -> Lexer in
                return delegate.lexerForSource(source)
            })
        }
    }
    
    public func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        let event = NSApp.currentEvent
        if event!.modifierFlags.intersection(.deviceIndependentFlagsMask) == NSEvent.ModifierFlags.shift {
            delegate?.didCommit(self)
            return true
        }
        return false
    }
    
}

extension SyntaxTextView {

	func shouldChangeText(insertingText: String, shouldChangeTextIn affectedCharRange: NSRange? = nil) -> Bool {
        if ignoreShouldChange { return true }

        let selectedRange = textView.selectedRange
        var location = selectedRange.lowerBound

		let origInsertingText = insertingText

		var insertingText = insertingText
		
        if insertingText == "" && affectedCharRange != nil {
            // TODO: Remove paired
        } else if insertingText == "\n" {
            
            let nsText = textView.string as NSString
            
            var currentLine = nsText.substring(with: nsText.lineRange(for: selectedRange))
            
            // Remove trailing newline to avoid adding it to newLinePrefix
            if currentLine.hasSuffix("\n") {
                currentLine.removeLast()
            }
            
            var newLinePrefix = ""
            
            for char in currentLine {
                
                let tempSet = CharacterSet(charactersIn: "\(char)")
                
                if tempSet.isSubset(of: .whitespacesAndNewlines) {
                    newLinePrefix += "\(char)"
                } else {
                    break
                }
                
            }
            
            insertingText += newLinePrefix
            
            // TODO: Implement auto indent
//            let suffixesToIndent = [":", "[", "("]
//            for s in suffixesToIndent {
//                if currentLine.hasSuffix(s) {
//                    insertingText += "    " // TODO: don't hardcode indent size
//                    break
//                }
//            }

            location += insertingText.count
        } else {
            // TODO: Implement smart paired chars
//            let pairedChars = ["[]", "()"]
//            // If the user is typing a character that has a pair, insert the pair and move the cursor in between
//            for pair in pairedChars {
//                if insertingText == pair.prefix(1) {
//                    insertingText += pair.dropFirst()
//                    location += 1
//                    break
//                }
//            }
        }
        
        if insertingText != origInsertingText {
            ignoreShouldChange = true
            textView.insertText(insertingText, replacementRange: selectedRange)
            ignoreShouldChange = false
            didUpdateText()
            updateSelectedRange(NSRange(location: location, length: 0))
            return false
        }
		
		return true
	}
	
}
