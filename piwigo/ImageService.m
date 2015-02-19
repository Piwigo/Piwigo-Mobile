//
//  ImageService.m
//  piwigo
//
//  Created by Spencer Baker on 1/31/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "ImageService.h"
#import "Model.h"
#import "PiwigoImageData.h"
#import "PiwigoAlbumData.h"
#import "CategoriesData.h"

NSString * const kGetImageOrderFileName = @"file";
NSString * const kGetImageOrderId = @"id";
NSString * const kGetImageOrderName = @"name";
NSString * const kGetImageOrderRating = @"rating_score";
NSString * const kGetImageOrderDateCreated = @"date_creation";
NSString * const kGetImageOrderDateAdded = @"date_available";
NSString * const kGetImageOrderRandom = @"random";

@implementation ImageService

+(AFHTTPRequestOperation*)getImagesForAlbumId:(NSInteger)albumId
											onPage:(NSInteger)page
										  forOrder:(NSString*)order
									  OnCompletion:(void (^)(AFHTTPRequestOperation *operation, NSArray *albumImages))completion
										 onFailure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))fail
{
	return [self post:kPiwigoCategoriesGetImages
		URLParameters:@{@"albumId" : @(albumId),
						@"perPage" : @([Model sharedInstance].imagesPerPage),
						@"page" : @(page),
						@"order" : order}
		   parameters:nil
			  success:^(AFHTTPRequestOperation *operation, id responseObject) {
				  
				  if(completion) {
					  if([[responseObject objectForKey:@"stat"] isEqualToString:@"ok"]) {
						  NSArray *albumImages = [ImageService parseAlbumImagesJSON:[responseObject objectForKey:@"result"]];
						  completion(operation, albumImages);
					  } else {
						  completion(operation, nil);
					  }
				  }
			  } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
				  
				  if(fail) {
					  fail(operation, error);
				  }
			  }];
}

+(NSArray*)parseAlbumImagesJSON:(NSDictionary*)json
{
	NSDictionary *paging = [json objectForKey:@"paging"];
	[Model sharedInstance].lastPageImageCount = [[paging objectForKey:@"count"] integerValue];
	
	NSDictionary *imagesInfo = [json objectForKey:@"images"];
	
	NSMutableArray *albumImages = [NSMutableArray new];
	for(NSDictionary *image in imagesInfo)
	{
		PiwigoImageData *imgData = [ImageService parseBasicImageInfoJSON:image];
		[albumImages addObject:imgData];
	}
	return albumImages;
}

+(AFHTTPRequestOperation*)getImageInfoById:(NSInteger)imageId
						  ListOnCompletion:(void (^)(AFHTTPRequestOperation *operation, PiwigoImageData *imageData))completion
								 onFailure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))fail
{
	return [self post:kPiwigoImagesGetInfo
		URLParameters:@{@"imageId" : @(imageId)}
		   parameters:nil
			  success:^(AFHTTPRequestOperation *operation, id responseObject) {
				  
				  if(completion) {
					  if([[responseObject objectForKey:@"stat"] isEqualToString:@"ok"])
					  {
						  completion(operation, [ImageService parseBasicImageInfoJSON:[responseObject objectForKey:@"result"]]);
					  } else {
						  completion(operation, nil);
					  }
				  }
			  } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
				  
				  if(fail) {
					  fail(operation, error);
				  }
			  }];
}

