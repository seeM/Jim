//
//  SyntaxTheme.swift
//  SavannaKit
//
//  Created by Louis D'hauwe on 24/01/2017.
//  Copyright © 2017 Silver Fox. All rights reserved.
//

import AppKit
import Foundation
import CoreGraphics

public protocol SyntaxColorTheme {
	
	var font: NSFont { get }
	
	var backgroundColor: NSColor { get }

	func globalAttributes() -> [NSAttributedString.Key: Any]

	func attributes(for token: Token) -> [NSAttributedString.Key: Any]
}
