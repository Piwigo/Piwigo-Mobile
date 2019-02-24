//
//  SortLocalImages.h
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 24/02/2019.
//  Copyright © 2019 Piwigo.org. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
    kPiwigoSortByNewest,
    kPiwigoSortByOldest,
    kPiwigoSortByNotUploaded,
    kPiwigoSortByCount
} kPiwigoSortBy;

@interface SortLocalImages : NSObject

+(NSString*)getNameForSortType:(kPiwigoSortBy)sortType;
+(void)getSortedImageArrayFromSortType:(kPiwigoSortBy)sortType
                             forImages:(NSArray*)images
                           forCategory:(NSInteger)category
                           forProgress:(void (^)(NSInteger onPage, NSInteger outOf))progress
                          onCompletion:(void (^)(NSArray *images))completion;

@end
