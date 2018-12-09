//
//  ImageService.m
//  piwigo
//
//  Created by Spencer Baker on 1/31/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "AppDelegate.h"
#import "ImageService.h"
#import "Model.h"
#import "PiwigoImageData.h"
#import "PiwigoAlbumData.h"
#import "CategoriesData.h"
#import "PiwigoTagData.h"
#import "SAMKeychain.h"
#import "ImagesCollection.h"

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
    // Calculate the number of thumbnails displayed per page
    NSInteger imagesPerPage = [ImagesCollection numberOfImagesPerPageForView:nil andNberOfImagesPerRowInPortrait:[Model sharedInstance].thumbnailsPerRowInPortrait];

    return [self post:kPiwigoCategoriesGetImages
		URLParameters:nil
           parameters:@{
                        @"cat_id"   : @(albumId),
                        @"per_page" : @(imagesPerPage),
                        @"page"     : @(page),
                        @"order"    : order     // Percent-encoded should not be used here!
                        }
             progress:nil
			  success:^(NSURLSessionTask *task, id responseObject) {
				  
				  if(completion) {
					  if([[responseObject objectForKey:@"stat"] isEqualToString:@"ok"]) {
						  NSArray *albumImages = [ImageService parseAlbumImagesJSON:[responseObject objectForKey:@"result"]];
						  completion(task, albumImages);
					  }
                      else
                      {
                          // Display Piwigo error
                          NSInteger errorCode = [[responseObject objectForKey:@"err"] intValue];
                          [NetworkHandler showPiwigoError:errorCode forPath:kPiwigoGetInfos andURLparams:nil];

                          completion(task, nil);
					  }
				  }
			  } failure:^(NSURLSessionTask *task, NSError *error) {
#if defined(DEBUG)
                  NSLog(@"=> getImagesForAlbumId: %@ — Failed!", @(albumId));
#endif
                  NSInteger statusCode = [[[error userInfo] valueForKey:AFNetworkingOperationFailingURLResponseErrorKey] statusCode];
                  if ((statusCode == 401) ||        // Unauthorized
                      (statusCode == 403) ||        // Forbidden
                      (statusCode == 404))          // Not Found
                  {
                      NSLog(@"…notify kPiwigoNetworkErrorEncounteredNotification!");
                      dispatch_async(dispatch_get_main_queue(), ^{
                          [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNetworkErrorEncounteredNotification object:nil userInfo:nil];
                      });
                  }
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
		URLParameters:nil
           parameters:@{
                        @"image_id" : @(imageId)
                        }
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
					  }
                      else
                      {
                          // Display Piwigo error
                          NSInteger errorCode = [[responseObject objectForKey:@"err"] intValue];
                          [NetworkHandler showPiwigoError:errorCode forPath:kPiwigoGetInfos andURLparams:nil];

                          completion(task, nil);
					  }
				  }
			  }
              failure:^(NSURLSessionTask *task, NSError *error) {
#if defined(DEBUG)
                  NSLog(@"=> getImageInfoById: %@ failed with error %ld:%@", @(imageId), (long)[error code], [error localizedDescription]);
#endif
                  // Check session (closed or IPv4/IPv6 switch)?
                  NSInteger statusCode = [[[error userInfo] valueForKey:AFNetworkingOperationFailingURLResponseErrorKey] statusCode];
                  if ((statusCode == 401) ||        // Unauthorized
                      (statusCode == 403) ||        // Forbidden
                      (statusCode == 404))          // Not Found
                  {
                      NSLog(@"…notify kPiwigoNetworkErrorEncounteredNotification!");
                      dispatch_async(dispatch_get_main_queue(), ^{
                          [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNetworkErrorEncounteredNotification object:nil userInfo:nil];
                      });
                  }
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
    imageData.fullResPath = [NetworkHandler encodedImageURL:[[imageJson objectForKey:@"element_url"] stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"]];
	
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
	NSString *dateAvailableString = [imageJson objectForKey:@"date_available"];
	[dateFormat setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    if (![dateAvailableString isKindOfClass:[NSNull class]]) {
        imageData.datePosted = [dateFormat dateFromString:dateAvailableString];
    } else {
        imageData.datePosted = [NSDate date];
    }
    NSString *dateCreatedString = [imageJson objectForKey:@"date_creation"];
    if (![dateCreatedString isKindOfClass:[NSNull class]]) {
        imageData.dateCreated = [dateFormat dateFromString:dateCreatedString];
    }
    else {
        // When creation is unknown, use posted date so that image sort becomes possible
        imageData.dateCreated = imageData.datePosted;
    }

    // When $conf['original_url_protection'] = 'images' or 'all'; is enabled
    // the URLs returned by the Piwigo server contain &amp; instead of & (Piwigo v2.9.2)
	NSDictionary *imageSizes = [imageJson objectForKey:@"derivatives"];
    
    // Square image
    imageData.SquarePath = [NetworkHandler encodedImageURL:[[[imageSizes objectForKey:@"square"] objectForKey:@"url"] stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"]];
    if (![[[imageSizes objectForKey:@"square"] objectForKey:@"width"] isKindOfClass:[NSNull class]]) {
        imageData.SquareWidth = [[[imageSizes objectForKey:@"square"] objectForKey:@"width"] integerValue];
    }
    else {
        // When the image dimensions are unknown, use 0
        imageData.SquareWidth = 0;
    }
    if (![[[imageSizes objectForKey:@"square"] objectForKey:@"height"] isKindOfClass:[NSNull class]]) {
        imageData.SquareHeight = [[[imageSizes objectForKey:@"square"] objectForKey:@"height"] integerValue];
    }
    else {
        // When the image dimensions are unknown, use 0
        imageData.SquareHeight = 0;
    }

    // Thumbnail image
    imageData.ThumbPath = [NetworkHandler encodedImageURL:[[[imageSizes objectForKey:@"thumb"] objectForKey:@"url"] stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"]];
    if (![[[imageSizes objectForKey:@"thumb"] objectForKey:@"width"] isKindOfClass:[NSNull class]]) {
        imageData.ThumbWidth = [[[imageSizes objectForKey:@"thumb"] objectForKey:@"width"] integerValue];
    }
    else {
        // When the image dimensions are unknown, use 0
        imageData.ThumbWidth = 0;
    }
    if (![[[imageSizes objectForKey:@"thumb"] objectForKey:@"height"] isKindOfClass:[NSNull class]]) {
        imageData.ThumbHeight = [[[imageSizes objectForKey:@"thumb"] objectForKey:@"height"] integerValue];
    }
    else {
        // When the image dimensions are unknown, use 0
        imageData.ThumbHeight = 0;
    }

    // Medium image
    imageData.MediumPath = [NetworkHandler encodedImageURL:[[[imageSizes objectForKey:@"medium"] objectForKey:@"url"] stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"]];
    if (![[[imageSizes objectForKey:@"medium"] objectForKey:@"width"] isKindOfClass:[NSNull class]]) {
        imageData.MediumWidth = [[[imageSizes objectForKey:@"medium"] objectForKey:@"width"] integerValue];
    }
    else {
        // When the image dimensions are unknown, use 0
        imageData.MediumWidth = 0;
    }
    if (![[[imageSizes objectForKey:@"medium"] objectForKey:@"height"] isKindOfClass:[NSNull class]]) {
        imageData.MediumHeight = [[[imageSizes objectForKey:@"medium"] objectForKey:@"height"] integerValue];
    }
    else {
        // When the image dimensions are unknown, use 0
        imageData.MediumHeight = 0;
    }

    // XX small image
    imageData.XXSmallPath = [NetworkHandler encodedImageURL:[[[imageSizes objectForKey:@"2small"] objectForKey:@"url"] stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"]];
    if (![[[imageSizes objectForKey:@"2small"] objectForKey:@"width"] isKindOfClass:[NSNull class]]) {
        imageData.XXSmallWidth = [[[imageSizes objectForKey:@"2small"] objectForKey:@"width"] integerValue];
    }
    else {
        // When the image dimensions are unknown, use 0
        imageData.XXSmallWidth = 0;
    }
    if (![[[imageSizes objectForKey:@"2small"] objectForKey:@"height"] isKindOfClass:[NSNull class]]) {
        imageData.XXSmallHeight = [[[imageSizes objectForKey:@"2small"] objectForKey:@"height"] integerValue];
    }
    else {
        // When the image dimensions are unknown, use 0
        imageData.XXSmallHeight = 0;
    }

    // X small image
    imageData.XSmallPath = [NetworkHandler encodedImageURL:[[[imageSizes objectForKey:@"xsmall"] objectForKey:@"url"] stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"]];
    if (![[[imageSizes objectForKey:@"xsmall"] objectForKey:@"width"] isKindOfClass:[NSNull class]]) {
        imageData.XSmallWidth = [[[imageSizes objectForKey:@"xsmall"] objectForKey:@"width"] integerValue];
    }
    else {
        // When the image dimensions are unknown, use 0
        imageData.XSmallWidth = 0;
    }
    if (![[[imageSizes objectForKey:@"xsmall"] objectForKey:@"height"] isKindOfClass:[NSNull class]]) {
        imageData.XSmallHeight = [[[imageSizes objectForKey:@"xsmall"] objectForKey:@"height"] integerValue];
    }
    else {
        // When the image dimensions are unknown, use 0
        imageData.XSmallHeight = 0;
    }

    // Small image
    imageData.SmallPath = [NetworkHandler encodedImageURL:[[[imageSizes objectForKey:@"small"] objectForKey:@"url"] stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"]];
    if (![[[imageSizes objectForKey:@"small"] objectForKey:@"width"] isKindOfClass:[NSNull class]]) {
        imageData.SmallWidth = [[[imageSizes objectForKey:@"small"] objectForKey:@"width"] integerValue];
    }
    else {
        // When the image dimensions are unknown, use 0
        imageData.SmallWidth = 0;
    }
    if (![[[imageSizes objectForKey:@"small"] objectForKey:@"height"] isKindOfClass:[NSNull class]]) {
        imageData.SmallHeight = [[[imageSizes objectForKey:@"small"] objectForKey:@"height"] integerValue];
    }
    else {
        // When the image dimensions are unknown, use 0
        imageData.SmallHeight = 0;
    }

    // Large image
    imageData.LargePath = [NetworkHandler encodedImageURL:[[[imageSizes objectForKey:@"large"] objectForKey:@"url"] stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"]];
    if (![[[imageSizes objectForKey:@"large"] objectForKey:@"width"] isKindOfClass:[NSNull class]]) {
        imageData.LargeWidth = [[[imageSizes objectForKey:@"large"] objectForKey:@"width"] integerValue];
    }
    else {
        // When the image dimensions are unknown, use 0
        imageData.LargeWidth = 0;
    }
    if (![[[imageSizes objectForKey:@"large"] objectForKey:@"height"] isKindOfClass:[NSNull class]]) {
        imageData.LargeHeight = [[[imageSizes objectForKey:@"large"] objectForKey:@"height"] integerValue];
    }
    else {
        // When the image dimensions are unknown, use 0
        imageData.LargeHeight = 0;
    }

    // X large image
    imageData.XLargePath = [NetworkHandler encodedImageURL:[[[imageSizes objectForKey:@"xlarge"] objectForKey:@"url"] stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"]];
    if (![[[imageSizes objectForKey:@"xlarge"] objectForKey:@"width"] isKindOfClass:[NSNull class]]) {
        imageData.XLargeWidth = [[[imageSizes objectForKey:@"xlarge"] objectForKey:@"width"] integerValue];
    }
    else {
        // When the image dimensions are unknown, use 0
        imageData.XLargeWidth = 0;
    }
    if (![[[imageSizes objectForKey:@"xlarge"] objectForKey:@"height"] isKindOfClass:[NSNull class]]) {
        imageData.XLargeHeight = [[[imageSizes objectForKey:@"xlarge"] objectForKey:@"height"] integerValue];
    }
    else {
        // When the image dimensions are unknown, use 0
        imageData.XLargeHeight = 0;
    }

    // XX large image
    imageData.XXLargePath = [NetworkHandler encodedImageURL:[[[imageSizes objectForKey:@"xxlarge"] objectForKey:@"url"] stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"]];
    if (![[[imageSizes objectForKey:@"xxlarge"] objectForKey:@"width"] isKindOfClass:[NSNull class]]) {
        imageData.XXLargeWidth = [[[imageSizes objectForKey:@"xxlarge"] objectForKey:@"width"] integerValue];
    }
    else {
        // When the image dimensions are unknown, use 0
        imageData.XXLargeWidth = 0;
    }
    if (![[[imageSizes objectForKey:@"xxlarge"] objectForKey:@"height"] isKindOfClass:[NSNull class]]) {
        imageData.XXLargeHeight = [[[imageSizes objectForKey:@"xxlarge"] objectForKey:@"height"] integerValue];
    }
    else {
        // When the image dimensions are unknown, use 0
        imageData.XXLargeHeight = 0;
    }

    // Full resolution dimensions
    if (![[imageSizes objectForKey:@"width"] isKindOfClass:[NSNull class]]) {
        imageData.fullResWidth = [[imageSizes objectForKey:@"width"] integerValue];
    }
    else {
        // When the image dimensions are unknown, use 0
        imageData.fullResWidth = 0;
    }
    if (![[imageSizes objectForKey:@"height"] isKindOfClass:[NSNull class]]) {
        imageData.fullResHeight = [[imageSizes objectForKey:@"height"] integerValue];
    }
    else {
        // When the image dimensions are unknown, use 0
        imageData.fullResHeight = 0;
    }

    NSDictionary *categories = [imageJson objectForKey:@"categories"];
	NSMutableArray *categoryIds = [NSMutableArray new];
	for(NSDictionary *category in categories)
	{
		[categoryIds addObject:[category objectForKey:@"id"]];
	}
	imageData.categoryIds = categoryIds;
	
    NSDictionary *tags = [imageJson objectForKey:@"tags"];
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
    return [self post:kPiwigoImageDelete
		URLParameters:nil
		   parameters:@{
                        @"image_id" : @([image.imageId integerValue]),
                        @"pwg_token" : [Model sharedInstance].pwgToken
                        }
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
        URLRequest = image.fullResPath;
    } else if ([image.XXLargePath length] > 0) {
        URLRequest = image.XXLargePath;
    } else if ([image.XLargePath length] > 0) {
        URLRequest = image.XLargePath;
    } else if ([image.LargePath length] > 0) {
        URLRequest = image.LargePath;
    } else if ([image.MediumPath length] > 0) {
        URLRequest = image.MediumPath;
    } else if ([image.SmallPath length] > 0) {
        URLRequest = image.SmallPath;
    } else if ([image.XSmallPath length] > 0) {
        URLRequest = image.XSmallPath;
    } else if ([image.XXSmallPath length] > 0) {
        URLRequest = image.XXSmallPath;
    } else if ([image.ThumbPath length] > 0) {
        URLRequest = image.ThumbPath;
    }
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:URLRequest]];

    // Download and save image
    NSString *fileName = [[NSURL URLWithString:URLRequest] lastPathComponent];
    if ([fileName containsString:@".php"]) {
        // The URL does not contain a unique file name but a PHP request
        // Might happen with full resolution images
        fileName = [[NSURL URLWithString:image.MediumPath] lastPathComponent];
        if ([fileName containsString:@".php"]) {
            // The URL does not contain a unique file name but a PHP request
            if ([image.fileName length] > 0) {
                // Use the image file name returned by Piwigo
                fileName = image.fileName;
            } else {
                // Should never reach this point
                fileName = @"fileName.jpg";
            }
        }
    }

    NSURLSessionDownloadTask *task =
        [[Model sharedInstance].imagesSessionManager downloadTaskWithRequest:request
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

+(NSURLSessionTask*)setCategoriesForImage:(PiwigoImageData *)image
                           withCategories:(NSArray *)categoryIds
                               onProgress:(void (^)(NSProgress *))progress
                             OnCompletion:(void (^)(NSURLSessionTask *task, BOOL setCategoriesSuccessfully))completion
                                onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
    NSString *newImageCategories = [categoryIds componentsJoinedByString:@";"];
    NSURLSessionTask *request = [self post:kPiwigoImageSetInfo
                             URLParameters:nil
                                parameters:@{
                                             @"image_id" : image.imageId,
                                             @"categories" : newImageCategories,
                                             @"multiple_value_mode" : @"replace"
                                             }
                                  progress:progress
                                   success:^(NSURLSessionTask *task, id responseObject) {
                                       
                                       if(completion)
                                       {
                                           completion(task, [[responseObject objectForKey:@"stat"] isEqualToString:@"ok"]);
                                       }
                                   }
                                   failure:fail];
    
    return request;
}

+(NSURLSessionTask*)downloadVideo:(PiwigoImageData*)video
                       onProgress:(void (^)(NSProgress *))progress
                completionHandler:(void (^)(NSURLResponse *response, NSURL *filePath, NSError *error))completionHandler
{
	if(!video) return nil;
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:video.fullResPath]];
    
    // Replace .mp4 or .m4v with .mov for compatibility with Photos.app
    NSString *fileName = video.fileName;
    if (([[[video.fileName pathExtension] uppercaseString] isEqualToString:@"MP4"]) ||
        ([[[video.fileName pathExtension] uppercaseString] isEqualToString:@"M4V"])) {
        fileName = [[video.fileName stringByDeletingPathExtension] stringByAppendingPathExtension:@"mov"];
    }
    
    // Download and save video
    NSURLSessionDownloadTask *task = [[Model sharedInstance].imagesSessionManager
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
