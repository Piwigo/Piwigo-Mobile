//
//  AlbumService.m
//  piwigo
//
//  Created by Spencer Baker on 1/24/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "AlbumService.h"
#import "CategoriesData.h"

NSString * const kCategoryDeletionModeNone = @"no_delete";
NSString * const kCategoryDeletionModeOrphaned = @"delete_orphans";
NSString * const kCategoryDeletionModeAll = @"force_delete";

//#ifndef DEBUG_ALBUM
//#define DEBUG_ALBUM
//#endif

@implementation AlbumService

+(NSURLSessionTask*)getInfosOnCompletion:(void (^)(NSURLSessionTask *task, NSArray *infos))completion
                               onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
    // Send request
    return [self post:kPiwigoGetInfos
        URLParameters:nil
           parameters:nil
       sessionManager:NetworkVarsObjc.sessionManager
             progress:nil
              success:^(NSURLSessionTask *task, id responseObject) {
                  
        // Returned JSON:
        //
        //  { result = {
        //      infos = ({name = version;
        //                value = "2.10.2";
        //                },
        //               {name = "nb_elements";         ==> Total number of photos
        //                value = 341;
        //                },
        //               {name = "nb_categories";       ==> Total number of albums
        //                value = 28;
        //                },
        //               {name = "nb_virtual";          ==> Total number of virtual albums
        //                value = 28;
        //                },
        //               {name = "nb_physical";         ==> Total number of non-virtual albums
        //                value = 0;
        //                },
        //               {name = "nb_image_category";   ==> Total number of images in albums
        //                value = 352;
        //                },
        //               {name = "nb_tags";             ==> Total number of tags, orphans included
        //                value = 4;
        //                },
        //               {name = "nb_image_tag";        ==> Total number of tagged images
        //                value = 25;
        //                },
        //               {name = "nb_users";            ==> Total number of users
        //                value = 6;
        //                },
        //               {name = "nb_groups";           ==> Total number of groups
        //                value = 0;
        //                },
        //               {name = "nb_comments";         ==> Total number of comments
        //                value = 0;
        //                },
        //               {name = "first_date";          ==> Date of first image upload
        //                value = "2017-08-31 22:44:11";
        //                }
        //          );
        //      };
        //      stat = ok;
        //  }
        
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
                      NSError *error = [NetworkHandler getPiwigoErrorFromResponse:responseObject
                                            path:kPiwigoGetInfos andURLparams:nil];
                      if(completion) {
                          [NetworkHandler showPiwigoError:error withCompletion:^{
                              completion(task, nil);
                          }];
                      } else {
                          [NetworkHandler showPiwigoError:error withCompletion:nil];
                      }
                  }
              } failure:^(NSURLSessionTask *task, NSError *error) {
#if defined(DEBUG_ALBUM)
                  NSLog(@"getInfos — Fail: %@", [error description]);
#endif
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
#if defined(DEBUG_ALBUM)
        NSLog(@"                => use cache");
#endif
        if(completion) {
            completion(nil, nil);
            return nil;
        } else {
            return nil;
        }
    }

    // Recursive option ?
    NSString *recursiveString = recursive ? @"true" : @"false";

    // Community extension active ?
    NSString *fakedString = NetworkVarsObjc.usesCommunityPluginV29 ? @"false" : @"true";
    
    // Album thumbnail size
    NSString *thumbnailSize = @"thumb";
    kPiwigoImageSize albumThumbnailSize = (kPiwigoImageSize)AlbumVars.defaultAlbumThumbnailSize;
    switch (albumThumbnailSize) {
        case kPiwigoImageSizeSquare:
            if (AlbumVars.hasSquareSizeImages) {
                thumbnailSize = @"square";
            }
            break;
        case kPiwigoImageSizeXXSmall:
            if (AlbumVars.hasXXSmallSizeImages) {
                thumbnailSize = @"2small";
            }
            break;
        case kPiwigoImageSizeXSmall:
            if (AlbumVars.hasXSmallSizeImages) {
                thumbnailSize = @"xsmall";
            }
            break;
        case kPiwigoImageSizeSmall:
            if (AlbumVars.hasSmallSizeImages) {
                thumbnailSize = @"small";
            }
            break;
        case kPiwigoImageSizeMedium:
            if (AlbumVars.hasMediumSizeImages) {
                thumbnailSize = @"medium";
            }
            break;
        case kPiwigoImageSizeLarge:
            if (AlbumVars.hasLargeSizeImages) {
                thumbnailSize = @"large";
            }
            break;
        case kPiwigoImageSizeXLarge:
            if (AlbumVars.hasXLargeSizeImages) {
                thumbnailSize = @"xlarge";
            }
            break;
        case kPiwigoImageSizeXXLarge:
            if (AlbumVars.hasXXLargeSizeImages) {
                thumbnailSize = @"xxlarge";
            }
            break;

        case kPiwigoImageSizeThumb:
        case kPiwigoImageSizeFullRes:
        default:
            thumbnailSize = @"thumb";
            break;
    }
    
    // Compile parameters
    NSDictionary *parameters = @{
                                 @"cat_id" : @(categoryId),
                                 @"recursive" : recursiveString,
                                 @"faked_by_community" : fakedString,
                                 @"thumbnail_size" : thumbnailSize
                                 };
    
    // Get albums list for category
    return [self post:kPiwigoCategoriesGetList
        URLParameters:nil
           parameters:parameters
       sessionManager:NetworkVarsObjc.sessionManager
             progress:nil
              success:^(NSURLSessionTask *task, id responseObject) {
                  
                  if([[responseObject objectForKey:@"stat"] isEqualToString:@"ok"])
                  {
                      // Extract albums data from JSON message
                      NSArray *albums = [AlbumService parseAlbumJSON:[[responseObject objectForKey:@"result"] objectForKey:@"categories"]];

#if defined(DEBUG_ALBUM)
                      NSLog(@"                => %ld albums returned", (long)[albums count]);
#endif
                      // Update Categories Data cache
                      if (categoryId == 0)
                      {
                          [[CategoriesData sharedInstance] replaceAllCategories:albums];
                      }
                      else {
                          [[CategoriesData sharedInstance] updateCategories:albums];
                      }
                      
                      // Update albums if Community extension installed (not needed for admins)
                      if (!NetworkVarsObjc.hasAdminRights &&
                          NetworkVarsObjc.usesCommunityPluginV29) {
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
                      NSError *error = [NetworkHandler getPiwigoErrorFromResponse:responseObject
                                            path:kPiwigoCategoriesGetList andURLparams:nil];
                      if(completion) {
                          [NetworkHandler showPiwigoError:error withCompletion:^{
                              completion(task, nil);
                          }];
                      } else {
                          [NetworkHandler showPiwigoError:error withCompletion:nil];
                      }
                  }
              } failure:^(NSURLSessionTask *task, NSError *error) {
#if defined(DEBUG_ALBUM)
                  NSLog(@"getAlbumListForCategory — Fail: %@", [error description]);
#endif
                  if(fail) {
                      fail(task, error);
                  }
              }];
}

