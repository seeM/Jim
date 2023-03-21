import Foundation

extension String {
	
	func nsRange(fromRange range: Range<Index>) -> NSRange {
		return NSRange(range, in: self)
	}

}
