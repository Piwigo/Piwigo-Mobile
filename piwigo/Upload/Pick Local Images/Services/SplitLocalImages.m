//
//  SplitLocalImages.m
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 16/03/2019.
//  Copyright © 2019 Piwigo.org. All rights reserved.
//

#import <Photos/Photos.h>

#import "SplitLocalImages.h"

@implementation SplitLocalImages

+(NSArray *)splitImagesByDate:(NSArray *)images
{
    NSMutableArray *imagesByDate = [NSMutableArray new];
    
    // Initialise loop conditions
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSInteger comps = (NSCalendarUnitDay | NSCalendarUnitMonth | NSCalendarUnitYear);
    __block NSDateComponents *currentDateComponents = [calendar components:comps fromDate: [[images firstObject] creationDate]];
    __block NSDate *currentDate = [calendar dateFromComponents:currentDateComponents];
    NSMutableArray *imagesOfSameDate = [NSMutableArray new];
    
    // Sort imageAssets
    [images enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        // NOP if no object
        if(!obj) {
            return;
        }
        
        // Get current image creation date
        NSDateComponents *dateComponents = [calendar components:comps fromDate:[obj creationDate]];
        NSDate *date = [calendar dateFromComponents:dateComponents];
        
        // Image taken at same date?
        NSComparisonResult result = [date compare:currentDate];
        if (result == NSOrderedSame) {
            // Same date -> Append object to section
            [imagesOfSameDate addObject:obj];
        }
        else {
            // Append section to collection
            [imagesByDate addObject:[imagesOfSameDate copy]];
            
            // Initialise for next items
            [imagesOfSameDate removeAllObjects];
            currentDateComponents = [calendar components:comps fromDate: [obj creationDate]];
            currentDate = [calendar dateFromComponents:currentDateComponents];
            
            // Add current item
            [imagesOfSameDate addObject:obj];
        }
    }];
    
    // Append last section to collection
    [imagesByDate addObject:[imagesOfSameDate copy]];
    
    return imagesByDate;
}

@end
