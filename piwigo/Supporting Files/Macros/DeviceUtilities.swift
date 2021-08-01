//
//  DeviceUtilities.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 15/08/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//
//  Converted to Swift 5.1 by Eddy Lelièvre-Berna on 19/09/2020
//

@objc
class DeviceUtilities: NSObject {
    
    // MARK: - Device names
    @objc
    class func name(forCode deviceCode: String?) -> String {
        // See https://everyi.com/ipod-iphone-ipad-identification/index-how-to-identify-my-ipod-iphone-ipad.html
        // or https://apps.apple.com/fr/app/mactracker/id430255202?l=en&mt=12
        guard let deviceCode = deviceCode else {
            return "Unknown device"
        }
        
        // MARK: - iPhone
        if (deviceCode == "iPhone1,1") {
            return "iPhone"
        }
        if (deviceCode == "iPhone1,2") {
            return "iPhone 3G"
        }
        if (deviceCode == "iPhone2,1") {
            return "iPhone 3GS"
        }
        if (deviceCode == "iPhone3,1") {
            return "iPhone 4 (GSM)"
        }
        if (deviceCode == "iPhone3,2") {
            return "iPhone 4 (GSM)"
        }
        if (deviceCode == "iPhone3,3") {
            return "iPhone 4 (CDMA)"
        }
        if (deviceCode == "iPhone4,1") {
            return "iPhone 4s"
        }
        if (deviceCode == "iPhone5,1") {
            return "iPhone 5 (GSM)"
        }
        if (deviceCode == "iPhone5,2") {
            return "iPhone 5"
        }
        if (deviceCode == "iPhone5,3") {
            return "iPhone 5c (GSM+CDMA)"
        }
        if (deviceCode == "iPhone5,4") {
            return "iPhone 5c (CDMA)"
        }
        if (deviceCode == "iPhone6,1") {
            return "iPhone 5s (GSM)"
        }
        if (deviceCode == "iPhone6,2") {
            return "iPhone 5s (GSM+CDMA)"
        }
        if (deviceCode == "iPhone7,1") {
            return "iPhone 6 Plus"
        }
        if (deviceCode == "iPhone7,2") {
            return "iPhone 6"
        }
        if (deviceCode == "iPhone8,1") {
            return "iPhone 6s"
        }
        if (deviceCode == "iPhone8,2") {
            return "iPhone 6s Plus"
        }
        if (deviceCode == "iPhone8,4") {
            return "iPhone SE"
        }
        if (deviceCode == "iPhone9,1") {
            return "iPhone 7"
        }
        if (deviceCode == "iPhone9,2") {
            return "iPhone 7 Plus"
        }
        if (deviceCode == "iPhone9,3") {
            return "iPhone 7"
        }
        if (deviceCode == "iPhone9,4") {
            return "iPhone 7 Plus"
        }
        if (deviceCode == "iPhone10,1") {
            return "iPhone 8"
        }
        if (deviceCode == "iPhone10,2") {
            return "iPhone 8 Plus"
        }
        if (deviceCode == "iPhone10,3") {
            return "iPhone X"
        }
        if (deviceCode == "iPhone10,4") {
            return "iPhone 8"
        }
        if (deviceCode == "iPhone10,5") {
            return "iPhone 8 Plus"
        }
        if (deviceCode == "iPhone10,6") {
            return "iPhone X"
        }
        if (deviceCode == "iPhone11,2") {
            return "iPhone XS"
        }
        if (deviceCode == "iPhone11,6") {
            return "iPhone XS Max"
        }
        if (deviceCode == "iPhone11,8") {
            return "iPhone XR"
        }
        if (deviceCode == "iPhone12,1") {
            return "iPhone 11"
        }
        if (deviceCode == "iPhone12,3") {
            return "iPhone 11 Pro"
        }
        if (deviceCode == "iPhone12,5") {
            return "iPhone 11 Pro Max"
        }
        if (deviceCode == "iPhone12,8") {
            return "iPhone SE (2nd generation)"
        }
        if (deviceCode == "iPhone13,1") {
            return "iPhone 12 mini"
        }
        if (deviceCode == "iPhone13,2") {
            return "iPhone 12"
        }
        if (deviceCode == "iPhone13,3") {
            return "iPhone 12 Pro"
        }
        if (deviceCode == "iPhone13,4") {
            return "iPhone 12 Pro Max"
        }

