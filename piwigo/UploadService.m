//
//  UploadService.m
//  piwigo
//
//  Created by Spencer Baker on 1/28/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "UploadService.h"
#import "Model.h"

@implementation UploadService

+(NSArray*)uploadImage:(UIImage*)image
			  withName:(NSString*)imageName
			  forAlbum:(NSInteger)album
			onProgress:(void (^)(NSInteger current, NSInteger total))progress
		  OnCompletion:(void (^)(AFHTTPRequestOperation *operation, NSDictionary *response))completion
			 onFailure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))fail
{
	NSInteger chunkSize = 500 * 1024;
	NSData *imgData = UIImageJPEGRepresentation(image, 1.0);
	NSInteger length = imgData.length;
	NSInteger offset = 0;
	
	NSMutableArray *requests = [NSMutableArray new];
	NSInteger count = 0;
	NSInteger chunks = imgData.length / chunkSize;
	if(imgData.length % chunkSize != 0) {
		chunks++;
	}
	
	__block NSInteger countSuccess = 0;
	
	do {
		NSUInteger thisChunkSize = length - offset > chunkSize ? chunkSize : length - offset;
		NSData *chunk = [imgData subdataWithRange:NSMakeRange(offset, thisChunkSize)];
		
		AFHTTPRequestOperation *request = [self postMultiPart:kPiwigoImagesUpload
					parameters:@{@"name" : imageName,
								 @"album" : [NSString stringWithFormat:@"%@", @(album)],
								 @"chunk" : [NSString stringWithFormat:@"%@", @(count)],
								 @"chunks" : [NSString stringWithFormat:@"%@", @(chunks)],
								 @"data" : chunk}
					success:^(AFHTTPRequestOperation *operation, id responseObject) {
						countSuccess++;
						if(progress) {
							progress(countSuccess, chunks);
						}
						if(countSuccess == chunks && completion) {
							completion(operation, responseObject);
						}
					} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
						NSLog(@"%@", operation.responseObject);
						if(fail) {
							fail(operation, error);
						}
					}];
		offset += thisChunkSize;
		count++;
		[requests addObject:request];
	} while(offset < length);
	
	return requests;
	
//	return [self postMultiPart:kPiwigoImagesUpload
//					parameters:@{@"name" : imageName,
//								 @"album" : [NSString stringWithFormat:@"%@", @(album)],
//								 @"chunk" : @"0",
//								 @"chunks" : @"1",
//								 @"data" : chunk}
//					   success:^(AFHTTPRequestOperation *operation, id responseObject) {
//						   
//					   } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
//						   
//					   }];
}

@end
