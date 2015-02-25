//
//  NotUploadedYet.h
//  piwigo
//
//  Created by Spencer Baker on 2/18/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NotUploadedYet : NSObject

+(void)getListOfImageNamesThatArentUploadedForCategory:(NSInteger)categoryId
										   forProgress:(void (^)(NSInteger onPage, NSInteger outOf))progress
										  onCompletion:(void (^)(NSArray *missingImages))completion;
@end