        // MARK: - iPad
        if (deviceCode == "iPad1,1") {
            return "iPad"
        }
        if (deviceCode == "iPad2,1") {
            return "iPad 2 (Wi-Fi)"
        }
        if (deviceCode == "iPad2,2") {
            return "iPad 2 (Wi-Fi + 3G GSM)"
        }
        if (deviceCode == "iPad2,3") {
            return "iPad 2 (Wi-Fi + 3G CDMA)"
        }
        if (deviceCode == "iPad2,4") {
            return "iPad 2 (Wi-Fi)"
        }
        if (deviceCode == "iPad3,1") {
            return "iPad (3rd generation) (Wi-Fi)"
        }
        if (deviceCode == "iPad3,2") {
            return "iPad (3rd generation) (Wi-Fi + Cellular)"
        }
        if (deviceCode == "iPad3,3") {
            return "iPad (3rd generation) (Wi-Fi + Cellular)"
        }
        if (deviceCode == "iPad3,4") {
            return "iPad (4th generation) (Wi-Fi)"
        }
        if (deviceCode == "iPad3,5") {
            return "iPad (4th generation) (Wi-Fi + Cellular)"
        }
        if (deviceCode == "iPad3,6") {
            return "iPad (4th generation) (Wi-Fi + Cellular)"
        }
        if (deviceCode == "iPad6,11") {
            return "iPad (5th generation) (Wi-Fi)"
        }
        if (deviceCode == "iPad6,12") {
            return "iPad (5th generation) (Wi-Fi + Cellular)"
        }
        if (deviceCode == "iPad7,5") {
            return "iPad (6th generation) (Wi-Fi)"
        }
        if (deviceCode == "iPad7,6") {
            return "iPad (6th generation) (Wi-Fi + Cellular)"
        }
        if (deviceCode == "iPad7,11") {
            return "iPad (7th generation) (Wi-Fi)"
        }
        if (deviceCode == "iPad7,12") {
            return "iPad (7th generation) (Wi-Fi + Cellular)"
        }
        if (deviceCode == "iPad11,6") {
            return "iPad (8th generation) (Wi-Fi)"
        }
        if (deviceCode == "iPad11,7") {
            return "iPad (8th generation) (Wi-Fi + Cellular)"
        }

        // MARK: - iPad Air
        if (deviceCode == "iPad4,1") {
            return "iPad Air (Wi-Fi)"
        }
        if (deviceCode == "iPad4,2") {
            return "iPad Air (Wi-Fi + Cellular)"
        }
        if (deviceCode == "iPad5,3") {
            return "iPad Air 2 (Wi-Fi)"
        }
        if (deviceCode == "iPad5,4") {
            return "iPad Air 2 (Wi-Fi + Cellular)"
        }
        if (deviceCode == "iPad11,3") {
            return "iPad Air (3rd generation) (Wi-Fi)"
        }
        if (deviceCode == "iPad11,4") {
            return "iPad Air (3rd generation) (Wi-Fi + Cellular)"
        }
        if (deviceCode == "iPad13,1") {
            return "iPad Air (4th generation) (Wi-Fi)"
        }
        if (deviceCode == "iPad13,2") {
            return "iPad Air (4th generation) (Wi-Fi + Cellular)"
        }

