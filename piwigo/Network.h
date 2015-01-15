//
//  Network.h
//  piwigo
//
//  Created by Spencer Baker on 1/15/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <Foundation/Foundation.h>

FOUNDATION_EXPORT NSString * const kBaseUrlPath;

typedef void(^SuccessBlock)(id responseObject);
typedef void(^FailureBlock)(id responseObject, NSError *error);

@interface Network : NSObject

+(void)post:(SuccessBlock)success;

+(AFHTTPRequestOperation*)afPost:(SuccessBlock)success;

@end
