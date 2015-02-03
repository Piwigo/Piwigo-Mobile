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

+(void)uploadImage:(NSData*)imageData
		  withName:(NSString*)imageName
		  forAlbum:(NSInteger)album
   andPrivacyLevel:(NSInteger)privacyLevel
			onProgress:(void (^)(NSInteger current, NSInteger total))progress
		  OnCompletion:(void (^)(AFHTTPRequestOperation *operation, NSDictionary *response))completion
			 onFailure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))fail
{
	NSInteger chunkSize = 500 * 1024;
	
	NSInteger chunks = imageData.length / chunkSize;
	if(imageData.length % chunkSize != 0) {
		chunks++;
	}
	AFHTTPRequestOperation *chunk = [self sendChunk:imageData
											 offset:0
										   withName:imageName
										   forAlbum:album
									   privacyLevel:privacyLevel
											onCount:0
										 countTotal:chunks
									   OnCompletion:completion
										  onFailure:fail];
	
	[chunk setDownloadProgressBlock:^(NSUInteger bytesRead, long long totalBytesRead, long long totalBytesExpectedToRead) {
		if(progress)
		{
			progress(totalBytesRead, totalBytesExpectedToRead);
		}
	}];
}

+(AFHTTPRequestOperation*)sendChunk:(NSData*)data
							 offset:(NSInteger) offset
						   withName:(NSString*)imageName
						   forAlbum:(NSInteger)album
					   privacyLevel:(NSInteger)privacyLevel
							onCount:(NSInteger)count
						 countTotal:(NSInteger)chunks
					   OnCompletion:(void (^)(AFHTTPRequestOperation *operation, NSDictionary *response))completion
						  onFailure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))fail
{
	NSInteger chunkSize = 500 * 1024;
	NSInteger length = data.length;
	NSUInteger thisChunkSize = length - offset > chunkSize ? chunkSize : length - offset;
	NSData *chunk = [data subdataWithRange:NSMakeRange(offset, thisChunkSize)];
	
	NSInteger nextChunkNumber = count + 1;
	NSInteger oldOffset = offset;
	offset += thisChunkSize;
	
	return [self postMultiPart:kPiwigoImagesUpload
	   parameters:@{@"name" : imageName,
					@"album" : [NSString stringWithFormat:@"%@", @(album)],
					@"privacyLevel" : [NSString stringWithFormat:@"%@", @(privacyLevel)],
					@"chunk" : [NSString stringWithFormat:@"%@", @(count)],
					@"chunks" : [NSString stringWithFormat:@"%@", @(chunks)],
					@"data" : chunk}
		  success:^(AFHTTPRequestOperation *operation, id responseObject) {
			  NSLog(@"completed %@/%@", @(count + 1), @(chunks));
			  if(count >= chunks - 1) {
				  // done, return
				  if(completion) {
					  completion(operation, responseObject);
				  }
			  } else {
				  // keep going!
				  [self sendChunk:data
						   offset:offset
						 withName:imageName
						 forAlbum:album
					 privacyLevel:privacyLevel
						  onCount:nextChunkNumber
					   countTotal:chunks
					 OnCompletion:completion
						onFailure:fail];
			  }
		  } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
			  // failed, send it again
			  [self sendChunk:data
					   offset:oldOffset
					 withName:imageName
					 forAlbum:album
				 privacyLevel:privacyLevel
					  onCount:count
				   countTotal:chunks
				 OnCompletion:completion
					onFailure:fail];
		  }];
}

@end
