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
        guard let textView = notification.object as? NSTextView, textView == self.textView else { return }
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
        guard let event = NSApp.currentEvent else { return false }
        let modifierFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let isCommand = modifierFlags == [.command, .shift]
        if event.keyCode == 36 && modifierFlags == .shift {
            delegate?.didCommit(self)
            delegate?.nextCell(self)
            return true
        } else if event.keyCode == 125 && event.modifierFlags == .init(rawValue: 10486016) {
            if textView.selectedRange().location == textView.string.count {
                delegate?.nextCell(self)
                return true
            }
        } else if event.keyCode == 126 && event.modifierFlags == .init(rawValue: 10486016) {
            if textView.selectedRange().location == 0 {
                delegate?.previousCell(self)
                return true
            }
        } else if event.keyCode == 45 && isCommand {
            delegate?.nextCell(self)
            return true
        } else if event.keyCode == 35 && isCommand {
            delegate?.previousCell(self)
            return true
        } else if event.keyCode == 11 && isCommand {
            delegate?.createCellBelow(self)
            return true
        } else if event.keyCode == 0 && isCommand {
//            print("Create above")
//            delegate?.createCellAbove(self)
            return true
        } else if event.keyCode == 7 && isCommand {
            delegate?.cutCell(self)
            return true
        } else if event.keyCode == 9 && isCommand {
            delegate?.pasteCellBelow(self)
            return true
        } else if event.keyCode == 6 && isCommand {
            delegate?.undoCutCell(self)
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
            return false
        }
		
		return true
	}
	
}
