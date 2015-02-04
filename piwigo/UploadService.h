//
//  UploadService.h
//  piwigo
//
//  Created by Spencer Baker on 1/28/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "NetworkHandler.h"

FOUNDATION_EXPORT NSString * const kUploadImage;

@interface UploadService : NetworkHandler

+(void)uploadImage:(NSData*)imageData
		  withName:(NSString*)imageName
		  forAlbum:(NSInteger)album
   andPrivacyLevel:(NSInteger)privacyLevel
		onProgress:(void (^)(NSInteger current, NSInteger total, NSInteger currentChunk, NSInteger totalChunks))progress
	  OnCompletion:(void (^)(AFHTTPRequestOperation *operation, NSDictionary *response))completion
		 onFailure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))fail;

@end
