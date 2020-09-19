//
//  Utilities.m
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 15/08/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

#import "Utilities.h"

@implementation Utilities

+(NSString *)deviceNameForCode:(NSString *)deviceCode
{
    // See https://everyi.com/ipod-iphone-ipad-identification/index-how-to-identify-my-ipod-iphone-ipad.html
    // or https://apps.apple.com/fr/app/mactracker/id430255202?l=en&mt=12
    
    // iPhone
    if ([deviceCode isEqualToString:@"iPhone1,1"])    return @"iPhone";
    if ([deviceCode isEqualToString:@"iPhone1,2"])    return @"iPhone 3G";
    if ([deviceCode isEqualToString:@"iPhone2,1"])    return @"iPhone 3GS";
    if ([deviceCode isEqualToString:@"iPhone3,1"])    return @"iPhone 4 (GSM)";
    if ([deviceCode isEqualToString:@"iPhone3,2"])    return @"iPhone 4 (GSM)";
    if ([deviceCode isEqualToString:@"iPhone3,3"])    return @"iPhone 4 (CDMA)";
    if ([deviceCode isEqualToString:@"iPhone4,1"])    return @"iPhone 4s";
    if ([deviceCode isEqualToString:@"iPhone5,1"])    return @"iPhone 5 (GSM)";
    if ([deviceCode isEqualToString:@"iPhone5,2"])    return @"iPhone 5";
    if ([deviceCode isEqualToString:@"iPhone5,3"])    return @"iPhone 5c (GSM+CDMA)";
    if ([deviceCode isEqualToString:@"iPhone5,4"])    return @"iPhone 5c (CDMA)";
    if ([deviceCode isEqualToString:@"iPhone6,1"])    return @"iPhone 5s (GSM)";
    if ([deviceCode isEqualToString:@"iPhone6,2"])    return @"iPhone 5s (GSM+CDMA)";
    if ([deviceCode isEqualToString:@"iPhone7,1"])    return @"iPhone 6 Plus";
    if ([deviceCode isEqualToString:@"iPhone7,2"])    return @"iPhone 6";
    if ([deviceCode isEqualToString:@"iPhone8,1"])    return @"iPhone 6s";
    if ([deviceCode isEqualToString:@"iPhone8,2"])    return @"iPhone 6s Plus";
    if ([deviceCode isEqualToString:@"iPhone8,4"])    return @"iPhone SE";
    if ([deviceCode isEqualToString:@"iPhone9,1"])    return @"iPhone 7";
    if ([deviceCode isEqualToString:@"iPhone9,2"])    return @"iPhone 7 Plus";
    if ([deviceCode isEqualToString:@"iPhone9,3"])    return @"iPhone 7";
    if ([deviceCode isEqualToString:@"iPhone9,4"])    return @"iPhone 7 Plus";
    if ([deviceCode isEqualToString:@"iPhone10,1"])   return @"iPhone 8";
    if ([deviceCode isEqualToString:@"iPhone10,2"])   return @"iPhone 8 Plus";
    if ([deviceCode isEqualToString:@"iPhone10,3"])   return @"iPhone X";
    if ([deviceCode isEqualToString:@"iPhone10,4"])   return @"iPhone 8";
    if ([deviceCode isEqualToString:@"iPhone10,5"])   return @"iPhone 8 Plus";
    if ([deviceCode isEqualToString:@"iPhone10,6"])   return @"iPhone X";
    if ([deviceCode isEqualToString:@"iPhone11,2"])   return @"iPhone XS";
    if ([deviceCode isEqualToString:@"iPhone11,6"])   return @"iPhone XS Max";
    if ([deviceCode isEqualToString:@"iPhone11,8"])   return @"iPhone XR";
    if ([deviceCode isEqualToString:@"iPhone12,1"])   return @"iPhone 11";
    if ([deviceCode isEqualToString:@"iPhone12,3"])   return @"iPhone 11 Pro";
    if ([deviceCode isEqualToString:@"iPhone12,5"])   return @"iPhone 11 Pro Max";
    if ([deviceCode isEqualToString:@"iPhone12,8"])   return @"iPhone SE (2nd generation)";

    // iPad
    if ([deviceCode isEqualToString:@"iPad1,1"])      return @"iPad";
    if ([deviceCode isEqualToString:@"iPad2,1"])      return @"iPad 2 (Wi-Fi)";
    if ([deviceCode isEqualToString:@"iPad2,2"])      return @"iPad 2 (Wi-Fi + 3G GSM)";
    if ([deviceCode isEqualToString:@"iPad2,3"])      return @"iPad 2 (Wi-Fi + 3G CDMA)";
    if ([deviceCode isEqualToString:@"iPad2,4"])      return @"iPad 2 (Wi-Fi)";
    if ([deviceCode isEqualToString:@"iPad3,1"])      return @"iPad (3rd generation) (Wi-Fi)";
    if ([deviceCode isEqualToString:@"iPad3,2"])      return @"iPad (3rd generation) (Wi-Fi + Cellular)";
    if ([deviceCode isEqualToString:@"iPad3,3"])      return @"iPad (3rd generation) (Wi-Fi + Cellular)";
    if ([deviceCode isEqualToString:@"iPad3,4"])      return @"iPad (4th generation) (Wi-Fi)";
    if ([deviceCode isEqualToString:@"iPad3,5"])      return @"iPad (4th generation) (Wi-Fi + Cellular)";
    if ([deviceCode isEqualToString:@"iPad3,6"])      return @"iPad (4th generation) (Wi-Fi + Cellular)";
    if ([deviceCode isEqualToString:@"iPad6,11"])     return @"iPad (5th generation) (Wi-Fi)";
    if ([deviceCode isEqualToString:@"iPad6,12"])     return @"iPad (5th generation) (Wi-Fi + Cellular)";
    if ([deviceCode isEqualToString:@"iPad7,5"])      return @"iPad (6th generation) (Wi-Fi)";
    if ([deviceCode isEqualToString:@"iPad7,6"])      return @"iPad (6th generation) (Wi-Fi + Cellular)";
    if ([deviceCode isEqualToString:@"iPad7,11"])     return @"iPad (7th generation) (Wi-Fi)";
    if ([deviceCode isEqualToString:@"iPad7,12"])     return @"iPad (7th generation) (Wi-Fi + Cellular)";

    // iPad Air
    if ([deviceCode isEqualToString:@"iPad4,1"])      return @"iPad Air (Wi-Fi)";
    if ([deviceCode isEqualToString:@"iPad4,2"])      return @"iPad Air (Wi-Fi + Cellular)";
    if ([deviceCode isEqualToString:@"iPad5,3"])      return @"iPad Air 2 (Wi-Fi)";
    if ([deviceCode isEqualToString:@"iPad5,4"])      return @"iPad Air 2 (Wi-Fi + Cellular)";
    if ([deviceCode isEqualToString:@"iPad11,3"])     return @"iPad Air (3rd generation) (Wi-Fi)";
    if ([deviceCode isEqualToString:@"iPad11,4"])     return @"iPad Air (3rd generation) (Wi-Fi + Cellular)";

    // iPad Pro
    if ([deviceCode isEqualToString:@"iPad6,3"])      return @"iPad Pro 9.7-inch (Wi-Fi)";
    if ([deviceCode isEqualToString:@"iPad6,4"])      return @"iPad Pro 9.7-inch (Wi-Fi + Cellular)";
    if ([deviceCode isEqualToString:@"iPad6,7"])      return @"iPad Pro 12.9-inch (Wi-Fi)";
    if ([deviceCode isEqualToString:@"iPad6,8"])      return @"iPad Pro 12.9-inch (Wi-Fi + Cellular)";
    if ([deviceCode isEqualToString:@"iPad7,3"])      return @"iPad Pro 10.5 inch (Wi-Fi)";
    if ([deviceCode isEqualToString:@"iPad7,4"])      return @"iPad Pro 10.5 inch (Wi-Fi + Cellular)";
    if ([deviceCode isEqualToString:@"iPad6,7"])      return @"iPad Pro 12.9 inch (Wi-Fi)";
    if ([deviceCode isEqualToString:@"iPad6,8"])      return @"iPad Pro 12.9 inch (Wi-Fi + Cellular)";
    if ([deviceCode isEqualToString:@"iPad7,1"])      return @"iPad Pro 12.9-inch (2nd generation) (Wi-Fi)";
    if ([deviceCode isEqualToString:@"iPad7,2"])      return @"iPad Pro 12.9-inch (2nd generation) (Wi-Fi + Cellular)";
    if ([deviceCode isEqualToString:@"iPad7,3"])      return @"iPad Pro 10.5-inch (Wi-Fi)";
    if ([deviceCode isEqualToString:@"iPad7,4"])      return @"iPad Pro 10.5-inch (Wi-Fi + Cellular)";
    if ([deviceCode isEqualToString:@"iPad8,1"])      return @"iPad Pro 11-inch (Wi-Fi)";
    if ([deviceCode isEqualToString:@"iPad8,2"])      return @"iPad Pro 11-inch (Wi-Fi)";
    if ([deviceCode isEqualToString:@"iPad8,3"])      return @"iPad Pro 11-inch (Wi-Fi + Cellular)";
    if ([deviceCode isEqualToString:@"iPad8,4"])      return @"iPad Pro 11-inch (Wi-Fi + Cellular)";
    if ([deviceCode isEqualToString:@"iPad8,5"])      return @"iPad Pro 12.9-inch (3rd generation) (Wi-Fi)";
    if ([deviceCode isEqualToString:@"iPad8,6"])      return @"iPad Pro 12.9-inch (3rd generation) (Wi-Fi)";
    if ([deviceCode isEqualToString:@"iPad8,7"])      return @"iPad Pro 12.9-inch (3rd generation) (Wi-Fi + Cellular)";
    if ([deviceCode isEqualToString:@"iPad8,8"])      return @"iPad Pro 12.9-inch (3rd generation) (Wi-Fi + Cellular)";
    if ([deviceCode isEqualToString:@"iPad8,9"])      return @"iPad Pro 11-inch (2nd generation) (Wi-Fi)";
    if ([deviceCode isEqualToString:@"iPad8,10"])     return @"iPad Pro 11-inch (2nd generation) (Wi-Fi + Cellular)";
    if ([deviceCode isEqualToString:@"iPad8,11"])     return @"iPad Pro 12.9-inch (4th generation) (Wi-Fi)";
    if ([deviceCode isEqualToString:@"iPad8,12"])     return @"iPad Pro 12.9-inch (4th generation) (Wi-Fi + Cellular)";

    // iPad mini
    if ([deviceCode isEqualToString:@"iPad2,5"])      return @"iPad Mini (Wi-Fi)";
    if ([deviceCode isEqualToString:@"iPad2,6"])      return @"iPad Mini (Wi-Fi + Cellular)";
    if ([deviceCode isEqualToString:@"iPad2,7"])      return @"iPad Mini (Wi-Fi + Cellular MM)";
    if ([deviceCode isEqualToString:@"iPad4,4"])      return @"iPad mini 2 (Wi-Fi)";
    if ([deviceCode isEqualToString:@"iPad4,5"])      return @"iPad mini 2 (Wi-Fi + Cellular)";
    if ([deviceCode isEqualToString:@"iPad4,7"])      return @"iPad mini 3 (Wi-Fi)";
    if ([deviceCode isEqualToString:@"iPad4,8"])      return @"iPad mini 3 (Wi-Fi + Cellular)";
    if ([deviceCode isEqualToString:@"iPad5,1"])      return @"iPad mini 4 (Wi-Fi)";
    if ([deviceCode isEqualToString:@"iPad5,2"])      return @"iPad mini 4 (Wi-Fi + Cellular)";
    if ([deviceCode isEqualToString:@"iPad11,1"])     return @"iPad mini (5th generation) (Wi-Fi)";
    if ([deviceCode isEqualToString:@"iPad11,2"])     return @"iPad mini (5th generation) (Wi-Fi + Cellular)";

    // iPod
    if ([deviceCode isEqualToString:@"iPod1,1"])      return @"iPod touch";
    if ([deviceCode isEqualToString:@"iPod2,1"])      return @"iPod touch (2nd generation)";
    if ([deviceCode isEqualToString:@"iPod3,1"])      return @"iPod touch (3rd generation)";
    if ([deviceCode isEqualToString:@"iPod4,1"])      return @"iPod touch (4th generation)";
    if ([deviceCode isEqualToString:@"iPod5,1"])      return @"iPod touch (5th generation)";
    if ([deviceCode isEqualToString:@"iPod7,1"])      return @"iPod touch (6th generation)";
    if ([deviceCode isEqualToString:@"iPod9,1"])      return @"iPod touch (7th generation)";
    
    // Simulator
    if ([deviceCode isEqualToString:@"i386"])         return @"Simulator";
    if ([deviceCode isEqualToString:@"x86_64"])       return @"Simulator";
    
    return deviceCode;
}

@end
