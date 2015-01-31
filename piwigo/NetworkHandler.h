//
//  NetworkHandler.h
//  WordSearch
//
//  Created by Spencer Baker on 9/10/14.
//  Copyright (c) 2014 CS 3450. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^SuccessBlock)(id responseObject);

FOUNDATION_EXPORT NSString * const kPiwigoSessionLogin;
FOUNDATION_EXPORT NSString * const kPiwigoSessionGetStatus;
FOUNDATION_EXPORT NSString * const kPiwigoCategoriesGetList;
FOUNDATION_EXPORT NSString * const kPiwigoCategoriesGetImages;
FOUNDATION_EXPORT NSString * const kPiwigoImagesUpload;
FOUNDATION_EXPORT NSString * const kPiwigoImagesGetInfo;

@interface NetworkHandler : NSObject

+(AFHTTPRequestOperation*)post:(NSString*)path
				 URLParameters:(NSDictionary*)urlParams
					parameters:(NSDictionary*)parameters
					   success:(void (^)(AFHTTPRequestOperation *operation, id responseObject))success
					   failure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))fail;

+(AFHTTPRequestOperation*)postMultiPart:(NSString*)path
							 parameters:(NSDictionary*)parameters
								success:(void (^)(AFHTTPRequestOperation *operation, id responseObject))success
								failure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))fail;


+(void)showConnectionError:(NSError*)error;

@end
