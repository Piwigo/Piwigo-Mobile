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
#import "SAMKeychain.h"

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
    // Create shared session manager if needed
    if ([Model sharedInstance].sessionManager == nil) {
        [NetworkHandler createSharedSessionManager];
    }
    
    // Set response serializer
    [NetworkHandler setJSONandTextResponseSerializer];
    
	return [self post:kPiwigoCategoriesGetImages
		URLParameters:nil
           parameters:@{@"cat_id"   : @(albumId),
                        @"per_page" : @([Model sharedInstance].imagesPerPage),
                        @"page"     : @(page),
                        @"order"    : [order stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]
                        }
             progress:nil
			  success:^(NSURLSessionTask *task, id responseObject) {
				  
				  if(completion) {
					  if([[responseObject objectForKey:@"stat"] isEqualToString:@"ok"]) {
						  NSArray *albumImages = [ImageService parseAlbumImagesJSON:[responseObject objectForKey:@"result"]];
						  completion(task, albumImages);
					  } else {
#if defined(DEBUG)
                          NSLog(@"=> getImagesForAlbumId: %@ — Success but stat not Ok!", @(albumId));
#endif
						  completion(task, nil);
					  }
				  }
			  } failure:^(NSURLSessionTask *task, NSError *error) {
#if defined(DEBUG)
                  NSLog(@"=> getImagesForAlbumId: %@ — Failed!", @(albumId));
#endif
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
    // Create shared session manager if needed
    if ([Model sharedInstance].sessionManager == nil) {
        [NetworkHandler createSharedSessionManager];
    }
    
    // Set response serializer
    [NetworkHandler setJSONandTextResponseSerializer];
    
	return [self post:kPiwigoImagesGetInfo
		URLParameters:nil
           parameters:@{@"image_id" : @(imageId)}
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
#if defined(DEBUG)
                          NSLog(@"=> getImageInfoById: %@ — Success but stat not Ok!", @(imageId));
#endif
						  completion(task, nil);
					  }
				  }
			  }
              failure:^(NSURLSessionTask *task, NSError *error) {
#if defined(DEBUG)
                  NSLog(@"=> getImageInfoById: %@ — Failed!", @(imageId));
#endif
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
    if(!imageData.fileName || [imageData.fileName isKindOfClass:[NSNull class]])
    {
        imageData.fileName = @"";
    }
    NSString *fileExt = [[imageData.fileName pathExtension] uppercaseString];
    if([fileExt isEqualToString:@"MP4"] || [fileExt isEqualToString:@"M4V"] ||
       [fileExt isEqualToString:@"OGG"] || [fileExt isEqualToString:@"OGV"] ||
       [fileExt isEqualToString:@"MOV"] || [fileExt isEqualToString:@"AVI"] ||
       [fileExt isEqualToString:@"WEBM"] || [fileExt isEqualToString:@"WEBMV"] ||
       [fileExt isEqualToString:@"MP3"])
	{
		imageData.isVideo = YES;
	}

    imageData.name = [imageJson objectForKey:@"name"];
	if(!imageData.name || [imageData.name isKindOfClass:[NSNull class]])
	{
		imageData.name = @"";
	}
    // When $conf['original_url_protection'] = 'images' or 'all'; is enabled
    // the URLs returned by the Piwigo server contain &amp; instead of & (Piwigo v2.9.2)
    imageData.fullResPath = [[imageJson objectForKey:@"element_url"] stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"];
	
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
	
    NSDateFormatter *dateFormat = [NSDateFormatter new];
	NSString *dateString = [imageJson objectForKey:@"date_available"];
	[dateFormat setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
	imageData.datePosted = [dateFormat dateFromString:dateString];
    dateString = [imageJson objectForKey:@"date_creation"];
    if (![dateString isKindOfClass:[NSNull class]]) imageData.dateCreated = [dateFormat dateFromString:dateString];
    
    // When $conf['original_url_protection'] = 'images' or 'all'; is enabled
    // the URLs returned by the Piwigo server contain &amp; instead of & (Piwigo v2.9.2)
	NSDictionary *imageSizes = [imageJson objectForKey:@"derivatives"];
	imageData.SquarePath = [[[imageSizes objectForKey:@"square"] objectForKey:@"url"] stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"];
	imageData.ThumbPath = [[[imageSizes objectForKey:@"thumb"] objectForKey:@"url"] stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"];
	imageData.MediumPath = [[[imageSizes objectForKey:@"medium"] objectForKey:@"url"] stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"];
	imageData.XXSmallPath = [[imageSizes valueForKeyPath:@"2small.url"] stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"];
	imageData.XSmallPath = [[imageSizes valueForKeyPath:@"xsmall.url"] stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"];
	imageData.SmallPath = [[imageSizes valueForKeyPath:@"small.url"] stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"];
	imageData.LargePath = [[imageSizes valueForKeyPath:@"large.url"] stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"];
	imageData.XLargePath = [[imageSizes valueForKeyPath:@"xlarge.url"] stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"];
	imageData.XXLargePath = [[imageSizes valueForKeyPath:@"xxlarge.url"] stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"];
	
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

    // Create shared session manager if needed
    if ([Model sharedInstance].sessionManager == nil) {
        [NetworkHandler createSharedSessionManager];
    }
    
    // Set response serializer
    [NetworkHandler setJSONandTextResponseSerializer];
    
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

+(NSURLSessionDownloadTask*)downloadImage:(PiwigoImageData*)image
                       onProgress:(void (^)(NSProgress *))progress
                completionHandler:(void (^)(NSURLResponse *response, NSURL *filePath, NSError *error))completionHandler
{
	if(!image) return nil;
    
    // Download image with highest resolution possible (fullResPath image is not always available)
    NSString *URLRequest = @"";
    if ([image.fullResPath length] > 0) {
        URLRequest = [NetworkHandler getURLWithPath:image.fullResPath asPiwigoRequest:NO withURLParams:nil];
    } else if ([image.XXLargePath length] > 0) {
        URLRequest = [NetworkHandler getURLWithPath:image.XXLargePath asPiwigoRequest:NO withURLParams:nil];
    } else if ([image.XLargePath length] > 0) {
        URLRequest = [NetworkHandler getURLWithPath:image.XLargePath asPiwigoRequest:NO withURLParams:nil];
    } else if ([image.LargePath length] > 0) {
        URLRequest = [NetworkHandler getURLWithPath:image.LargePath asPiwigoRequest:NO withURLParams:nil];
    } else if ([image.MediumPath length] > 0) {
        URLRequest = [NetworkHandler getURLWithPath:image.MediumPath asPiwigoRequest:NO withURLParams:nil];
    } else if ([image.SmallPath length] > 0) {
        URLRequest = [NetworkHandler getURLWithPath:image.SmallPath asPiwigoRequest:NO withURLParams:nil];
    } else if ([image.XSmallPath length] > 0) {
        URLRequest = [NetworkHandler getURLWithPath:image.XSmallPath asPiwigoRequest:NO withURLParams:nil];
    } else if ([image.XXSmallPath length] > 0) {
        URLRequest = [NetworkHandler getURLWithPath:image.XXSmallPath asPiwigoRequest:NO withURLParams:nil];
    } else if ([image.ThumbPath length] > 0) {
        URLRequest = [NetworkHandler getURLWithPath:image.ThumbPath asPiwigoRequest:NO withURLParams:nil];
    }
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString: URLRequest]];

    // Create shared session manager if needed
    if ([Model sharedInstance].sessionManager == nil) {
        [NetworkHandler createSharedSessionManager];
    }
    
    // Set response serializer
    [NetworkHandler setJSONandTextResponseSerializer];

    // Download and save image
    NSString *fileName = image.fileName;
    NSURLSessionDownloadTask *task =
        [[Model sharedInstance].sessionManager downloadTaskWithRequest:request
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

+(NSURLSessionTask*)downloadVideo:(PiwigoImageData*)video
                       onProgress:(void (^)(NSProgress *))progress
                completionHandler:(void (^)(NSURLResponse *response, NSURL *filePath, NSError *error))completionHandler
{
	if(!video) return nil;

    NSString *URLRequest = [NetworkHandler getURLWithPath:video.fullResPath asPiwigoRequest:NO withURLParams:nil];
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:URLRequest]];
    
    // Replace .mp4 or .m4v with .mov for compatibility with Photos.app
    NSString *fileName = video.fileName;
    if (([[[video.fileName pathExtension] uppercaseString] isEqualToString:@"MP4"]) ||
        ([[[video.fileName pathExtension] uppercaseString] isEqualToString:@"M4V"])) {
        fileName = [[video.fileName stringByDeletingPathExtension] stringByAppendingPathExtension:@"mov"];
    }
    
    // Create shared session manager if needed
    if ([Model sharedInstance].sessionManager == nil) {
        [NetworkHandler createSharedSessionManager];
    }
    
    // Set response serializer
    [NetworkHandler setJSONandTextResponseSerializer];
    
    // Download and save video
    NSURLSessionDownloadTask *task = [[Model sharedInstance].sessionManager
                    downloadTaskWithRequest:request
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
