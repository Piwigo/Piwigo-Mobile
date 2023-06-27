//
//  String+AppTools.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 25/12/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation

extension String {

    // MARK: - HTML conversion
    var htmlToAttributedString: NSAttributedString {

        // Remove any white space or newline located at the beginning or end of the description
        var comment = self
        if comment.isEmpty { return NSAttributedString() }
        while comment.count > 0, comment.first!.isNewline || comment.first!.isWhitespace {
            comment.removeFirst()
        }
        while comment.count > 0, comment.last!.isNewline || comment.last!.isWhitespace  {
            comment.removeLast()
        }

        // Convert HTML code
        guard let data = comment.data(using: .utf8) else { return NSAttributedString(string: "") }
        do {
            let attributedStr = try NSMutableAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.html, .characterEncoding:String.Encoding.utf8.rawValue], documentAttributes: nil)
            
            // Removes superfluous line feed
            while !attributedStr.string.isEmpty
                    && CharacterSet.newlines.contains(attributedStr.string.unicodeScalars.last!) {
                attributedStr.deleteCharacters(in: NSRange(location: attributedStr.length - 1, length: 1))
            }
            return attributedStr
        } catch {
            return NSAttributedString(string: self)
        }
    }
    
    var htmlToString: String {
        return htmlToAttributedString.string
    }
}
