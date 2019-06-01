//
//  AlbumService.m
//  piwigo
//
//  Created by Spencer Baker on 1/24/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "AlbumService.h"
#import "AppDelegate.h"
#import "Model.h"
#import "CategoriesData.h"

NSString * const kCategoryDeletionModeNone = @"no_delete";
NSString * const kCategoryDeletionModeOrphaned = @"delete_orphans";
NSString * const kCategoryDeletionModeAll = @"force_delete";

@implementation AlbumService

+(NSURLSessionTask*)getInfosOnCompletion:(void (^)(NSURLSessionTask *task, NSArray *infos))completion
                               onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
    // Send request
    return [self post:kPiwigoGetInfos
        URLParameters:nil
           parameters:nil
             progress:nil
              success:^(NSURLSessionTask *task, id responseObject) {
                  
                  if([[responseObject objectForKey:@"stat"] isEqualToString:@"ok"])
                  {
                      // Extract infos from JSON message
                      NSArray *infos = [[responseObject objectForKey:@"result"] objectForKey:@"infos"];
                      
                      if(completion)
                      {
                          completion(task, infos);
                      }
                  }
                  else
                  {
                      // Display Piwigo error
                      NSInteger errorCode = NSNotFound;
                      if ([responseObject objectForKey:@"err"]) {
                          errorCode = [[responseObject objectForKey:@"err"] intValue];
                      }
                      NSString *errorMsg = @"";
                      if ([responseObject objectForKey:@"message"]) {
                          errorMsg = [responseObject objectForKey:@"message"];
                      }
                      [NetworkHandler showPiwigoError:errorCode withMessage:errorMsg forPath:kPiwigoGetInfos andURLparams:nil];

                      if(completion)
                      {
                          completion(task, nil);
                      }
                  }
              } failure:^(NSURLSessionTask *task, NSError *error) {
#if defined(DEBUG)
                  NSLog(@"getInfos — Fail: %@", [error description]);
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

+(NSURLSessionTask*)getAlbumListForCategory:(NSInteger)categoryId
                                 usingCache:(BOOL)cached
                            inRecursiveMode:(BOOL)recursive
                               OnCompletion:(void (^)(NSURLSessionTask *task, NSArray *albums))completion
                                  onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
    // Use cache with care!
    NSArray *parentCategories = [[CategoriesData sharedInstance] getCategoriesForParentCategory:categoryId];
    if (cached && (parentCategories != nil)) {
//        NSLog(@"                => use cache");
        if(completion) {
            completion(nil, nil);
            return nil;
        } else {
            return nil;
        }
    }

    // Recursive option ?
    NSString *recursiveString = ([Model sharedInstance].loadAllCategoryInfo || recursive) ? @"true" : @"false";

    // Community extension active ?
    NSString *fakedString = [Model sharedInstance].usesCommunityPluginV29 ? @"false" : @"true";
    
    // Compile parameters
    NSDictionary *parameters = @{
                                 @"cat_id" : @(categoryId),
                                 @"recursive" : recursiveString,
                                 @"faked_by_community" : fakedString
                                 };
    
    // Get albums list for category
//    NSLog(@"                => getAlbumListForCategory(%ld,%@)", (long)categoryId, recursiveString);
    return [self post:kPiwigoCategoriesGetList
        URLParameters:nil
           parameters:parameters
             progress:nil
              success:^(NSURLSessionTask *task, id responseObject) {
                  
                  if([[responseObject objectForKey:@"stat"] isEqualToString:@"ok"])
                  {
                      // Extract albums data from JSON message
                      NSArray *albums = [AlbumService parseAlbumJSON:[[responseObject objectForKey:@"result"] objectForKey:@"categories"]];

//                      NSLog(@"                => %ld albums returned", (long)[albums count]);
                      // Update Categories Data cache
                      if ([Model sharedInstance].loadAllCategoryInfo)
                      {
                          [[CategoriesData sharedInstance] replaceAllCategories:albums];
                      }
                      else {
                          [[CategoriesData sharedInstance] updateCategories:albums];
                      }
                      
                      // Update albums if Community extension installed (not for admins)
                      if (![Model sharedInstance].hasAdminRights &&
                           [Model sharedInstance].usesCommunityPluginV29) {
                          [AlbumService setUploadRightsForCategory:categoryId inRecursiveMode:recursiveString];
                      }

                      if(completion)
                      {
                          completion(task, albums);
                      }
                  }
                  else
                  {
                      // Display Piwigo error
                      NSInteger errorCode = NSNotFound;
                      if ([responseObject objectForKey:@"err"]) {
                          errorCode = [[responseObject objectForKey:@"err"] intValue];
                      }
                      NSString *errorMsg = @"";
                      if ([responseObject objectForKey:@"message"]) {
                          errorMsg = [responseObject objectForKey:@"message"];
                      }
                      [NetworkHandler showPiwigoError:errorCode withMessage:errorMsg forPath:kPiwigoCategoriesGetList andURLparams:nil];

                      if(completion)
                      {
                          completion(task, nil);
                      }
                  }
              } failure:^(NSURLSessionTask *task, NSError *error) {
#if defined(DEBUG)
                  NSLog(@"getAlbumListForCategory — Fail: %@", [error description]);
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

+(NSArray*)parseAlbumJSON:(NSArray*)json
{
    NSMutableArray *albums = [NSMutableArray new];
	for(NSDictionary *category in json)
	{
		PiwigoAlbumData *albumData = [PiwigoAlbumData new];
		albumData.albumId = [[category objectForKey:@"id"] integerValue];
		
        // When "id_uppercat" is null or not supplied: album at the root
        if(([category objectForKey:@"id_uppercat"] == [NSNull null]) ||
           ([category objectForKey:@"id_uppercat"] == nil))
		{
			albumData.parentAlbumId = 0;
		}
		else
		{
			albumData.parentAlbumId = [[category objectForKey:@"id_uppercat"] integerValue];
		}
		
		NSString *upperCats = [category objectForKey:@"uppercats"];
		albumData.upperCategories = [upperCats componentsSeparatedByString:@","];
		
		albumData.nearestUpperCategory = albumData.upperCategories.count > 2 ? [[albumData.upperCategories objectAtIndex:albumData.upperCategories.count - 2] integerValue] : [[albumData.upperCategories objectAtIndex:0] integerValue];
		
		albumData.name = [category objectForKey:@"name"];
		albumData.comment = [category objectForKey:@"comment"];
		albumData.globalRank = [[category objectForKey:@"global_rank"] floatValue];
		albumData.numberOfImages = [[category objectForKey:@"nb_images"] integerValue];
		albumData.totalNumberOfImages = [[category objectForKey:@"total_nb_images"] integerValue];
		albumData.numberOfSubCategories = [[category objectForKey:@"nb_categories"] integerValue];
		
        // When "representative_picture_id" is null or not supplied: no album image
        if (([category objectForKey:@"representative_picture_id"] != nil) &&
            ([category objectForKey:@"representative_picture_id"] != [NSNull null]))
		{
			albumData.albumThumbnailId = [[category objectForKey:@"representative_picture_id"] integerValue];
            albumData.albumThumbnailUrl = [NetworkHandler encodedImageURL:[category objectForKey:@"tn_url"]];
		}
		
        // When "date_last" is null or not supplied: no date
		if(([category objectForKey:@"date_last"] != nil) &&
           ([category objectForKey:@"date_last"] != [NSNull null]))
		{
			NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
			[dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
			[dateFormatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:[Model sharedInstance].language]];
			albumData.dateLast = [dateFormatter dateFromString:[category objectForKey:@"date_last"]];
		}
        
        // By default, Community users have no upload rights
        albumData.hasUploadRights = NO;
        
        [albums addObject:albumData];
	}
	
	return albums;
}

+(void)setUploadRightsForCategory:(NSInteger)categoryId inRecursiveMode:(NSString *)recursive
{
    [self getCommunityAlbumListForCategory:categoryId
                           inRecursiveMode:recursive
                              OnCompletion:^(NSURLSessionTask *task, id responseObject) {
                                  if (responseObject) {
                                      // Extract albums data from JSON message
                                      NSArray *albums = [AlbumService parseAlbumJSON:responseObject];
                                      
                                      // Loop over Community albums
                                      for(PiwigoAlbumData *category in albums)
                                      {
                                          [[CategoriesData sharedInstance] addCommunityCategoryWithUploadRights:category];
                                     }
                                   }
                              }
                                 onFailure:nil
     ];
}

+(NSURLSessionTask*)getCommunityAlbumListForCategory:(NSInteger)categoryId
                                     inRecursiveMode:(NSString *)recursive
                                        OnCompletion:(void (^)(NSURLSessionTask *task, NSArray *albums))completion
                                           onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
    // Compile parameters
    NSDictionary *parameters = @{
                                 @"cat_id" : @(categoryId),
                                 @"recursive"  : recursive
                                 };
    
    // Send request
    return [self post:kCommunityCategoriesGetList
        URLParameters:nil
           parameters:parameters
             progress:nil
              success:^(NSURLSessionTask *task, id responseObject) {
                  
                  if (completion) {
                      if([[responseObject objectForKey:@"stat"] isEqualToString:@"ok"]) {
                          NSArray *albums = [[responseObject objectForKey:@"result"] objectForKey:@"categories"];
                          completion(task, albums);
                      }
                      else
                      {
                          // Display Piwigo error
                          NSInteger errorCode = NSNotFound;
                          if ([responseObject objectForKey:@"err"]) {
                              errorCode = [[responseObject objectForKey:@"err"] intValue];
                          }
                          NSString *errorMsg = @"";
                          if ([responseObject objectForKey:@"message"]) {
                              errorMsg = [responseObject objectForKey:@"message"];
                          }
                          [NetworkHandler showPiwigoError:errorCode withMessage:errorMsg forPath:kCommunityCategoriesGetList andURLparams:nil];

                          completion(task, nil);
                      }
                  }
              } failure:^(NSURLSessionTask *task, NSError *error) {
#if defined(DEBUG)
                  NSLog(@"getCommunityAlbumListForCategory — Fail: %@", [error description]);
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
              }];
}

+(NSURLSessionTask*)createCategoryWithName:(NSString*)categoryName
                                withStatus:(NSString*)categoryStatus
                                andComment:(NSString*)categoryComment
                                  inParent:(NSInteger)categoryId
                              OnCompletion:(void (^)(NSURLSessionTask *task, BOOL createdSuccessfully))completion
                                 onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
    return [self post:kPiwigoCategoriesAdd
        URLParameters:nil
           parameters:@{
                        @"name" : categoryName,
                        @"parent" : @(categoryId),
                        @"comment" : categoryComment,
                        @"status" : categoryStatus
                        }
             progress:nil
              success:^(NSURLSessionTask *task, id responseObject) {
                  if(completion)
                  {
                      completion(task, [[responseObject objectForKey:@"stat"] isEqualToString:@"ok"]);
                  }
              } failure:^(NSURLSessionTask *task, NSError *error) {
                  if (fail)
                  {
                      fail(task, error);
                  }
              }
            ];
}

+(NSURLSessionTask*)renameCategory:(NSInteger)categoryId
                           forName:(NSString *)categoryName
                       withComment:(NSString *)categoryComment
                      OnCompletion:(void (^)(NSURLSessionTask *task, BOOL renamedSuccessfully))completion
                         onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
	return [self post:kPiwigoCategoriesSetInfo
		URLParameters:nil       // This method requires HTTP POST
		   parameters:@{
						@"category_id" : @(categoryId),
						@"name" : categoryName,
                        @"comment" : categoryComment
                        }
             progress:nil
			  success:^(NSURLSessionTask *task, id responseObject) {
				  if(completion)
				  {
					  completion(task, [[responseObject objectForKey:@"stat"] isEqualToString:@"ok"]);
				  }
              } failure:^(NSURLSessionTask *task, NSError *error) {
                  if (fail)
                  {
                      fail(task, error);
                  }
              }
            ];
}

+(NSURLSessionTask*)deleteCategory:(NSInteger)categoryId
                            inMode:(NSString *)deletionMode
                      OnCompletion:(void (^)(NSURLSessionTask *task, BOOL deletedSuccessfully))completion
                         onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
	return [self post:kPiwigoCategoriesDelete
		URLParameters:nil
		   parameters:@{
						@"category_id" : [NSString stringWithFormat:@"%@", @(categoryId)],
                        @"photo_deletion_mode" : deletionMode,
						@"pwg_token" : [Model sharedInstance].pwgToken
                        }
             progress:nil
			  success:^(NSURLSessionTask *task, id responseObject) {
				  if(completion)
				  {
					  completion(task, [[responseObject objectForKey:@"stat"] isEqualToString:@"ok"]);
				  }
              } failure:^(NSURLSessionTask *task, NSError *error) {
                  if (fail)
                  {
                      fail(task, error);
                  }
              }
            ];
}