        // MARK: - iPad Pro
        if (deviceCode == "iPad6,3") {
            return "iPad Pro 9.7-inch (Wi-Fi)"
        }
        if (deviceCode == "iPad6,4") {
            return "iPad Pro 9.7-inch (Wi-Fi + Cellular)"
        }
        if (deviceCode == "iPad6,7") {
            return "iPad Pro 12.9-inch (Wi-Fi)"
        }
        if (deviceCode == "iPad6,8") {
            return "iPad Pro 12.9-inch (Wi-Fi + Cellular)"
        }
        if (deviceCode == "iPad7,3") {
            return "iPad Pro 10.5 inch (Wi-Fi)"
        }
        if (deviceCode == "iPad7,4") {
            return "iPad Pro 10.5 inch (Wi-Fi + Cellular)"
        }
        if (deviceCode == "iPad6,7") {
            return "iPad Pro 12.9 inch (Wi-Fi)"
        }
        if (deviceCode == "iPad6,8") {
            return "iPad Pro 12.9 inch (Wi-Fi + Cellular)"
        }
        if (deviceCode == "iPad7,1") {
            return "iPad Pro 12.9-inch (2nd generation) (Wi-Fi)"
        }
        if (deviceCode == "iPad7,2") {
            return "iPad Pro 12.9-inch (2nd generation) (Wi-Fi + Cellular)"
        }
        if (deviceCode == "iPad7,3") {
            return "iPad Pro 10.5-inch (Wi-Fi)"
        }
        if (deviceCode == "iPad7,4") {
            return "iPad Pro 10.5-inch (Wi-Fi + Cellular)"
        }
        if (deviceCode == "iPad8,1") {
            return "iPad Pro 11-inch (Wi-Fi)"
        }
        if (deviceCode == "iPad8,2") {
            return "iPad Pro 11-inch (Wi-Fi)"
        }
        if (deviceCode == "iPad8,3") {
            return "iPad Pro 11-inch (Wi-Fi + Cellular)"
        }
        if (deviceCode == "iPad8,4") {
            return "iPad Pro 11-inch (Wi-Fi + Cellular)"
        }
        if (deviceCode == "iPad8,5") {
            return "iPad Pro 12.9-inch (3rd generation) (Wi-Fi)"
        }
        if (deviceCode == "iPad8,6") {
            return "iPad Pro 12.9-inch (3rd generation) (Wi-Fi)"
        }
        if (deviceCode == "iPad8,7") {
            return "iPad Pro 12.9-inch (3rd generation) (Wi-Fi + Cellular)"
        }
        if (deviceCode == "iPad8,8") {
            return "iPad Pro 12.9-inch (3rd generation) (Wi-Fi + Cellular)"
        }
        if (deviceCode == "iPad8,9") {
            return "iPad Pro 11-inch (2nd generation) (Wi-Fi)"
        }
        if (deviceCode == "iPad8,10") {
            return "iPad Pro 11-inch (2nd generation) (Wi-Fi + Cellular)"
        }
        if (deviceCode == "iPad8,11") {
            return "iPad Pro 12.9-inch (4th generation) (Wi-Fi)"
        }
        if (deviceCode == "iPad8,12") {
            return "iPad Pro 12.9-inch (4th generation) (Wi-Fi + Cellular)"
        }

        // MARK: - iPad mini
        if (deviceCode == "iPad2,5") {
            return "iPad Mini (Wi-Fi)"
        }
        if (deviceCode == "iPad2,6") {
            return "iPad Mini (Wi-Fi + Cellular)"
        }
        if (deviceCode == "iPad2,7") {
            return "iPad Mini (Wi-Fi + Cellular MM)"
        }
        if (deviceCode == "iPad4,4") {
            return "iPad mini 2 (Wi-Fi)"
        }
        if (deviceCode == "iPad4,5") {
            return "iPad mini 2 (Wi-Fi + Cellular)"
        }
        if (deviceCode == "iPad4,7") {
            return "iPad mini 3 (Wi-Fi)"
        }
        if (deviceCode == "iPad4,8") {
            return "iPad mini 3 (Wi-Fi + Cellular)"
        }
        if (deviceCode == "iPad5,1") {
            return "iPad mini 4 (Wi-Fi)"
        }
        if (deviceCode == "iPad5,2") {
            return "iPad mini 4 (Wi-Fi + Cellular)"
        }
        if (deviceCode == "iPad11,1") {
            return "iPad mini (5th generation) (Wi-Fi)"
        }
        if (deviceCode == "iPad11,2") {
            return "iPad mini (5th generation) (Wi-Fi + Cellular)"
        }

        // MARK: - iPod
        if (deviceCode == "iPod1,1") {
            return "iPod touch"
        }
        if (deviceCode == "iPod2,1") {
            return "iPod touch (2nd generation)"
        }
        if (deviceCode == "iPod3,1") {
            return "iPod touch (3rd generation)"
        }
        if (deviceCode == "iPod4,1") {
            return "iPod touch (4th generation)"
        }
        if (deviceCode == "iPod5,1") {
            return "iPod touch (5th generation)"
        }
        if (deviceCode == "iPod7,1") {
            return "iPod touch (6th generation)"
        }
        if (deviceCode == "iPod9,1") {
            return "iPod touch (7th generation)"
        }

        // MARK: - Simulator
        if (deviceCode == "i386") {
            return "Simulator"
        }
        if (deviceCode == "x86_64") {
            return "Simulator"
        }

        return deviceCode
    }


