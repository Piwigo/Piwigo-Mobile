//
//  String+AppTools.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 26/03/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation

extension String {

    // MARK: - Passcode Encryption
    func encrypted() -> String {
        let encoded = (Int(self)! + 2323) * 7777 + 3141592657
        let key = String(encoded, radix: 23, uppercase: true)
        return String(repeating: "0", count: max(0, 8 - key.count)) + key
    }

    func decrypted() -> String {
        let key = Int(self, radix: 23)!
        let decoded = String(((key - 3141592657) / 7777) - 2323)
        return String(repeating: "0", count: max(0, 6 - decoded.count)) + decoded
    }
}
