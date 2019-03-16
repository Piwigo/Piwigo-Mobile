//
//  SplitLocalImages.h
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 16/03/2019.
//  Copyright © 2019 Piwigo.org. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SplitLocalImages : NSObject

+(NSArray *)splitImagesByDate:(NSArray *)images;

@end
