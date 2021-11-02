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
        switch deviceCode {
        case "iPhone1,1":
            return "iPhone"
        case "iPhone1,2":
            return "iPhone 3G"
        case "iPhone2,1":
            return "iPhone 3GS"
        case "iPhone3,1":
            return "iPhone 4 (GSM)"
        case "iPhone3,2":
            return "iPhone 4 (GSM)"
        case "iPhone3,3":
            return "iPhone 4 (CDMA)"
        case "iPhone4,1":
            return "iPhone 4s"
        case "iPhone5,1":
            return "iPhone 5 (GSM)"
        case "iPhone5,2":
            return "iPhone 5"
        case "iPhone5,3":
            return "iPhone 5c (GSM+CDMA)"
        case "iPhone5,4":
            return "iPhone 5c (CDMA)"
        case "iPhone6,1":
            return "iPhone 5s (GSM)"
        case "iPhone6,2":
            return "iPhone 5s (GSM+CDMA)"
        case "iPhone7,1":
            return "iPhone 6 Plus"
        case "iPhone7,2":
            return "iPhone 6"
        case "iPhone8,1":
            return "iPhone 6s"
        case "iPhone8,2":
            return "iPhone 6s Plus"
        case "iPhone8,4":
            return "iPhone SE"
        case "iPhone9,1", "iPhone9,3":
            return "iPhone 7"
        case "iPhone9,2", "iPhone9,4":
            return "iPhone 7 Plus"
        case "iPhone10,1", "iPhone10,4":
            return "iPhone 8"
        case "iPhone10,2":
            return "iPhone 8 Plus"
        case "iPhone10,3", "iPhone10,6":
            return "iPhone X"
        case "iPhone10,5":
            return "iPhone 8 Plus"
        case "iPhone11,2":
            return "iPhone XS"
        case "iPhone11,6":
            return "iPhone XS Max"
        case "iPhone11,8":
            return "iPhone XR"
        case "iPhone12,1":
            return "iPhone 11"
        case "iPhone12,3":
            return "iPhone 11 Pro"
        case "iPhone12,5":
            return "iPhone 11 Pro Max"
        case "iPhone12,8":
            return "iPhone SE (2nd generation)"
        case "iPhone13,1":
            return "iPhone 12 mini"
        case "iPhone13,2":
            return "iPhone 12"
        case "iPhone13,3":
            return "iPhone 12 Pro"
        case "iPhone13,4":
            return "iPhone 12 Pro Max"
        case "iPhone14,2":
            return "iPhone 13 Pro"
        case "iPhone14,3":
            return "iPhone 13 Pro Max"
        case "iPhone14,4":
            return "iPhone 13 mini"
        case "iPhone14,5":
            return "iPhone 13"
        default:
            break
        }

        // MARK: - iPad
        switch deviceCode {
        case "iPad1,1":
            return "iPad"
        case "iPad2,1":
            return "iPad 2 (Wi-Fi)"
        case "iPad2,2":
            return "iPad 2 (Wi-Fi + 3G GSM)"
        case "iPad2,3":
            return "iPad 2 (Wi-Fi + 3G CDMA)"
        case "iPad2,4":
            return "iPad 2 (Wi-Fi)"
        case "iPad3,1":
            return "iPad (3rd generation) (Wi-Fi)"
        case "iPad3,2", "iPad3,3":
            return "iPad (3rd generation) (Wi-Fi + Cellular)"
        case "iPad3,4":
            return "iPad (4th generation) (Wi-Fi)"
        case "iPad3,5", "iPad3,6":
            return "iPad (4th generation) (Wi-Fi + Cellular)"
        case "iPad6,11":
            return "iPad (5th generation) (Wi-Fi)"
        case "iPad6,12":
            return "iPad (5th generation) (Wi-Fi + Cellular)"
        case "iPad7,5":
            return "iPad (6th generation) (Wi-Fi)"
        case "iPad7,6":
            return "iPad (6th generation) (Wi-Fi + Cellular)"
        case "iPad7,11":
            return "iPad (7th generation) (Wi-Fi)"
        case "iPad7,12":
            return "iPad (7th generation) (Wi-Fi + Cellular)"
        case "iPad11,6":
            return "iPad (8th generation) (Wi-Fi)"
        case "iPad11,7":
            return "iPad (8th generation) (Wi-Fi + Cellular)"
        default:
            break
        }

        // MARK: - iPad Air
        switch deviceCode {
        case "iPad4,1":
            return "iPad Air (Wi-Fi)"
        case "iPad4,2":
            return "iPad Air (Wi-Fi + Cellular)"
        case "iPad5,3":
            return "iPad Air 2 (Wi-Fi)"
        case "iPad5,4":
            return "iPad Air 2 (Wi-Fi + Cellular)"
        case "iPad11,3":
            return "iPad Air (3rd generation) (Wi-Fi)"
        case "iPad11,4":
            return "iPad Air (3rd generation) (Wi-Fi + Cellular)"
        case "iPad13,1":
            return "iPad Air (4th generation) (Wi-Fi)"
        case "iPad13,2":
            return "iPad Air (4th generation) (Wi-Fi + Cellular)"
        default:
            break
        }

        // MARK: - iPad Pro
        switch deviceCode {
        case "iPad6,3":
            return "iPad Pro 9.7-inch (Wi-Fi)"
        case "iPad6,4":
            return "iPad Pro 9.7-inch (Wi-Fi + Cellular)"
        case "iPad6,7":
            return "iPad Pro 12.9-inch (Wi-Fi)"
        case "iPad6,8":
            return "iPad Pro 12.9-inch (Wi-Fi + Cellular)"
        case "iPad7,1":
            return "iPad Pro 12.9-inch (2nd generation) (Wi-Fi)"
        case "iPad7,2":
            return "iPad Pro 12.9-inch (2nd generation) (Wi-Fi + Cellular)"
        case "iPad7,3":
            return "iPad Pro 10.5 inch (Wi-Fi)"
        case "iPad7,4":
            return "iPad Pro 10.5 inch (Wi-Fi + Cellular)"
        case "iPad8,1":
            return "iPad Pro 11-inch (Wi-Fi)"
        case "iPad8,2":
            return "iPad Pro 11-inch (Wi-Fi)"
        case "iPad8,3":
            return "iPad Pro 11-inch (Wi-Fi + Cellular)"
        case "iPad8,4":
            return "iPad Pro 11-inch (Wi-Fi + Cellular)"
        case "iPad8,5", "iPad8,6":
            return "iPad Pro 12.9-inch (3rd generation) (Wi-Fi)"
        case "iPad8,7", "iPad8,8":
            return "iPad Pro 12.9-inch (3rd generation) (Wi-Fi + Cellular)"
        case "iPad8,9":
            return "iPad Pro 11-inch (2nd generation) (Wi-Fi)"
        case "iPad8,10":
            return "iPad Pro 11-inch (2nd generation) (Wi-Fi + Cellular)"
        case "iPad8,11":
            return "iPad Pro 12.9-inch (4th generation) (Wi-Fi)"
        case "iPad8,12":
            return "iPad Pro 12.9-inch (4th generation) (Wi-Fi + Cellular)"
        case "iPad13,4", "iPad13,5":
            return "iPad Pro 11-inch (3rd generation) (Wi-Fi)"
        case "iPad13,6", "iPad13,7":
            return "iPad Pro 11-inch (3rd generation) (Wi-Fi + Cellular)"
        case "iPad13,8", "iPad13,9":
            return "iPad Pro 12.9-inch (5th generation) (Wi-Fi)"
        case "iPad13,10", "iPad13,11":
            return "iPad Pro 12.9-inch (5th generation) (Wi-Fi + Cellular)"
        default:
            break
        }

        // MARK: - iPad mini
        switch deviceCode {
        case "iPad2,5":
            return "iPad Mini (Wi-Fi)"
        case "iPad2,6":
            return "iPad Mini (Wi-Fi + Cellular)"
        case "iPad2,7":
            return "iPad Mini (Wi-Fi + Cellular MM)"
        case "iPad4,4":
            return "iPad mini 2 (Wi-Fi)"
        case "iPad4,5":
            return "iPad mini 2 (Wi-Fi + Cellular)"
        case "iPad4,7":
            return "iPad mini 3 (Wi-Fi)"
        case "iPad4,8":
            return "iPad mini 3 (Wi-Fi + Cellular)"
        case "iPad5,1":
            return "iPad mini 4 (Wi-Fi)"
        case "iPad5,2":
            return "iPad mini 4 (Wi-Fi + Cellular)"
        case "iPad11,1":
            return "iPad mini (5th generation) (Wi-Fi)"
        case "iPad11,2":
            return "iPad mini (5th generation) (Wi-Fi + Cellular)"
        default:
            break
        }

        // MARK: - iPod
        switch deviceCode {
        case "iPod1,1":
            return "iPod touch"
        case "iPod2,1":
            return "iPod touch (2nd generation)"
        case "iPod3,1":
            return "iPod touch (3rd generation)"
        case "iPod4,1":
            return "iPod touch (4th generation)"
        case "iPod5,1":
            return "iPod touch (5th generation)"
        case "iPod7,1":
            return "iPod touch (6th generation)"
        case "iPod9,1":
            return "iPod touch (7th generation)"
        default:
            break
        }

        // MARK: - Simulator
        switch deviceCode {
        case "i386", "x86_64":
            return "Simulator"
        default:
            break
        }

        return deviceCode
    }


    // MARK: - Photo Resolutions
    class func devicePotoResolution(forCode deviceCode: String?) -> String {
        guard let deviceCode = deviceCode else {
            return ""
        }
        
        // MARK: - iPhone
        switch deviceCode {
        case "iPhone1,1", "iPhone1,2":
            return "2 Mpx"
        case "iPhone2,1":
            return "3 Mpx"
        case "iPhone3,1", "iPhone3,2", "iPhone3,3":
            return "5 Mpx"
        case "iPhone4,1",
             "iPhone5,1", "iPhone5,2", "iPhone5,3", "iPhone5,4",
             "iPhone6,1", "iPhone6,2", "iPhone7,1", "iPhone7,2":
            return "8 Mpx"
        case "iPhone8,1", "iPhone8,2", "iPhone8,4",
             "iPhone9,1", "iPhone9,2", "iPhone9,3", "iPhone9,4",
             "iPhone10,1", "iPhone10,2", "iPhone10,3", "iPhone10,4", "iPhone10,5", "iPhone10,6",
             "iPhone11,2", "iPhone11,6", "iPhone11,8",
             "iPhone12,1", "iPhone12,3", "iPhone12,5", "iPhone12,8",
             "iPhone13,1", "iPhone13,2", "iPhone13,3", "iPhone13,4",
             "iPhone14,2", "iPhone14,3", "iPhone14,4", "iPhone14,5":
            return "12 Mpx"
        default:
            break
        }

        // MARK: - iPad
        switch deviceCode {
        case "iPad1,1":
            return ""
        case "iPad2,1", "iPad2,2", "iPad2,3", "iPad2,4":
            return "0.92 Mpx"
        case "iPad3,1", "iPad3,2", "iPad3,3", "iPad3,4", "iPad3,5", "iPad3,6":
            return "5 Mpx"
        case "iPad6,11", "iPad6,12",
             "iPad7,5", "iPad7,6", "iPad7,11", "iPad7,12",
             "iPad11,6", "iPad11,7":
            return "8 Mpx"
        default:
            break
        }

        // MARK: - iPad Air
        switch deviceCode {
        case "iPad4,1", "iPad4,2":
            return "5 Mpx"
        case "iPad5,3", "iPad5,4",
             "iPad11,3", "iPad11,4":
            return "8 Mpx"
        case "iPad13,1", "iPad13,2":
            return "12 Mpx"
        default:
            break
        }

        // MARK: - iPad Pro
        switch deviceCode {
        case "iPad6,7", "iPad6,8":
            return "8 Mpx"
        case "iPad6,3", "iPad6,4",
             "iPad7,1", "iPad7,2", "iPad7,3", "iPad7,4",
             "iPad8,1", "iPad8,2", "iPad8,3", "iPad8,4", "iPad8,5", "iPad8,6",
             "iPad8,7", "iPad8,8", "iPad8,9", "iPad8,10", "iPad8,11", "iPad8,12",
             "iPad13,4", "iPad13,5", "iPad13,6", "iPad13,7", "iPad13,8", "iPad13,9", "iPad13,10", "iPad13,11":
            return "12 Mpx"
        default:
            break
        }

        // MARK: - iPad mini
        switch deviceCode {
        case "iPad2,5", "iPad2,6", "iPad2,7",
             "iPad4,4", "iPad4,5", "iPad4,7", "iPad4,8":
            return "5 Mpx"
        case "iPad5,1", "iPad5,2", "iPad11,1", "iPad11,2":
            return "8 Mpx"
        default:
            break
        }

        // MARK: - iPod
        switch deviceCode {
        case "iPod1,1", "iPod2,1", "iPod3,1":
            return ""
        case "iPod4,1":
            return "0.92 Mpx"
        case "iPod5,1":
            return "5 Mpx"
        case "iPod7,1", "iPod9,1":
            return "8 Mpx"
        default:
            break
        }

        // MARK: - Simulator
        switch deviceCode {
        case "i386", "x86_64":
            return "? Mpx"
        default:
            break
        }

        return "? Mpx"
    }


    // MARK: - Video Capabilities
    class func deviceVideoCapabilities(forCode deviceCode: String?) -> String {
        guard let deviceCode = deviceCode else {
            return ""
        }
        
        // MARK: - iPhone
        switch deviceCode {
        case "iPhone1,1", "iPhone1,2", "iPhone2,1":
            return "VGA, 30 fps"
        case "iPhone3,1", "iPhone3,2", "iPhone3,3":
            return "HD, 30 fps"
        case "iPhone4,1",
             "iPhone5,1", "iPhone5,2", "iPhone5,3", "iPhone5,4",
             "iPhone6,1", "iPhone6,2",
             "iPhone7,1", "iPhone7,2":
            return "Full HD, 30 fps"
        case "iPhone8,1", "iPhone8,2", "iPhone8,4",
             "iPhone9,1", "iPhone9,2", "iPhone9,3", "iPhone9,4":
            return "4K, 30 fps"
        case "iPhone10,1", "iPhone10,2", "iPhone10,3", "iPhone10,4", "iPhone10,5", "iPhone10,6",
             "iPhone11,2", "iPhone11,6", "iPhone11,8",
             "iPhone12,1", "iPhone12,3", "iPhone12,5", "iPhone12,8",
             "iPhone13,1", "iPhone13,2",
             "iPhone14,2", "iPhone14,3", "iPhone14,4", "iPhone14,5":
            return "4K, 60 fps"
        case "iPhone13,3", "iPhone13,4":
            return "4K, 120 fps"
        default:
            break
        }

        // MARK: - iPad
        switch deviceCode {
        case "iPad1,1":
            return ""
        case "iPad2,1", "iPad2,2", "iPad2,3", "iPad2,4":
            return "VGA, 30 fps"
        case "iPad3,1", "iPad3,2", "iPad3,3", "iPad3,4", "iPad3,5", "iPad3,6":
            return "HD, 30 fps"
        case "iPad6,11", "iPad6,12",
             "iPad7,5", "iPad7,6", "iPad7,11", "iPad7,12",
             "iPad11,6", "iPad11,7":
            return "Full HD, 30 fps"
        default:
            break
        }

        // MARK: - iPad Air
        switch deviceCode {
        case "iPad4,1", "iPad4,2":
            return "HD, 30 fps"
        case "iPad5,3", "iPad5,4",
             "iPad11,3", "iPad11,4":
            return "Full HD, 30 fps"
        case "iPad13,1", "iPad13,2":
            return "4K, 30 fps"
        default:
            break
        }

        // MARK: - iPad Pro
        switch deviceCode {
        case "iPad6,3", "iPad6,4":
            return "HD, 30 fps"
        case "iPad6,7", "iPad6,8":
            return "Full HD, 30 fps"
        case "iPad7,1", "iPad7,2", "iPad7,3", "iPad7,4",
             "iPad8,1", "iPad8,2", "iPad8,3", "iPad8,4", "iPad8,5",
             "iPad8,6", "iPad8,7", "iPad8,8", "iPad8,9", "iPad8,10",
             "iPad8,11", "iPad8,12":
            return "4K, 30 fps"
        case "iPad13,4", "iPad13,5", "iPad13,6", "iPad13,7",
             "iPad13,8", "iPad13,9", "iPad13,10", "iPad13,11":
            return "4K, 60 fps"
        default:
            break
        }

        // MARK: - iPad mini
        switch deviceCode {
        case "iPad2,5", "iPad2,6", "iPad2,7",
             "iPad4,4", "iPad4,5", "iPad4,7", "iPad4,8":
            return "HD, 30 fps"
        case "iPad5,1", "iPad5,2",
             "iPad11,1", "iPad11,2":
            return "Full HD, 30 fps"
        default:
            break
        }

        // MARK: - iPod
        switch deviceCode {
        case "iPod1,1", "iPod2,1", "iPod3,1":
            return ""
        case "iPod4,1":
            return "HD, 30 fps"
        case "iPod5,1", "iPod7,1", "iPod9,1":
            return "Full HD, 30 fps"
        default:
            break
        }

        // MARK: - Simulator
        switch deviceCode {
        case "i386", "x86_64":
            return "? Mpx"
        default:
            break
        }

        return "? Mpx"
    }
}
