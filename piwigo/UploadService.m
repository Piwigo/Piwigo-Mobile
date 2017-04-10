//
//  UploadService.m
//  piwigo
//
//  Created by Spencer Baker on 1/28/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "UploadService.h"
#import "Model.h"
#import "ImageUpload.h"
#import "PiwigoTagData.h"
#import "CategoriesData.h"

@implementation UploadService

+(void)uploadImage:(NSData*)imageData
   withInformation:(NSDictionary*)imageInformation
			onProgress:(void (^)(NSInteger current, NSInteger total, NSInteger currentChunk, NSInteger totalChunks))progress
		  OnCompletion:(void (^)(AFHTTPRequestOperation *operation, NSDictionary *response))completion
			 onFailure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))fail
{
	NSInteger chunkSize = 500 * 1024;
	
	NSInteger chunks = imageData.length / chunkSize;
	if(imageData.length % chunkSize != 0) {
		chunks++;
	}
	
	[self sendChunk:imageData
	WithInformation:[imageInformation mutableCopy]
						 forOffset:0
						   onChunk:0
					forTotalChunks:(NSInteger)chunks
						onProgress:progress
					  OnCompletion:completion
						 onFailure:fail];
}

+(void)sendChunk:(NSData*)imageData
 WithInformation:(NSMutableDictionary*)imageInformation
					  forOffset:(NSInteger)offset
						onChunk:(NSInteger)count
				 forTotalChunks:(NSInteger)chunks
					 onProgress:(void (^)(NSInteger current, NSInteger total, NSInteger currentChunk, NSInteger totalChunks))progress
				   OnCompletion:(void (^)(AFHTTPRequestOperation *operation, NSDictionary *response))completion
					  onFailure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))fail
{
	NSInteger chunkSize = 500 * 1024;
	NSInteger length = [imageData length];
	NSUInteger thisChunkSize = length - offset > chunkSize ? chunkSize : length - offset;
	NSData *chunk = [imageData subdataWithRange:NSMakeRange(offset, thisChunkSize)];
	
	NSInteger nextChunkNumber = count + 1;
	offset += thisChunkSize;
	
	[imageInformation setObject:chunk forKey:kPiwigoImagesUploadParamData];
	[imageInformation setObject:[NSString stringWithFormat:@"%@", @(count)] forKey:kPiwigoImagesUploadParamChunk];
	[imageInformation setObject:[NSString stringWithFormat:@"%@", @(chunks)] forKey:kPiwigoImagesUploadParamChunks];
	
	AFHTTPRequestOperation *chunkRequest = [self postMultiPart:kPiwigoImagesUpload
	   parameters:imageInformation
		  success:^(AFHTTPRequestOperation *operation, id responseObject) {
			  
			  if(count >= chunks - 1) {
				  // done, return
				  if(completion) {
					  completion(operation, responseObject);
				  }
			  } else {
				  // keep going!
				  [self sendChunk:imageData
				  WithInformation:imageInformation
									   forOffset:offset
										 onChunk:nextChunkNumber
								  forTotalChunks:chunks
									  onProgress:progress
									OnCompletion:completion
									   onFailure:fail];
			  }
		  } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
			  // failed!
			  if(fail)
			  {
				  fail(operation, error);
			  }
		  }];
	
	[chunkRequest setUploadProgressBlock:^(NSUInteger bytesWritten, long long totalBytesWritten, long long totalBytesExpectedToWrite) {
		if(progress)
		{
			progress((NSInteger)totalBytesWritten, (NSInteger)totalBytesExpectedToWrite, count + 1, chunks);
		}
	}];
}

+(AFHTTPRequestOperation*)setImageInfoForImageWithId:(NSString*)imageId
									 withInformation:(NSDictionary*)imageInformation
										  onProgress:(void (^)(NSUInteger bytesRead, long long totalBytesRead, long long totalBytesExpectedToRead))progress
										OnCompletion:(void (^)(AFHTTPRequestOperation *operation, NSDictionary *response))completion
										   onFailure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))fail
{
	
	NSString *tagIdList = [[[imageInformation objectForKey:kPiwigoImagesUploadParamTags] valueForKey:@"description"] componentsJoinedByString:@", "];
	
	AFHTTPRequestOperation *request = [self post:kPiwigoImageSetInfo
								   URLParameters:nil
									  parameters:@{
												   @"image_id" : imageId,
												   @"author" : [imageInformation objectForKey:kPiwigoImagesUploadParamAuthor],
												   @"comment" : [imageInformation objectForKey:kPiwigoImagesUploadParamDescription],
												   @"tag_ids" : tagIdList,
												   @"name" : [imageInformation objectForKey:kPiwigoImagesUploadParamName],
												   @"level" : [imageInformation objectForKey:kPiwigoImagesUploadParamPrivacy],
												   @"method" : @"pwg.images.setInfo",
												   @"single_value_mode" : @"replace"
												   }
										 success:completion
										 failure:fail];
	
	[request setDownloadProgressBlock:progress];
	
	return request;
}

+(AFHTTPRequestOperation*)updateImageInfo:(ImageUpload*)imageInfo
							   onProgress:(void (^)(NSUInteger bytesRead, long long totalBytesRead, long long totalBytesExpectedToRead))progress
							 OnCompletion:(void (^)(AFHTTPRequestOperation *operation, NSDictionary *response))completion
								onFailure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))fail
{
	NSMutableArray *tagIds = [NSMutableArray new];
	for(PiwigoTagData *tagData in imageInfo.tags)
	{
		[tagIds addObject:@(tagData.tagId)];
	}
	
	NSDictionary *imageProperties = @{
									  kPiwigoImagesUploadParamName : imageInfo.imageUploadName,
									  kPiwigoImagesUploadParamPrivacy : [NSString stringWithFormat:@"%@", @(imageInfo.privacyLevel)],
									  kPiwigoImagesUploadParamAuthor : imageInfo.author,
									  kPiwigoImagesUploadParamDescription : imageInfo.imageDescription,
									  kPiwigoImagesUploadParamTags : [tagIds copy]
									  };
	
	return [self setImageInfoForImageWithId:[NSString stringWithFormat:@"%@", @(imageInfo.imageId)]
									 withInformation:imageProperties
										  onProgress:progress
										OnCompletion:^(AFHTTPRequestOperation *operation, NSDictionary *response) {
											
											// update the cache
											[[[CategoriesData sharedInstance] getCategoryById:imageInfo.categoryToUploadTo] updateCacheWithImageUploadInfo:imageInfo];
											
											if(completion)
											{
												completion(operation, response);
											}
										}
								  onFailure:fail];
}

@end
