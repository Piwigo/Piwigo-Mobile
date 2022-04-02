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
        let encoded = (Int64(self)! + Int64(2323)) * Int64(7777) + Int64(3141592657)
        let key = String(encoded, radix: 23, uppercase: true)
        return String(repeating: "0", count: max(0, 8 - key.count)) + key
    }

    func decrypted() -> String {
        let key = Int64(self, radix: 23)!
        let decoded = String(((key - Int64(3141592657)) / Int64(7777)) - Int64(2323))
        return String(repeating: "0", count: max(0, 6 - decoded.count)) + decoded
    }
}