    // MARK: - Photo Resolutions
    class func devicePotoResolution(forCode deviceCode: String?) -> String {
        guard let deviceCode = deviceCode else {
            return ""
        }
        
        // MARK: - iPhone
        if (deviceCode == "iPhone1,1")  ||
            (deviceCode == "iPhone1,2") {
            return "2 Mpx"
        }
        if (deviceCode == "iPhone2,1") {
            return "3 Mpx"
        }
        if (deviceCode == "iPhone3,1")  ||
            (deviceCode == "iPhone3,2") ||
            (deviceCode == "iPhone3,3") {
            return "5 Mpx"
        }
        if (deviceCode == "iPhone4,1")  ||
            (deviceCode == "iPhone5,1") ||
            (deviceCode == "iPhone5,2") ||
            (deviceCode == "iPhone5,3") ||
            (deviceCode == "iPhone5,4") ||
            (deviceCode == "iPhone6,1") ||
            (deviceCode == "iPhone6,2") ||
            (deviceCode == "iPhone7,1") ||
            (deviceCode == "iPhone7,2") {
            return "8 Mpx"
        }
        if (deviceCode == "iPhone8,1")  ||
            (deviceCode == "iPhone8,2") ||
            (deviceCode == "iPhone8,4") ||
            (deviceCode == "iPhone9,1") ||
            (deviceCode == "iPhone9,2") ||
            (deviceCode == "iPhone9,3") ||
            (deviceCode == "iPhone9,4") ||
            (deviceCode == "iPhone10,1") ||
            (deviceCode == "iPhone10,2") ||
            (deviceCode == "iPhone10,3") ||
            (deviceCode == "iPhone10,4") ||
            (deviceCode == "iPhone10,5") ||
            (deviceCode == "iPhone10,6") ||
            (deviceCode == "iPhone11,2") ||
            (deviceCode == "iPhone11,6") ||
            (deviceCode == "iPhone11,8") ||
            (deviceCode == "iPhone12,1") ||
            (deviceCode == "iPhone12,3") ||
            (deviceCode == "iPhone12,5") ||
            (deviceCode == "iPhone12,8") ||
            (deviceCode == "iPhone13,1") ||
            (deviceCode == "iPhone13,2") ||
            (deviceCode == "iPhone13,3") ||
            (deviceCode == "iPhone13,4") {
            return "12 Mpx"
        }

        // MARK: - iPad
        if (deviceCode == "iPad1,1") {
            return ""
        }
        if (deviceCode == "iPad2,1")  ||
            (deviceCode == "iPad2,2") ||
            (deviceCode == "iPad2,3") ||
            (deviceCode == "iPad2,4") {
            return "0.92 Mpx"
        }
        if (deviceCode == "iPad3,1") ||
            (deviceCode == "iPad3,2") ||
            (deviceCode == "iPad3,3") ||
            (deviceCode == "iPad3,4") ||
            (deviceCode == "iPad3,5") ||
            (deviceCode == "iPad3,6") {
            return "5 Mpx"
        }
        if (deviceCode == "iPad6,11")  ||
            (deviceCode == "iPad6,12") ||
            (deviceCode == "iPad7,5")  ||
            (deviceCode == "iPad7,6")  ||
            (deviceCode == "iPad7,11") ||
            (deviceCode == "iPad7,12") ||
            (deviceCode == "iPad11,6") ||
            (deviceCode == "iPad11,7") {
            return "8 Mpx"
        }

        // MARK: - iPad Air
        if (deviceCode == "iPad4,1")  ||
            (deviceCode == "iPad4,2") {
            return "5 Mpx"
        }
        if (deviceCode == "iPad5,3")   ||
            (deviceCode == "iPad5,4")  ||
            (deviceCode == "iPad11,3") ||
            (deviceCode == "iPad11,4") {
            return "8 Mpx"
        }
        if (deviceCode == "iPad13,1") ||
            (deviceCode == "iPad13,2") {
            return "12 Mpx"
        }

