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
	
	func selectionDidChange() {
		
		guard let delegate = delegate else {
			return
		}
		
		colorTextView(lexerForSource: { (source) -> Lexer in
			return delegate.lexerForSource(source)
		})
		
		previousSelectedRange = textView.selectedRange
		
	}
	
    func didUpdateText() {
        
        refreshColors()
        delegate?.didChangeText(self)
        
    }
}

extension SyntaxTextView: NSTextViewDelegate {
		
		open func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
			
			let text = replacementString ?? ""
			
			return self.shouldChangeText(insertingText: text)
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
		
		open func textViewDidChangeSelection(_ notification: Notification) {
			
			contentDidChangeSelection()

		}
		
	}

extension SyntaxTextView {

	func shouldChangeText(insertingText: String) -> Bool {

		let selectedRange = textView.selectedRange

		let origInsertingText = insertingText

		var insertingText = insertingText
		
		if insertingText == "\n" {
			
			let nsText = textView.string as NSString
			
			var currentLine = nsText.substring(with: nsText.lineRange(for: textView.selectedRange))
			
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
		}
		
		let textStorage: NSTextStorage
		
		guard let _textStorage = textView.textStorage else {
			return true
		}
		
		textStorage = _textStorage
		
		if origInsertingText == "\n" {

			textStorage.replaceCharacters(in: selectedRange, with: insertingText)
			
			didUpdateText()
			
			updateSelectedRange(NSRange(location: selectedRange.lowerBound + insertingText.count, length: 0))

			return false
		}
		
		return true
	}
	
	func contentDidChangeSelection() {
		
		if ignoreSelectionChange {
			return
		}
		
		ignoreSelectionChange = true
		
		selectionDidChange()
		
		ignoreSelectionChange = false
		
	}
	
}