+(NSURLSessionTask*)moveCategory:(NSInteger)categoryId
                    intoCategory:(NSInteger)categoryToMoveIntoId
                    OnCompletion:(void (^)(NSURLSessionTask *task, BOOL movedSuccessfully))completion
                       onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
	return [self post:kPiwigoCategoriesMove
		URLParameters:nil
		   parameters:@{
						@"category_id" : [NSString stringWithFormat:@"%@", @(categoryId)],
						@"pwg_token" : [Model sharedInstance].pwgToken,
						@"parent" : [NSString stringWithFormat:@"%@", @(categoryToMoveIntoId)]
                        }
             progress:nil
			  success:^(NSURLSessionTask *task, id responseObject) {
				  if(completion)
				  {
					  completion(task, [[responseObject objectForKey:@"stat"] isEqualToString:@"ok"]);
				  }
              } failure:^(NSURLSessionTask *task, NSError *error) {
                  if (fail)
                  {
                      fail(task, error);
                  }
              }
            ];
}

+(NSURLSessionTask*)setCategoryRepresentativeForCategory:(NSInteger)categoryId
                                              forImageId:(NSInteger)imageId
                                            OnCompletion:(void (^)(NSURLSessionTask *task, BOOL setSuccessfully))completion
                                               onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
	return [self post:kPiwigoCategoriesSetRepresentative
		URLParameters:nil
		   parameters:@{
						@"category_id" : [NSString stringWithFormat:@"%@", @(categoryId)],
						@"image_id" : [NSString stringWithFormat:@"%@", @(imageId)]
                        }
             progress:nil
			  success:^(NSURLSessionTask *task, id responseObject) {
				  if(completion)
				  {
					  completion(task, [[responseObject objectForKey:@"stat"] isEqualToString:@"ok"]);
				  }
              } failure:^(NSURLSessionTask *task, NSError *error) {
                  if (fail)
                  {
                      fail(task, error);
                  }
              }
            ];
}

+(NSURLSessionTask*)refreshCategoryRepresentativeForCategory:(NSInteger)categoryId
                                                OnCompletion:(void (^)(NSURLSessionTask *task, BOOL refreshedSuccessfully))completion
                                                   onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
    return [self post:kPiwigoCategoriesRefreshRepresentative
        URLParameters:nil
           parameters:@{
                        @"category_id" : [NSString stringWithFormat:@"%@", @(categoryId)]
                        }
             progress:nil
              success:^(NSURLSessionTask *task, id responseObject) {
                  if(completion)
                  {
                      completion(task, [[responseObject objectForKey:@"stat"] isEqualToString:@"ok"]);
                  }
              } failure:^(NSURLSessionTask *task, NSError *error) {
                  if (fail)
                  {
                      fail(task, error);
                  }
              }
            ];
}


@end
