//
//  UploadService.h
//  piwigo
//
//  Created by Spencer Baker on 1/28/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "NetworkHandler.h"

FOUNDATION_EXPORT NSString * const kUploadImage;

@class ImageUpload;

@interface UploadService : NetworkHandler

+(void)uploadImage:(NSData*)imageData
   withInformation:(NSDictionary*)imageInformation
		onProgress:(void (^)(NSInteger current, NSInteger total, NSInteger currentChunk, NSInteger totalChunks))progress
	  OnCompletion:(void (^)(AFHTTPRequestOperation *operation, NSDictionary *response))completion
		 onFailure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))fail;

+(AFHTTPRequestOperation*)setImageInfoForImageWithId:(NSString*)imageId
									 withInformation:(NSDictionary*)imageInformation
										  onProgress:(void (^)(NSInteger current, NSInteger total, NSInteger currentChunk, NSInteger totalChunks))progress
										OnCompletion:(void (^)(AFHTTPRequestOperation *operation, NSDictionary *response))completion
										   onFailure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))fail;

+(AFHTTPRequestOperation*)updateImageInfo:(ImageUpload*)imageInfo
							   onProgress:(void (^)(NSInteger current, NSInteger total, NSInteger currentChunk, NSInteger totalChunks))progress
							 OnCompletion:(void (^)(AFHTTPRequestOperation *operation, NSDictionary *response))completion
								onFailure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))fail;

@end
