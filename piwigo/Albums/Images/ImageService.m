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

//#ifndef DEBUG_SHARE
//#define DEBUG_SHARE
//#endif

@implementation ImageService

// API pwg.categories.getImages returns:
//
//      id, name, width, height, categories, comment, hit
//      file, date_creation, data_available
//      page_url, derivatives
//
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

// API pwg.images.getInfo returns:
//
//      (id, name, width, height, categories, comment, hit), comments, comments_paging, rotation, coi, author
//      (file, date_creation, data_available), date_metadata_update, lastmodified, filesize, md5sum,
//      (page_url, derivatives), representative_ext
//      added_by, rating_score, level, rates, tags, latitude, longitude,
//
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
    if (![[imageJson objectForKey:@"width"] isKindOfClass:[NSNull class]]) {
        imageData.fullResWidth = [[imageJson objectForKey:@"width"] integerValue];
    }
    if (![[imageJson objectForKey:@"height"] isKindOfClass:[NSNull class]]) {
        imageData.fullResHeight = [[imageJson objectForKey:@"height"] integerValue];
    }
    
    // Categories
    NSDictionary *categories = [imageJson objectForKey:@"categories"];
	NSMutableArray *categoryIds = [NSMutableArray new];
	for(NSDictionary *category in categories)
	{
		[categoryIds addObject:[category objectForKey:@"id"]];
	}
	imageData.categoryIds = categoryIds;
    categoryIds = nil;
	
    // Tags
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
    imageTags = nil;
	
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
                            ofMinimumSize:(NSInteger)minSize
                       onProgress:(void (^)(NSProgress *))progress
                completionHandler:(void (^)(NSURLResponse *response, NSURL *filePath, NSError *error))completionHandler
{
	if(!image) return nil;
    
    // Download image of optimum size (depends on availability)
    NSString *URLRequest = @"";
    if (([image.ThumbPath length] > 0) &&
        (fmin(image.ThumbWidth, image.ThumbHeight) < minSize)) {
            URLRequest = image.ThumbPath;
    }
    if (([image.XXSmallPath length] > 0) &&
        (fmin(image.XXSmallWidth, image.XXSmallHeight) < minSize)) {
        URLRequest = image.XXSmallPath;
    }
    if (([image.XSmallPath length] > 0) &&
        (fmin(image.XSmallWidth, image.XSmallHeight) < minSize)) {
        URLRequest = image.XSmallPath;
    }
    if (([image.SmallPath length] > 0) &&
        (fmin(image.SmallWidth, image.SmallHeight) < minSize)) {
        URLRequest = image.SmallPath;
    }
    if (([image.MediumPath length] > 0) &&
        (fmin(image.MediumWidth, image.MediumHeight) < minSize)) {
        URLRequest = image.MediumPath;
    }
    if (([image.LargePath length] > 0) &&
        (fmin(image.LargeWidth, image.LargeHeight) < minSize)) {
        URLRequest = image.LargePath;
    }
    if (([image.XLargePath length] > 0) &&
        (fmin(image.XLargeWidth, image.XLargeHeight) > minSize)) {
        URLRequest = image.XLargePath;
    }
    if (([image.XXLargePath length] > 0) &&
        (fmin(image.XXLargeWidth, image.XXLargeHeight) < minSize)) {
        URLRequest = image.XXLargePath;
    }
    if (([image.fullResPath length] > 0) &&
        (fmin(image.fullResWidth, image.fullResHeight) < minSize)) {
        URLRequest = image.fullResPath;
    }
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:URLRequest]];

    // Set appropriate filename
    NSString *fileName = [[NSURL URLWithString:URLRequest] lastPathComponent];
    if ([fileName containsString:@".php"]) {
        // The URL does not contain a unique file name but a PHP request
        // Might happen with full resolution images, try with medium resolution file
        fileName = [[NSURL URLWithString:image.MediumPath] lastPathComponent];
        if ([fileName containsString:@".php"]) {
            // The URL does not contain a unique file name but a PHP request
            if ([image.fileName length] > 0) {
                // Use the image file name returned by Piwigo
                fileName = image.fileName;
            } else {
                // Should never reach this point
                fileName = @"PiwigoImage.jpg";
            }
        }
    }

    // Download and save image
    NSURLSessionDownloadTask *task =
        [[Model sharedInstance].imagesSessionManager downloadTaskWithRequest:request
                                progress:progress
                             destination:^NSURL *(NSURL *targetPath, NSURLResponse *response) {
                                 NSURL *documentsDirectoryURL = [[NSFileManager defaultManager] URLForDirectory:NSCachesDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:nil];
                                 NSLog(@"=> downloaded %@", [documentsDirectoryURL URLByAppendingPathComponent:fileName]);
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
//    if (([[[video.fileName pathExtension] uppercaseString] isEqualToString:@"MP4"]) ||
//        ([[[video.fileName pathExtension] uppercaseString] isEqualToString:@"M4V"])) {
//        fileName = [[video.fileName stringByDeletingPathExtension] stringByAppendingPathExtension:@"mov"];
//    }
    
    // Download and save video
    NSURLSessionDownloadTask *task = [[Model sharedInstance].imagesSessionManager
                    downloadTaskWithRequest:request
                                   progress:progress
                                destination:^NSURL *(NSURL *targetPath, NSURLResponse *response) {
                                     NSURL *documentsDirectoryURL = [[NSFileManager defaultManager] URLForDirectory:NSCachesDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:nil];
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

+(NSMutableDictionary *)stripGPSdataFromImageMetadata:(NSMutableDictionary *)metadata
{
#if defined(DEBUG_SHARE)
    NSLog(@"Strip GPS data [Start]: %@",metadata);
#endif

    // GPS dictionary
    NSMutableDictionary *GPSDictionary = [[metadata objectForKey:(NSString *)kCGImagePropertyGPSDictionary] mutableCopy];
    if (GPSDictionary) {
#if defined(DEBUG_SHARE)
        NSLog(@"=> GPS metadata = %@",GPSDictionary);
#endif
        [metadata removeObjectForKey:(NSString *)kCGImagePropertyGPSDictionary];
    }
    
    // EXIF dictionary
    NSMutableDictionary *EXIFDictionary = [[metadata objectForKey:(NSString *)kCGImagePropertyExifDictionary] mutableCopy];
    if (EXIFDictionary) {
#if defined(DEBUG_SHARE)
        NSLog(@"modifyImage: EXIF User Comment metadata = %@",[EXIFDictionary valueForKey:(NSString *)kCGImagePropertyExifUserComment]);
        NSLog(@"modifyImage: EXIF Subject Location metadata = %@",[EXIFDictionary valueForKey:(NSString *)kCGImagePropertyExifSubjectLocation]);
#endif
        [EXIFDictionary removeObjectForKey:(NSString *)kCGImagePropertyExifUserComment];
        [EXIFDictionary removeObjectForKey:(NSString *)kCGImagePropertyExifSubjectLocation];
        [metadata setObject:EXIFDictionary forKey:(NSString *)kCGImagePropertyExifDictionary];
    }

#if defined(DEBUG_SHARE)
    NSLog(@"Strip GPS data [End]: %@",metadata);
#endif
    return metadata;
}

+(NSMutableDictionary *)fixMetadata:(NSMutableDictionary *)metadata ofImage:(UIImage*)image
{
#if defined(DEBUG_SHARE)
    NSLog(@"fixMetadata [Start]: %@",metadata);
#endif

    // Extract metadata from UIImage object
    NSData *objectNSData = UIImageJPEGRepresentation(image, 1.0f);
    CGImageSourceRef objectSource = CGImageSourceCreateWithData((__bridge CFDataRef) objectNSData, NULL);
    NSMutableDictionary *objectMetadata = [(NSMutableDictionary*) CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(objectSource, 0, NULL)) mutableCopy];
#if defined(DEBUG_SHARE)
    NSLog(@"modifyImage finds metadata from object:%@",objectMetadata);
#endif
    
    // Update metadata header with correct metadata
    if ([metadata valueForKey:(NSString *)kCGImagePropertyOrientation]) {
        [metadata setValue:[objectMetadata valueForKey:(NSString *)kCGImagePropertyOrientation]
                         forKey:(NSString *)kCGImagePropertyOrientation];
    }
    
    // Update metadata with correct size
    if ([metadata valueForKey:(NSString *)kCGImagePropertyPixelWidth]) {
        [metadata setValue:[objectMetadata valueForKey:(NSString *)kCGImagePropertyPixelWidth]
                         forKey:(NSString *)kCGImagePropertyPixelWidth];
        [metadata setValue:[objectMetadata valueForKey:(NSString *)kCGImagePropertyPixelHeight]
                         forKey:(NSString *)kCGImagePropertyPixelHeight];
    }
    
    // Update 8BIM dictionary with correct metadata
    NSMutableDictionary *image8BIMDictionary = [[metadata objectForKey:(NSString *)kCGImageProperty8BIMDictionary] mutableCopy];
    NSMutableDictionary *object8BIMDictionary = [[objectMetadata objectForKey:(NSString *)kCGImageProperty8BIMDictionary] mutableCopy];
    if (image8BIMDictionary && object8BIMDictionary) {
        [image8BIMDictionary addEntriesFromDictionary:object8BIMDictionary];
        [metadata setObject:image8BIMDictionary forKey:(NSString *)kCGImageProperty8BIMDictionary];
    } else if (!image8BIMDictionary && object8BIMDictionary) {
        [metadata setObject:object8BIMDictionary forKey:(NSString *)kCGImageProperty8BIMDictionary];
    }
    
    // Update CIFF dictionary with correct metadata
    NSMutableDictionary *imageCIFFDictionary = [[metadata objectForKey:(NSString *)kCGImagePropertyCIFFDictionary] mutableCopy];
    NSMutableDictionary *objectCIFFDictionary = [[objectMetadata objectForKey:(NSString *)kCGImagePropertyCIFFDictionary] mutableCopy];
    if (imageCIFFDictionary && objectCIFFDictionary) {
        [imageCIFFDictionary addEntriesFromDictionary:objectCIFFDictionary];
        [metadata setObject:imageCIFFDictionary forKey:(NSString *)kCGImagePropertyCIFFDictionary];
    } else if (!imageCIFFDictionary && objectCIFFDictionary) {
        [metadata setObject:objectCIFFDictionary forKey:(NSString *)kCGImagePropertyCIFFDictionary];
    }
    
    // Update DNG dictionary with correct metadata
    NSMutableDictionary *imageDNGDictionary = [[metadata objectForKey:(NSString *)kCGImagePropertyDNGDictionary] mutableCopy];
    NSMutableDictionary *objectDNGDictionary = [[objectMetadata objectForKey:(NSString *)kCGImagePropertyDNGDictionary] mutableCopy];
    if (imageDNGDictionary && objectDNGDictionary) {
        [imageDNGDictionary addEntriesFromDictionary:objectDNGDictionary];
        [metadata setObject:objectDNGDictionary forKey:(NSString *)kCGImagePropertyDNGDictionary];
    } else if (!imageDNGDictionary && objectDNGDictionary) {
        [metadata setObject:objectDNGDictionary forKey:(NSString *)kCGImagePropertyDNGDictionary];
    }
    
    // Update Exif dictionary with correct metadata
    NSMutableDictionary *imageEXIFDictionary = [[metadata objectForKey:(NSString *)kCGImagePropertyExifDictionary] mutableCopy];
    NSMutableDictionary *objectEXIFDictionary = [[objectMetadata objectForKey:(NSString *)kCGImagePropertyExifDictionary] mutableCopy];
    if (imageEXIFDictionary && objectEXIFDictionary) {
        [imageEXIFDictionary addEntriesFromDictionary:objectEXIFDictionary];
        [metadata setObject:imageEXIFDictionary forKey:(NSString *)kCGImagePropertyExifDictionary];
    } else if (!imageEXIFDictionary && objectEXIFDictionary) {
        [metadata setObject:objectEXIFDictionary forKey:(NSString *)kCGImagePropertyExifDictionary];
    }
    NSMutableDictionary *imageEXIFAuxDictionary = [[metadata objectForKey:(NSString *)kCGImagePropertyExifAuxDictionary] mutableCopy];
    NSMutableDictionary *objectEXIFAuxDictionary = [[objectMetadata objectForKey:(NSString *)kCGImagePropertyExifAuxDictionary] mutableCopy];
    if (imageEXIFAuxDictionary && objectEXIFAuxDictionary) {
        [imageEXIFAuxDictionary addEntriesFromDictionary:objectEXIFAuxDictionary];
        [metadata setObject:imageEXIFAuxDictionary forKey:(NSString *)kCGImagePropertyExifAuxDictionary];
    } else if (!imageEXIFAuxDictionary && objectEXIFAuxDictionary) {
        [metadata setObject:objectEXIFAuxDictionary forKey:(NSString *)kCGImagePropertyExifAuxDictionary];
    }
    
    // Update GIF dictionary with correct metadata
    NSMutableDictionary *imageGIFDictionary = [[metadata objectForKey:(NSString *)kCGImagePropertyGIFDictionary] mutableCopy];
    NSMutableDictionary *objectGIFDictionary = [[objectMetadata objectForKey:(NSString *)kCGImagePropertyGIFDictionary] mutableCopy];
    if (imageGIFDictionary && objectGIFDictionary) {
        [imageGIFDictionary addEntriesFromDictionary:objectGIFDictionary];
        [metadata setObject:imageGIFDictionary forKey:(NSString *)kCGImagePropertyGIFDictionary];
    } else if (!imageGIFDictionary && objectGIFDictionary) {
        [metadata setObject:objectGIFDictionary forKey:(NSString *)kCGImagePropertyGIFDictionary];
    }
    
    // Update IPTC dictionary with correct metadata
    NSMutableDictionary *imageIPTCDictionary = [[metadata objectForKey:(NSString *)kCGImagePropertyIPTCDictionary] mutableCopy];
    NSMutableDictionary *objectIPTCDictionary = [[objectMetadata objectForKey:(NSString *)kCGImagePropertyIPTCDictionary] mutableCopy];
    if (imageIPTCDictionary && objectIPTCDictionary) {
        [imageIPTCDictionary addEntriesFromDictionary:objectIPTCDictionary];
        [metadata setObject:imageIPTCDictionary forKey:(NSString *)kCGImagePropertyIPTCDictionary];
    } else if (!imageIPTCDictionary && objectIPTCDictionary) {
        [metadata setObject:objectIPTCDictionary forKey:(NSString *)kCGImagePropertyIPTCDictionary];
    }
    
    // Update JFIF dictionary with correct metadata
    NSMutableDictionary *imageJFIFDictionary = [[metadata objectForKey:(NSString *)kCGImagePropertyJFIFDictionary] mutableCopy];
    NSMutableDictionary *objectJFIFDictionary = [[objectMetadata objectForKey:(NSString *)kCGImagePropertyJFIFDictionary] mutableCopy];
    if (imageJFIFDictionary && objectJFIFDictionary) {
        [imageJFIFDictionary addEntriesFromDictionary:objectJFIFDictionary];
        [metadata setObject:imageJFIFDictionary forKey:(NSString *)kCGImagePropertyJFIFDictionary];
    } else if (!imageJFIFDictionary && objectJFIFDictionary) {
        [metadata setObject:objectJFIFDictionary forKey:(NSString *)kCGImagePropertyJFIFDictionary];
    }
    
    // Update PNG dictionary with correct metadata
    NSMutableDictionary *imagePNGDictionary = [[metadata objectForKey:(NSString *)kCGImagePropertyPNGDictionary] mutableCopy];
    NSMutableDictionary *objectPNGDictionary = [[objectMetadata objectForKey:(NSString *)kCGImagePropertyPNGDictionary] mutableCopy];
    if (imagePNGDictionary && objectPNGDictionary) {
        [imagePNGDictionary addEntriesFromDictionary:objectPNGDictionary];
        [metadata setObject:imagePNGDictionary forKey:(NSString *)kCGImagePropertyPNGDictionary];
    } else if (!imagePNGDictionary && objectPNGDictionary) {
        [metadata setObject:objectPNGDictionary forKey:(NSString *)kCGImagePropertyPNGDictionary];
    }
    
    // Update RAW dictionary with correct metadata
    NSMutableDictionary *imageRawDictionary = [[metadata objectForKey:(NSString *)kCGImagePropertyRawDictionary] mutableCopy];
    NSMutableDictionary *objectRawDictionary = [[objectMetadata objectForKey:(NSString *)kCGImagePropertyRawDictionary] mutableCopy];
    if (imageRawDictionary && objectRawDictionary) {
        [imageRawDictionary addEntriesFromDictionary:objectRawDictionary];
        [metadata setObject:imageRawDictionary forKey:(NSString *)kCGImagePropertyRawDictionary];
    } else if (!imageRawDictionary && objectRawDictionary) {
        [metadata setObject:objectRawDictionary forKey:(NSString *)kCGImagePropertyRawDictionary];
    }
    
    // Update TIFF dictionary with correct metadata
    NSMutableDictionary *imageTIFFDictionary = [[metadata objectForKey:(NSString *)kCGImagePropertyTIFFDictionary] mutableCopy];
    NSMutableDictionary *objectTIFFDictionary = [[objectMetadata objectForKey:(NSString *)kCGImagePropertyTIFFDictionary] mutableCopy];
    if (imageTIFFDictionary && objectTIFFDictionary) {
        [imageTIFFDictionary addEntriesFromDictionary:objectTIFFDictionary];
        [metadata setObject:imageTIFFDictionary forKey:(NSString *)kCGImagePropertyTIFFDictionary];
    } else if (!imageTIFFDictionary && objectTIFFDictionary) {
        [metadata setObject:objectTIFFDictionary forKey:(NSString *)kCGImagePropertyTIFFDictionary];
    }

    // Release memory
    CFRelease(objectSource);
    objectNSData = nil;

#if defined(DEBUG_SHARE)
    NSLog(@"fixMetadata [End]: %@",metadata);
#endif
    return metadata;
}

+(NSData*)writeMetadata:(NSDictionary*)metadata intoImageData:(NSData *)imageData
{
    // NOP if metadata == nil
    if (!metadata) return imageData;
    
    // Create an imagesourceref
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef) imageData, NULL);
    if (!source) {
#if defined(DEBUG_SHARE)
        NSLog(@"Error: Could not create source");
#endif
    } else {
        // Type of image (e.g., public.jpeg)
        CFStringRef UTI = CGImageSourceGetType(source);
        
        // Create a new data object and write the new image into it
        NSMutableData *dest_data = [NSMutableData data];
        CGImageDestinationRef destination = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)dest_data, UTI, 1, NULL);
        if (!destination) {
#if defined(DEBUG_SHARE)
            NSLog(@"Error: Could not create image destination");
#endif
            CFRelease(source);
        } else {
            // add the image contained in the image source to the destination, overidding the old metadata with our modified metadata
            CGImageDestinationAddImageFromSource(destination, source, 0, (__bridge CFDictionaryRef) metadata);
            BOOL success = NO;
            success = CGImageDestinationFinalize(destination);
            if (!success) {
#if defined(DEBUG_SHARE)
                NSLog(@"Error: Could not create data from image destination");
#endif
                CFRelease(destination);
                CFRelease(source);
            } else {
                CFRelease(destination);
                CFRelease(source);
//                return [dest_data copy];
                return dest_data;
            }
        }
    }
    return imageData;
}

@end
