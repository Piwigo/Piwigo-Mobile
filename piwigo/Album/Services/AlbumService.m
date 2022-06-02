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

+(NSURLSessionTask*)getAlbumDataOnCompletion:(void (^)(NSURLSessionTask *task, BOOL didChange))completion
                                   onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
    // Community extension active ?
    NSString *fakedString = NetworkVarsObjc.usesCommunityPluginV29 ? @"false" : @"true";
    
    // Album thumbnail size
    NSString *thumbnailSize = @"thumb";
    kPiwigoImageSize albumThumbnailSize = (kPiwigoImageSize)AlbumVars.shared.defaultAlbumThumbnailSize;
    switch (albumThumbnailSize) {
        case kPiwigoImageSizeSquare:
            if (AlbumVars.shared.hasSquareSizeImages) {
                thumbnailSize = @"square";
            }
            break;
        case kPiwigoImageSizeXXSmall:
            if (AlbumVars.shared.hasXXSmallSizeImages) {
                thumbnailSize = @"2small";
            }
            break;
        case kPiwigoImageSizeXSmall:
            if (AlbumVars.shared.hasXSmallSizeImages) {
                thumbnailSize = @"xsmall";
            }
            break;
        case kPiwigoImageSizeSmall:
            if (AlbumVars.shared.hasSmallSizeImages) {
                thumbnailSize = @"small";
            }
            break;
        case kPiwigoImageSizeMedium:
            if (AlbumVars.shared.hasMediumSizeImages) {
                thumbnailSize = @"medium";
            }
            break;
        case kPiwigoImageSizeLarge:
            if (AlbumVars.shared.hasLargeSizeImages) {
                thumbnailSize = @"large";
            }
            break;
        case kPiwigoImageSizeXLarge:
            if (AlbumVars.shared.hasXLargeSizeImages) {
                thumbnailSize = @"xlarge";
            }
            break;
        case kPiwigoImageSizeXXLarge:
            if (AlbumVars.shared.hasXXLargeSizeImages) {
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
                                 @"cat_id" : @"0",
                                 @"recursive" : @"true",
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
                      NSArray<PiwigoAlbumData *> *albums = [AlbumService parseAlbumJSON:[[responseObject objectForKey:@"result"] objectForKey:@"categories"]];

#if defined(DEBUG_ALBUM)
                      NSLog(@"                => %ld albums returned", (long)[albums count]);
#endif
                      // Update Categories Data cache
                      BOOL didChange = [[CategoriesData sharedInstance] replaceAllCategories:albums];
                      
                      // Check whether the auto-upload category still exists
                      NSInteger autoUploadCatId = UploadVarsObjc.autoUploadCategoryId;
                      NSInteger indexOfAutoUpload = [albums indexOfObjectPassingTest:^BOOL(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                          PiwigoAlbumData *category = (PiwigoAlbumData *)obj;
                          if(category.albumId == autoUploadCatId) {
                              return YES;
                          } else {
                              return NO;
                          }
                      }];
                      if (indexOfAutoUpload == NSNotFound) {
                          [UploadUtilitiesObjc disableAutoUpload];
                      }
                      
                      // Check whether the default album still exists
                      NSInteger defaultCatId = AlbumVars.shared.defaultCategory;
                      if (defaultCatId != 0) {
                          NSInteger indexOfDefault = [albums indexOfObjectPassingTest:^BOOL(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                              PiwigoAlbumData *category = (PiwigoAlbumData *)obj;
                              if (category.albumId == defaultCatId) {
                                  return YES;
                              } else {
                                  return NO;
                              }
                          }];
                          if (indexOfDefault == NSNotFound) {
                              AlbumVars.shared.defaultCategory = 0;    // Back to root album
                          }
                      }
                      
                      // Update albums if Community extension installed (not needed for admins)
                      if (!NetworkVarsObjc.hasAdminRights &&
                          NetworkVarsObjc.usesCommunityPluginV29)
                      {
                          [self getCommunityAlbumListForCategory:0
                                                 inRecursiveMode:@"true"
                                                    OnCompletion:^(NSURLSessionTask *task, id responseObject) {
                                if (responseObject) {
                                    // Extract albums data from JSON message
                                    NSArray *albums = [AlbumService parseAlbumJSON:responseObject];

                                    // Loop over Community albums
                                    for(PiwigoAlbumData *category in albums) {
                                        [[CategoriesData sharedInstance] addCommunityCategoryWithUploadRights:category];
                                    }
                                    
                                    // Job done
                                    if(completion) {
                                        completion(task, didChange);
                                    }
                                } else {
                                    // Continue without Community albums
                                    if(completion) {
                                        completion(task, didChange);
                                    }
                                }
                            } onFailure:nil // i.e. continue without Community albums
                          ];
                      } else {
                          // Job done
                          if(completion) {
                              completion(task, didChange);
                          }
                      }
                  }
                  else
                  {
                      // Display Piwigo error
                      NSError *error = [NetworkHandler getPiwigoErrorFromResponse:responseObject
                                            path:kPiwigoCategoriesGetList andURLparams:nil];
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
                  NSLog(@"getAlbumData — Fail: %@", [error description]);
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
        if (([category objectForKey:@"global_rank"] != nil) &&
            ([category objectForKey:@"global_rank"] != [NSNull null])) {
            albumData.globalRank = [[category objectForKey:@"global_rank"] floatValue];
        } else {
            albumData.globalRank = 0.0;
        }
        if (([category objectForKey:@"nb_images"] != nil) &&
            ([category objectForKey:@"nb_images"] != [NSNull null])) {
            albumData.numberOfImages = [[category objectForKey:@"nb_images"] integerValue];
        } else {
            albumData.numberOfImages = 0;
        }
        if (([category objectForKey:@"total_nb_images"] != nil) &&
            ([category objectForKey:@"total_nb_images"] != [NSNull null])) {
            albumData.totalNumberOfImages = [[category objectForKey:@"total_nb_images"] integerValue];
        } else {
            albumData.totalNumberOfImages = 0;
        }
        if (([category objectForKey:@"nb_categories"] != nil) &&
            ([category objectForKey:@"nb_categories"] != [NSNull null])) {
            albumData.numberOfSubCategories = [[category objectForKey:@"nb_categories"] integerValue];
        } else {
            albumData.numberOfSubCategories = 0;
        }

        // When "representative_picture_id" is null or not supplied: no album image
        if (([category objectForKey:@"representative_picture_id"] != nil) &&
            ([category objectForKey:@"representative_picture_id"] != [NSNull null]))
		{
			albumData.albumThumbnailId = [[category objectForKey:@"representative_picture_id"] integerValue];
		}
        if (([category objectForKey:@"tn_url"] != nil) &&
            ([category objectForKey:@"tn_url"] != [NSNull null]))
        {
            albumData.albumThumbnailUrl = [NetworkHandler encodedImageURL:[category objectForKey:@"tn_url"]];
        } else {
            albumData.albumThumbnailUrl = @"";
        }

        // When "date_last" is null or not supplied: no date
        /// - 'date_last' is the maximum 'date_available' of the images associated to an album.
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
                              OnCompletion:(void (^)(NSURLSessionTask *task, NSInteger newCatId))completion
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
              [[NSNotificationCenter defaultCenter] postNotificationName:PwgNotificationsObjc.pwgAddRecentAlbum
                                                                  object:nil userInfo:userInfo];
              
              // Task completed successfully
              if(completion)
              {
                  completion(task, newCatId);
              }
          }
          else {
              // Display Piwigo error
              NSError *error = [NetworkHandler getPiwigoErrorFromResponse:responseObject
                                    path:kPiwigoCategoriesAdd andURLparams:nil];
              if(completion) {
                  [NetworkHandler showPiwigoError:error withCompletion:^{
                      completion(task, NSNotFound);
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

@end
