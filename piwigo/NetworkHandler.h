//
//  NetworkHandler.h
//  WordSearch
//
//  Created by Spencer Baker on 9/10/14.
//  Copyright (c) 2014 CS 3450. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^NetworkBlock)(BOOL okay);
typedef void(^SuccessBlock)(id responseObject);
typedef void(^FailureBlock)(id responseObject, NSError *error);
typedef void(^CompletionBlock)(id responseObject);
typedef void(^CompletionBoolBlock)(BOOL response);

FOUNDATION_EXPORT NSString * const kBaseUrlPath;

@interface NetworkHandler : NSObject

+(void)getPost:(NSString*)path success:(SuccessBlock)success;
+(AFHTTPRequestOperation*)afPost:(SuccessBlock)success;

@end