+(PiwigoImageData*)parseBasicImageInfoJSON:(NSDictionary*)imageJson
{
	PiwigoImageData *imageData = [PiwigoImageData new];
	
	imageData.imageId = [imageJson objectForKey:@"id"];
	imageData.fileName = [imageJson objectForKey:@"file"];
	imageData.name = [imageJson objectForKey:@"name"];
	imageData.fullResPath = [imageJson objectForKey:@"element_url"];
	
	NSDictionary *imageSizes = [imageJson objectForKey:@"derivatives"];
	imageData.thumbPath = [[imageSizes objectForKey:@"thumb"] objectForKey:@"url"];
	imageData.squarePath = [[imageSizes objectForKey:@"square"] objectForKey:@"url"];
	imageData.mediumPath = [[imageSizes objectForKey:@"medium"] objectForKey:@"url"];
	
	NSArray *categories = [imageJson objectForKey:@"categories"];
	NSMutableArray *categoryIds = [NSMutableArray new];
	for(NSDictionary *category in categories)
	{
		[categoryIds addObject:[category objectForKey:@"id"]];
	}
	
	imageData.categoryIds = categoryIds;
	
	return imageData;
}

+(AFHTTPRequestOperation*)deleteImage:(PiwigoImageData*)image
						  ListOnCompletion:(void (^)(AFHTTPRequestOperation *operation))completion
								 onFailure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))fail
{
	if(!image) return nil;
	return [self post:kPiwigoImageDelete
		URLParameters:nil
		   parameters:@{@"image_id" : @([image.imageId integerValue]),
						@"pwg_token" : [Model sharedInstance].pwgToken}
			  success:^(AFHTTPRequestOperation *operation, id responseObject) {
				  
				  if(completion) {
					  if([[responseObject objectForKey:@"stat"] isEqualToString:@"ok"]) {
						  [[CategoriesData sharedInstance] removeImage:image];
						  completion(operation);
					  } else {
						  fail(operation, responseObject);
					  }
				  }
			  } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
				  
				  if(fail) {
					  fail(operation, error);
				  }
			  }];
}

+(AFHTTPRequestOperation*)downloadImage:(PiwigoImageData*)image
							 onProgress:(void (^)(NSInteger current, NSInteger total))progress
					 ListOnCompletion:(void (^)(AFHTTPRequestOperation *operation, UIImage *image))completion
							onFailure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))fail
{
	if(!image) return nil;
	NSURLRequest *requst = [NSURLRequest requestWithURL:[NSURL URLWithString:image.fullResPath]];
	AFHTTPRequestOperation *requestOperation = [[AFHTTPRequestOperation alloc] initWithRequest:requst];
	requestOperation.responseSerializer = [AFImageResponseSerializer serializer];
	[requestOperation setCompletionBlockWithSuccess:completion
											failure:fail];
	
	[requestOperation setDownloadProgressBlock:^(NSUInteger bytesRead, long long totalBytesRead, long long totalBytesExpectedToRead) {
		if(progress) {
			progress(totalBytesRead, totalBytesExpectedToRead);
		}
	}];
	
	[requestOperation start];
	return requestOperation;
}

+(AFHTTPRequestOperation*)loadImageChunkForLastChunkCount:(NSInteger)lastImageBulkCount
											  forCategory:(NSInteger)categoryId
												   onPage:(NSInteger)onPage
										 ListOnCompletion:(void (^)(AFHTTPRequestOperation *operation, NSInteger count))completion
												onFailure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))fail
{
	if(lastImageBulkCount != [Model sharedInstance].imagesPerPage)
	{
		if(fail)
		{
			fail(nil, nil);
		}
		return nil;
	}
	
	AFHTTPRequestOperation *request = [ImageService getImagesForAlbumId:categoryId
																 onPage:onPage
															   forOrder:kGetImageOrderFileName
														   OnCompletion:^(AFHTTPRequestOperation *operation, NSArray *albumImages) {
															   
															   if(albumImages)
															   {
																   PiwigoAlbumData *albumData = [[CategoriesData sharedInstance] getCategoryById:categoryId];
																   [albumData addImages:albumImages];
															   }
															   
															   if(completion) {
																   completion(operation, albumImages.count);
															   }
														   } onFailure:^(AFHTTPRequestOperation *operation, NSError *error) {
															   NSLog(@"Fail get album photos: %@", error);
															   if(fail) {
																   fail(fail, error);
															   }
														   }];
	
	[request setQueuePriority:NSOperationQueuePriorityVeryHigh];
	return request;
}


@end