        // MARK: - iPad Pro
        if (deviceCode == "iPad6,3") ||
            (deviceCode == "iPad6,4") {
            return "12 Mpx"
        }
        if (deviceCode == "iPad6,7") ||
            (deviceCode == "iPad6,8") ||
            (deviceCode == "iPad6,7") ||
            (deviceCode == "iPad6,8") {
            return "8 Mpx"
        }
        if (deviceCode == "iPad7,1") ||
            (deviceCode == "iPad7,2") ||
            (deviceCode == "iPad7,3") ||
            (deviceCode == "iPad7,4") ||
            (deviceCode == "iPad8,1") ||
            (deviceCode == "iPad8,2") ||
            (deviceCode == "iPad8,3") ||
            (deviceCode == "iPad8,4") ||
            (deviceCode == "iPad8,5") ||
            (deviceCode == "iPad8,6") ||
            (deviceCode == "iPad8,7") ||
            (deviceCode == "iPad8,8") ||
            (deviceCode == "iPad8,9") ||
            (deviceCode == "iPad8,10") ||
            (deviceCode == "iPad8,11") ||
            (deviceCode == "iPad8,12") {
            return "12 Mpx"
        }

        // MARK: - iPad mini
        if (deviceCode == "iPad2,5")  ||
            (deviceCode == "iPad2,6") ||
            (deviceCode == "iPad2,7") ||
            (deviceCode == "iPad4,4") ||
            (deviceCode == "iPad4,5") ||
            (deviceCode == "iPad4,7") ||
            (deviceCode == "iPad4,8") {
            return "5 Mpx"
        }
        if (deviceCode == "iPad5,1")   ||
            (deviceCode == "iPad5,2")  ||
            (deviceCode == "iPad11,1") ||
            (deviceCode == "iPad11,2") {
            return "8 Mpx"
        }

        // MARK: - iPod
        if (deviceCode == "iPod1,1")  ||
            (deviceCode == "iPod2,1") ||
            (deviceCode == "iPod3,1") {
            return ""
        }
        if (deviceCode == "iPod4,1") {
            return "0.92 Mpx"
        }
        if (deviceCode == "iPod5,1") {
            return "5 Mpx"
        }
        if (deviceCode == "iPod7,1") ||
            (deviceCode == "iPod9,1") {
            return "8 Mpx"
        }

        // MARK: - Simulator
        if (deviceCode == "i386") {
            return "? Mpx"
        }
        if (deviceCode == "x86_64") {
            return "? Mpx"
        }

        return "? Mpx"
    }


    // MARK: - Video Capabilities
    class func deviceVideoCapabilities(forCode deviceCode: String?) -> String {
        guard let deviceCode = deviceCode else {
            return ""
        }
        
        // MARK: - iPhone
        if (deviceCode == "iPhone1,1")  ||
            (deviceCode == "iPhone1,2") ||
            (deviceCode == "iPhone2,1") {
            return "VGA, 30 fps"
        }
        if (deviceCode == "iPhone3,1")  ||
            (deviceCode == "iPhone3,2") ||
            (deviceCode == "iPhone3,3") {
            return "HD, 30 fps"
        }
        if (deviceCode == "iPhone4,1")  ||
            (deviceCode == "iPhone5,1") ||
            (deviceCode == "iPhone5,2") ||
            (deviceCode == "iPhone5,3") ||
            (deviceCode == "iPhone5,4") ||
            (deviceCode == "iPhone6,1") ||
            (deviceCode == "iPhone6,2") ||
            (deviceCode == "iPhone7,1") ||
            (deviceCode == "iPhone7,2") {
            return "Full HD, 30 fps"
        }
        if (deviceCode == "iPhone8,1")  ||
            (deviceCode == "iPhone8,2") ||
            (deviceCode == "iPhone8,4") ||
            (deviceCode == "iPhone9,1") ||
            (deviceCode == "iPhone9,2") ||
            (deviceCode == "iPhone9,3") ||
            (deviceCode == "iPhone9,4") {
            return "4K, 30 fps"
        }
        if (deviceCode == "iPhone10,1") ||
            (deviceCode == "iPhone10,2") ||
            (deviceCode == "iPhone10,3") ||
            (deviceCode == "iPhone10,4") ||
            (deviceCode == "iPhone10,5") ||
            (deviceCode == "iPhone10,6") ||
            (deviceCode == "iPhone11,2") ||
            (deviceCode == "iPhone11,6") ||
            (deviceCode == "iPhone11,8") ||
            (deviceCode == "iPhone12,1") ||
            (deviceCode == "iPhone12,3") ||
            (deviceCode == "iPhone12,5") ||
            (deviceCode == "iPhone12,8") ||
            (deviceCode == "iPhone13,1") ||
            (deviceCode == "iPhone13,2") {
            return "4K, 60 fps"
        }
        if (deviceCode == "iPhone13,3") ||
            (deviceCode == "iPhone13,4") {
            return "4K, 120 fps"
        }

