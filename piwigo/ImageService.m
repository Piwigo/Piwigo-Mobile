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
#import "PiwigoTagData.h"

NSString * const kGetImageOrderFileName = @"file";
NSString * const kGetImageOrderId = @"id";
NSString * const kGetImageOrderName = @"name";
NSString * const kGetImageOrderRating = @"rating_score";
NSString * const kGetImageOrderDateCreated = @"date_creation";
NSString * const kGetImageOrderDatePosted = @"date_available";
NSString * const kGetImageOrderRandom = @"random";
NSString * const kGetImageOrderAscending = @"asc";
NSString * const kGetImageOrderDescending = @"desc";

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
						@"order" : [order stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]}
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
	
	NSArray *imagesInfo = [json objectForKey:@"images"];
	if(![imagesInfo isKindOfClass:[NSArray class]])
	{
		return nil;
	}
	
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
						  PiwigoImageData *imageData = [ImageService parseBasicImageInfoJSON:[responseObject objectForKey:@"result"]];
						  for(NSNumber *categoryId in imageData.categoryIds)
						  {
							  [[[CategoriesData sharedInstance] getCategoryById:[categoryId integerValue]] addImages:@[imageData]];
						  }
						  completion(operation, imageData);
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
	if([imageData.fileName rangeOfString:@".mp4"].location != NSNotFound ||
	   [imageData.fileName rangeOfString:@".MP4"].location != NSNotFound ||
	   [imageData.fileName rangeOfString:@".MOV"].location != NSNotFound ||
	   [imageData.fileName rangeOfString:@".mov"].location != NSNotFound ||
	   [imageData.fileName rangeOfString:@".AVI"].location != NSNotFound ||
	   [imageData.fileName rangeOfString:@".avi"].location != NSNotFound ||
	   [imageData.fileName rangeOfString:@".MP3"].location != NSNotFound ||
	   [imageData.fileName rangeOfString:@".mp3"].location != NSNotFound)
	{
		imageData.isVideo = YES;
	}
	imageData.name = [imageJson objectForKey:@"name"];
	if(!imageData.name || [imageData.name isKindOfClass:[NSNull class]])
	{
		imageData.name = @"";
	}
	imageData.fullResPath = [imageJson objectForKey:@"element_url"];
	
	imageData.privacyLevel = [[imageJson objectForKey:@"level"] integerValue];
	imageData.author = [imageJson objectForKey:@"author"];
	if(!imageData.author || [imageData.author isKindOfClass:[NSNull class]])
	{
		imageData.author = @"";
	}
	imageData.imageDescription = [imageJson objectForKey:@"comment"];
	if(!imageData.imageDescription || [imageData.imageDescription isKindOfClass:[NSNull class]])
	{
		imageData.imageDescription = @"";
	}
	
	NSString *dateString = [imageJson objectForKey:@"date_available"];
	NSDateFormatter *dateFormat = [NSDateFormatter new];
	[dateFormat setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
	imageData.datePosted = [dateFormat dateFromString:dateString];
    dateString = [imageJson objectForKey:@"date_creation"];
    if (![dateString isKindOfClass:[NSNull class]]) imageData.dateCreated = [dateFormat dateFromString:dateString];
    
	NSDictionary *imageSizes = [imageJson objectForKey:@"derivatives"];
	imageData.squarePath = [[imageSizes objectForKey:@"square"] objectForKey:@"url"];
	imageData.thumbPath = [[imageSizes objectForKey:@"thumb"] objectForKey:@"url"];
	imageData.mediumPath = [[imageSizes objectForKey:@"medium"] objectForKey:@"url"];
	imageData.xxSmall = [imageSizes valueForKeyPath:@"2small.url"];
	imageData.xSmall = [imageSizes valueForKeyPath:@"xsmall.url"];
	imageData.small = [imageSizes valueForKeyPath:@"small.url"];
	imageData.large = [imageSizes valueForKeyPath:@"large.url"];
	imageData.xLarge = [imageSizes valueForKeyPath:@"xlarge.url"];
	imageData.xxLarge = [imageSizes valueForKeyPath:@"xxlarge.url"];
	
	NSArray *categories = [imageJson objectForKey:@"categories"];
	NSMutableArray *categoryIds = [NSMutableArray new];
	for(NSDictionary *category in categories)
	{
		[categoryIds addObject:[category objectForKey:@"id"]];
	}
	
	imageData.categoryIds = categoryIds;
	
	NSArray *tags = [imageJson objectForKey:@"tags"];
	NSMutableArray *imageTags = [NSMutableArray new];
	for(NSDictionary *tag in tags)
	{
		PiwigoTagData *tagData = [PiwigoTagData new];
		tagData.tagId = [[tag objectForKey:@"id"] integerValue];
		tagData.tagName = [tag objectForKey:@"name"];
		[imageTags addObject:tagData];
	}
	imageData.tags = imageTags;
	
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
	NSURLRequest *requst = [NSURLRequest requestWithURL:[NSURL URLWithString:[image.fullResPath stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]];
	AFHTTPRequestOperation *requestOperation = [[AFHTTPRequestOperation alloc] initWithRequest:requst];
	requestOperation.responseSerializer = [AFImageResponseSerializer serializer];
	[requestOperation setCompletionBlockWithSuccess:completion
											failure:fail];
	
	[requestOperation setDownloadProgressBlock:^(NSUInteger bytesRead, long long totalBytesRead, long long totalBytesExpectedToRead) {
		if(progress) {
			progress((NSInteger)totalBytesRead, (NSInteger)totalBytesExpectedToRead);
		}
	}];
	
	[requestOperation start];
	return requestOperation;
}

+(AFHTTPRequestOperation*)downloadVideo:(PiwigoImageData*)video
							 onProgress:(void (^)(NSInteger current, NSInteger total))progress
					   ListOnCompletion:(void (^)(AFHTTPRequestOperation *operation, id response))completion
							  onFailure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))fail
{
	if(!video) return nil;
	NSURLRequest *requst = [NSURLRequest requestWithURL:[NSURL URLWithString:[video.fullResPath stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]];
	AFHTTPRequestOperation *requestOperation = [[AFHTTPRequestOperation alloc] initWithRequest:requst];
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString *path = [[paths objectAtIndex:0] stringByAppendingPathComponent:video.fileName];
	requestOperation.outputStream = [NSOutputStream outputStreamToFileAtPath:path append:NO];
	[requestOperation setCompletionBlockWithSuccess:completion
											failure:fail];
	
	[requestOperation setDownloadProgressBlock:^(NSUInteger bytesRead, long long totalBytesRead, long long totalBytesExpectedToRead) {
		if(progress) {
			progress((NSInteger)totalBytesRead, (NSInteger)totalBytesExpectedToRead);
		}
	}];
	
	[requestOperation start];
	return requestOperation;
}

+(AFHTTPRequestOperation*)loadImageChunkForLastChunkCount:(NSInteger)lastImageBulkCount
											  forCategory:(NSInteger)categoryId
												   onPage:(NSInteger)onPage
												  forSort:(NSString*)sort
										 ListOnCompletion:(void (^)(AFHTTPRequestOperation *operation, NSInteger count))completion
												onFailure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))fail
{
	if([[CategoriesData sharedInstance] getCategoryById:categoryId].imageList.count == [[CategoriesData sharedInstance] getCategoryById:categoryId].numberOfImages)
	{	// done. don't need anymore
		if(fail)
		{
			fail(nil, nil);
		}
		return nil;
	}
	
	AFHTTPRequestOperation *request = [ImageService getImagesForAlbumId:categoryId
																 onPage:onPage
															   forOrder:sort
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
																   fail(nil, error);
															   }
														   }];
	
	[request setQueuePriority:NSOperationQueuePriorityVeryHigh];
	return request;
}


@end