+(NSArray*)parseAlbumJSON:(NSArray*)json
{
    // API pwg.categories.getList returns:
    //      id, id_uppercat, representative_picture_id, tn_url
    //      status, name, comment
    //      nb_categories, uppercats, nb_images, total_nb_images
    //      date_last, max_date_last
    //      comment, global_rank, permalink, url
    //

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
		
        if (![[category objectForKey:@"name"] isKindOfClass:[NSNull class]]) {
            albumData.name = [NetworkObjcUtilities utf8mb4ObjcStringFrom:[category objectForKey:@"name"]];
        } else {
            albumData.name = @"Error…";
        }
        if (![[category objectForKey:@"comment"] isKindOfClass:[NSNull class]]) {
            albumData.comment = [NetworkObjcUtilities utf8mb4ObjcStringFrom:[category objectForKey:@"comment"]];
        } else {
            albumData.comment = @"";
        }
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
			[dateFormatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:NetworkVarsObjc.language]];
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
       sessionManager:NetworkVarsObjc.sessionManager
             progress:nil
              success:^(NSURLSessionTask *task, id responseObject) {
                  
                  if([[responseObject objectForKey:@"stat"] isEqualToString:@"ok"])
                  {
                      NSArray *albums = [[responseObject objectForKey:@"result"] objectForKey:@"categories"];
                      if (completion) {
                          completion(task, albums);
                      }
                  }
                  else
                  {
                      // Display Piwigo error
                      NSError *error = [NetworkHandler getPiwigoErrorFromResponse:responseObject
                                            path:kCommunityCategoriesGetList andURLparams:nil];
                      if(completion) {
                          [NetworkHandler showPiwigoError:error withCompletion:^{
                              completion(task, nil);
                          }];
                      } else {
                          [NetworkHandler showPiwigoError:error withCompletion:nil];
                      }
                  }
              } failure:^(NSURLSessionTask *task, NSError *error) {
#if defined(DEBUG_ALBUM)
                  NSLog(@"getCommunityAlbumListForCategory — Fail: %@", [error description]);
#endif
                  if(fail) {
                      fail(task, error);
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
    NSDictionary *parameters = @{@"name" : categoryName,
                                 @"parent" : @(categoryId),
                                 @"comment" : categoryComment,
                                 @"status" : categoryStatus
    };
    
    return [self post:kPiwigoCategoriesAdd
        URLParameters:nil
           parameters:parameters
       sessionManager:NetworkVarsObjc.sessionManager
             progress:nil
              success:^(NSURLSessionTask *task, id responseObject) {
        
          if ([[responseObject objectForKey:@"stat"] isEqualToString:@"ok"]) {
              // Add new album to cache
              NSInteger newCatId = [[[responseObject objectForKey:@"result"] objectForKey:@"id"] integerValue];
              [[CategoriesData sharedInstance] addCategory:newCatId withParameters:parameters];

              // Add new category to list of recent albums
              NSDictionary *userInfo = @{@"categoryId" : [NSNumber numberWithLong:newCatId]};
              [[NSNotificationCenter defaultCenter] postNotificationName:[PwgNotificationsObjc addRecentAlbum] object:nil userInfo:userInfo];
              
              // Task completed successfully
              if(completion)
              {
                  completion(task, YES);
              }
          }
          else {
              // Display Piwigo error
              NSError *error = [NetworkHandler getPiwigoErrorFromResponse:responseObject
                                    path:kPiwigoCategoriesAdd andURLparams:nil];
              if(completion) {
                  [NetworkHandler showPiwigoError:error withCompletion:^{
                      completion(task, NO);
                  }];
              } else {
                  [NetworkHandler showPiwigoError:error withCompletion:nil];
              }
          }

    } failure:^(NSURLSessionTask *task, NSError *error) {
#if defined(DEBUG_ALBUM)
            NSLog(@"createCategoryWithName — Fail: %@", [error description]);
#endif
            if(fail) {
                fail(task, error);
            }
        }];
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
       sessionManager:NetworkVarsObjc.sessionManager
             progress:nil
			  success:^(NSURLSessionTask *task, id responseObject) {
				  if(completion)
				  {
					  completion(task, [[responseObject objectForKey:@"stat"] isEqualToString:@"ok"]);
				  }
              } failure:^(NSURLSessionTask *task, NSError *error) {
    #if defined(DEBUG_ALBUM)
                  NSLog(@"renameCategory — Fail: %@", [error description]);
    #endif
                  if(fail) {
                      fail(task, error);
                  }
              }];
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
						@"pwg_token" : NetworkVarsObjc.pwgToken
                        }
       sessionManager:NetworkVarsObjc.sessionManager
             progress:nil
			  success:^(NSURLSessionTask *task, id responseObject)
    {
        if([[responseObject objectForKey:@"stat"] isEqualToString:@"ok"]) {
            // Remove category from list of recent albums
            NSDictionary *userInfo = @{@"categoryId" : [NSNumber numberWithLong:categoryId]};
            [[NSNotificationCenter defaultCenter] postNotificationName:[PwgNotificationsObjc removeRecentAlbum] object:nil userInfo:userInfo];
              if(completion)
              {
                  completion(task, YES);
              }
        } else {
            if(fail) {
                NSError *error = [NetworkHandler getPiwigoErrorFromResponse:responseObject
                                     path:kPiwigoCategoriesDelete andURLparams:nil];
                fail(task, error);
            }
        }
    } failure:^(NSURLSessionTask *task, NSError *error) {
  #if defined(DEBUG_ALBUM)
                NSLog(@"deleteCategory — Fail: %@", [error description]);
  #endif
                if(fail) {
                    fail(task, error);
                }
            }];
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
						@"pwg_token" : NetworkVarsObjc.pwgToken,
						@"parent" : [NSString stringWithFormat:@"%@", @(categoryToMoveIntoId)]
                        }
       sessionManager:NetworkVarsObjc.sessionManager
             progress:nil
			  success:^(NSURLSessionTask *task, id responseObject) {
				  if(completion)
				  {
					  completion(task, [[responseObject objectForKey:@"stat"] isEqualToString:@"ok"]);
				  }
            } failure:^(NSURLSessionTask *task, NSError *error) {
  #if defined(DEBUG_ALBUM)
                NSLog(@"moveCategory — Fail: %@", [error description]);
  #endif
                if(fail) {
                    fail(task, error);
                }
            }];
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
       sessionManager:NetworkVarsObjc.sessionManager
             progress:nil
			  success:^(NSURLSessionTask *task, id responseObject) {
				  if(completion)
				  {
					  completion(task, [[responseObject objectForKey:@"stat"] isEqualToString:@"ok"]);
				  }
            } failure:^(NSURLSessionTask *task, NSError *error) {
  #if defined(DEBUG_ALBUM)
                NSLog(@"setCategoryRepresentativeForCategory — Fail: %@", [error description]);
  #endif
                if(fail) {
                    fail(task, error);
                }
            }];
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
       sessionManager:NetworkVarsObjc.sessionManager
             progress:nil
              success:^(NSURLSessionTask *task, id responseObject) {
                  if(completion)
                  {
                      completion(task, [[responseObject objectForKey:@"stat"] isEqualToString:@"ok"]);
                  }
            } failure:^(NSURLSessionTask *task, NSError *error) {
  #if defined(DEBUG_ALBUM)
                NSLog(@"refreshCategoryRepresentativeForCategory — Fail: %@", [error description]);
  #endif
                if(fail) {
                    fail(task, error);
                }
            }];
}


@end