        // MARK: - iPad
        if (deviceCode == "iPad1,1") {
            return ""
        }
        if (deviceCode == "iPad2,1")  ||
            (deviceCode == "iPad2,2") ||
            (deviceCode == "iPad2,3") ||
            (deviceCode == "iPad2,4") {
            return "VGA, 30 fps"
        }
        if (deviceCode == "iPad3,1") ||
            (deviceCode == "iPad3,2") ||
            (deviceCode == "iPad3,3") ||
            (deviceCode == "iPad3,4") ||
            (deviceCode == "iPad3,5") ||
            (deviceCode == "iPad3,6") {
            return "HD, 30 fps"
        }
        if (deviceCode == "iPad6,11")  ||
            (deviceCode == "iPad6,12") ||
            (deviceCode == "iPad7,5")  ||
            (deviceCode == "iPad7,6")  ||
            (deviceCode == "iPad7,11") ||
            (deviceCode == "iPad7,12") ||
            (deviceCode == "iPad11,6") ||
            (deviceCode == "iPad11,7") {
            return "Full HD, 30 fps"
        }

        // MARK: - iPad Air
        if (deviceCode == "iPad4,1")  ||
            (deviceCode == "iPad4,2") {
            return "HD, 30 fps"
        }
        if (deviceCode == "iPad5,3")   ||
            (deviceCode == "iPad5,4")  ||
            (deviceCode == "iPad11,3") ||
            (deviceCode == "iPad11,4") {
            return "Full HD, 30 fps"
        }
        if (deviceCode == "iPad13,1") ||
            (deviceCode == "iPad13,2") {
            return "4K, 30 fps"
        }

        // MARK: - iPad Pro
        if (deviceCode == "iPad6,3") ||
            (deviceCode == "iPad6,4") {
            return "4K, 30 fps"
        }
        if (deviceCode == "iPad6,7") ||
            (deviceCode == "iPad6,8") ||
            (deviceCode == "iPad6,7") ||
            (deviceCode == "iPad6,8") {
            return "Full HD, 30 fps"
        }
        if (deviceCode == "iPad7,1") ||
            (deviceCode == "iPad7,2") ||
            (deviceCode == "iPad7,3") ||
            (deviceCode == "iPad7,4") ||
            (deviceCode == "iPad8,1") ||
            (deviceCode == "iPad8,2") ||
            (deviceCode == "iPad8,3") ||
            (deviceCode == "iPad8,4") ||
            (deviceCode == "iPad8,5") ||
            (deviceCode == "iPad8,6") ||
            (deviceCode == "iPad8,7") ||
            (deviceCode == "iPad8,8") ||
            (deviceCode == "iPad8,9") ||
            (deviceCode == "iPad8,10") {
            return "4K, 30 fps"
        }
        if (deviceCode == "iPad8,11") ||
            (deviceCode == "iPad8,12") {
            return "4K, 60 fps"
        }

        // MARK: - iPad mini
        if (deviceCode == "iPad2,5")  ||
            (deviceCode == "iPad2,6") ||
            (deviceCode == "iPad2,7") ||
            (deviceCode == "iPad4,4") ||
            (deviceCode == "iPad4,5") ||
            (deviceCode == "iPad4,7") ||
            (deviceCode == "iPad4,8") {
            return "HD, 30 fps"
        }
        if (deviceCode == "iPad5,1")   ||
            (deviceCode == "iPad5,2")  ||
            (deviceCode == "iPad11,1") ||
            (deviceCode == "iPad11,2") {
            return "Full HD, 30 fps"
        }

        // MARK: - iPod
        if (deviceCode == "iPod1,1")  ||
            (deviceCode == "iPod2,1") ||
            (deviceCode == "iPod3,1") {
            return ""
        }
        if (deviceCode == "iPod4,1") {
            return "HD, 30 fps"
        }
        if (deviceCode == "iPod5,1") ||
            (deviceCode == "iPod7,1") ||
            (deviceCode == "iPod9,1") {
            return "Full HD, 30 fps"
        }

        // MARK: - Simulator
        if (deviceCode == "i386") {
            return "? Mpx"
        }
        if (deviceCode == "x86_64") {
            return "? Mpx"
        }

        return "? Mpx"
    }
}
