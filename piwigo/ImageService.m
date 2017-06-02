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

+(NSURLSessionTask*)getImagesForAlbumId:(NSInteger)albumId
                                 onPage:(NSInteger)page
                               forOrder:(NSString*)order
                           OnCompletion:(void (^)(NSURLSessionTask *task, NSArray *albumImages))completion
                              onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
	return [self post:kPiwigoCategoriesGetImages
		URLParameters:@{@"albumId" : @(albumId),
						@"perPage" : @([Model sharedInstance].imagesPerPage),
						@"page"    : @(page),
						@"order"   : [order stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]}
           parameters:nil
             progress:nil
			  success:^(NSURLSessionTask *task, id responseObject) {
				  
				  if(completion) {
					  if([[responseObject objectForKey:@"stat"] isEqualToString:@"ok"]) {
						  NSArray *albumImages = [ImageService parseAlbumImagesJSON:[responseObject objectForKey:@"result"]];
						  completion(task, albumImages);
					  } else {
						  completion(task, nil);
					  }
				  }
			  } failure:^(NSURLSessionTask *task, NSError *error) {
				  
				  if(fail) {
					  fail(task, error);
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

+(NSURLSessionTask*)getImageInfoById:(NSInteger)imageId
                    ListOnCompletion:(void (^)(NSURLSessionTask *task, PiwigoImageData *imageData))completion
                           onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
	return [self post:kPiwigoImagesGetInfo
		URLParameters:@{@"imageId" : @(imageId)}
           parameters:nil
             progress:nil
			  success:^(NSURLSessionTask *task, id responseObject) {
				  
				  if(completion) {
					  if([[responseObject objectForKey:@"stat"] isEqualToString:@"ok"])
					  {
						  PiwigoImageData *imageData = [ImageService parseBasicImageInfoJSON:[responseObject objectForKey:@"result"]];
						  for(NSNumber *categoryId in imageData.categoryIds)
						  {
							  [[[CategoriesData sharedInstance] getCategoryById:[categoryId integerValue]] addImages:@[imageData]];
						  }
						  completion(task, imageData);
					  } else {
						  completion(task, nil);
					  }
				  }
			  }
              failure:^(NSURLSessionTask *task, NSError *error) {
				  if(fail) {
					  fail(task, error);
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

+(NSURLSessionTask*)deleteImage:(PiwigoImageData*)image
               ListOnCompletion:(void (^)(NSURLSessionTask *task))completion
                      onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
	if(!image) return nil;
	return [self post:kPiwigoImageDelete
		URLParameters:nil
		   parameters:@{@"image_id" : @([image.imageId integerValue]),
                        @"pwg_token" : [Model sharedInstance].pwgToken}
             progress:nil
			  success:^(NSURLSessionTask *task, id responseObject) {
				  if(completion) {
					  if([[responseObject objectForKey:@"stat"] isEqualToString:@"ok"]) {
						  [[CategoriesData sharedInstance] removeImage:image];
						  completion(task);
					  } else {
						  fail(task, responseObject);
					  }
				  }
			  } failure:^(NSURLSessionTask *task, NSError *error) {
				  if(fail) {
					  fail(task, error);
				  }
			  }];
}

+(NSURLSessionTask*)downloadImage:(PiwigoImageData*)image
                       onProgress:(void (^)(NSProgress *))progress
                 ListOnCompletion:(void (^)(NSURLSessionTask *task, UIImage *image))completion
                        onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
	if(!image) return nil;
    NSURL *request = [NSURL URLWithString:[image.fullResPath stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];

    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    manager.responseSerializer = [AFImageResponseSerializer serializer];
    
    NSURLSessionDataTask *task = [manager GET:request.absoluteString parameters:nil
                                     progress:progress
                                      success:^(NSURLSessionTask *task, UIImage *image) {
                                          if(completion) {
                                              completion(task, image);
                                          }
                                          [manager invalidateSessionCancelingTasks:YES];
                                      }
                                      failure:^(NSURLSessionTask *task, NSError *error) {
#if defined(DEBUG)
                                          NSLog(@"ImageService/get Error: %@", error);
#endif
                                          if(fail) {
                                              fail(task, error);
                                          }
                                          [manager invalidateSessionCancelingTasks:YES];
                                      }
     ];

	return task;
}

+(NSURLSessionTask*)downloadVideo:(PiwigoImageData*)video
                       onProgress:(void (^)(NSProgress *))progress
                completionHandler:(void (^)(NSURLResponse *response, NSURL *filePath, NSError *error))completionHandler
{
	if(!video) return nil;

    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    AFURLSessionManager *manager = [[AFURLSessionManager alloc] initWithSessionConfiguration:configuration];
    
    NSURL *URL = [NSURL URLWithString:[video.fullResPath stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    NSURLRequest *request = [NSURLRequest requestWithURL:URL];
    
    // replace .mp4 or .mv4 with .mov for compatibility with Photos.app
    NSString *fileName = video.fileName;
    if (([[video.fileName pathExtension] isEqualToString:@"MP4"]) ||
        ([[video.fileName pathExtension] isEqualToString:@"mp4"]) ||
        ([[video.fileName pathExtension] isEqualToString:@"M4V"]) ||
        ([[video.fileName pathExtension] isEqualToString:@"m4v"])) {
        fileName = [[video.fileName stringByDeletingPathExtension] stringByAppendingPathExtension:@"mov"];
    }
    
    NSURLSessionDownloadTask *task = [manager downloadTaskWithRequest:request
                                                             progress:progress
                                                          destination:^NSURL *(NSURL *targetPath, NSURLResponse *response) {
                                                              NSURL *documentsDirectoryURL = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:nil];
                                                              return [documentsDirectoryURL URLByAppendingPathComponent:fileName];
                                                          }
                                                    completionHandler:completionHandler
                                      ];
    [task resume];

    return task;
}

+(NSURLSessionTask*)loadImageChunkForLastChunkCount:(NSInteger)lastImageBulkCount
                                        forCategory:(NSInteger)categoryId
                                             onPage:(NSInteger)onPage
                                            forSort:(NSString*)sort
                                   ListOnCompletion:(void (^)(NSURLSessionTask *task, NSInteger count))completion
                                          onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
	if([[CategoriesData sharedInstance] getCategoryById:categoryId].imageList.count == [[CategoriesData sharedInstance] getCategoryById:categoryId].numberOfImages)
	{	// done. don't need anymore
		if(fail)
		{
			fail(nil, nil);
		}
		return nil;
	}
	
    NSURLSessionTask *task = [ImageService getImagesForAlbumId:categoryId
                                                        onPage:onPage
                                                      forOrder:sort
                                                  OnCompletion:^(NSURLSessionTask *task, NSArray *albumImages) {
															   
                                                       if(albumImages)
                                                       {
                                                           PiwigoAlbumData *albumData = [[CategoriesData sharedInstance] getCategoryById:categoryId];
                                                           [albumData addImages:albumImages];
                                                       }
                                                       
                                                       if(completion) {
                                                           completion(task, albumImages.count);
                                                       }
                                                   } onFailure:^(NSURLSessionTask *task, NSError *error) {
#if defined(DEBUG)
                                                       NSLog(@"loadImageChunkForLastChunkCount fail: %@", error);
#endif
                                                       if(fail) {
                                                           fail(nil, error);
                                                       }
                                                   }
                              ];
	
    task.priority = NSOperationQueuePriorityVeryHigh;
	return task;
}

@end
