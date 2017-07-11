//
//  AlbumService.m
//  piwigo
//
//  Created by Spencer Baker on 1/24/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "AlbumService.h"
#import "PiwigoAlbumData.h"
#import "Model.h"
#import "CategoriesData.h"

@implementation AlbumService

+(NSURLSessionTask*)getAlbumListForCategory:(NSInteger)categoryId
                               OnCompletion:(void (^)(NSURLSessionTask *task, NSArray *albums))completion
                                  onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
    if(categoryId != -1 && [Model sharedInstance].loadAllCategoryInfo && categoryId != 0) return  nil;
    
    // Recursive option ?
    NSString *recursiveString = [Model sharedInstance].loadAllCategoryInfo ? @"true" : @"false";
    if(categoryId == -1)
    {	// hack-ish way to force load all albums -- send a categoyId as -1
        recursiveString = @"true";
        categoryId = 0;
    }
    
    // Community extension active ?
    NSString *fakedString = [Model sharedInstance].hasInstalledCommunity ? @"false" : @"true";
    
    // Get albums list for category
    return [self post:kPiwigoCategoriesGetList
        URLParameters:@{
                        @"categoryId" : @(categoryId),
                        @"recursive" : recursiveString,
                        @"faked" : fakedString
                        }
           parameters:nil
             progress:nil
              success:^(NSURLSessionTask *task, id responseObject) {
                  
                  if([[responseObject objectForKey:@"stat"] isEqualToString:@"ok"])
                  {
                      // Extract albums data from JSON message
                      NSArray *albums = [AlbumService parseAlbumJSON:[[responseObject objectForKey:@"result"] objectForKey:@"categories"]];
                      [[CategoriesData sharedInstance] addAllCategories:albums];
                      
                      // Update albums when Community extension is installed (for non-admin)
                      if (![Model sharedInstance].hasAdminRights && [Model sharedInstance].hasInstalledCommunity) {
                          [AlbumService setUploadRightsForCategory:categoryId];
                      }

                      // Post to the app that the category data has been updated
                      [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationCategoryDataUpdated object:nil];

                      if(completion)
                      {
                          completion(task, albums);
                      }
                  }
                  else
                  {
                      if(completion)
                      {
                          completion(task, nil);
                      }
                  }
              } failure:^(NSURLSessionTask *task, NSError *error) {
#if defined(DEBUG)
                  NSLog(@"getAlbumListForCategory — Fail: %@", [error description]);
#endif
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
		
		if([category objectForKey:@"id_uppercat"] == [NSNull null])
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
		albumData.numberOfSubAlbumImages = [[category objectForKey:@"total_nb_images"] integerValue];
		albumData.numberOfSubCategories = [[category objectForKey:@"nb_categories"] integerValue];
		
		id thumbId = [category objectForKey:@"representative_picture_id"];
		if(thumbId != [NSNull null])
		{
			albumData.albumThumbnailId = [[category objectForKey:@"representative_picture_id"] integerValue];
			albumData.albumThumbnailUrl = [category objectForKey:@"tn_url"];
		}
		
		if([category objectForKey:@"date_last"] != [NSNull null])
		{
			NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
			[dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
			[dateFormatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:[Model sharedInstance].language]];
			albumData.dateLast = [dateFormatter dateFromString:[category objectForKey:@"date_last"]];
		}
        
        if([Model sharedInstance].hasAdminRights) {
            albumData.hasUploadRights = YES;
        } else {
            albumData.hasUploadRights = NO;
        }
		
		[albums addObject:albumData];
	}
	
	return albums;
}

+(void)setUploadRightsForCategory:(NSInteger)categoryId
{
    [self getCommunityAlbumListForCategory:categoryId
                              OnCompletion:^(NSURLSessionTask *task, NSArray *comAlbums) {
                                  if (comAlbums) {
                                      for(NSDictionary *category in comAlbums)
                                      {
                                          NSInteger catId = [[category valueForKey:@"id"] integerValue];
                                          [[CategoriesData sharedInstance] getCategoryById:catId].hasUploadRights = YES;
                                     }
                                   }
                              }
     ];
}

+(NSURLSessionTask*)getCommunityAlbumListForCategory:(NSInteger)categoryId
                                        OnCompletion:(void (^)(NSURLSessionTask *task, NSArray *albums))completion
{
    return [self post:kCommunityCategoriesGetList
        URLParameters:@{
                        @"categoryId" : @(categoryId)
                        }
           parameters:nil
             progress:nil
              success:^(NSURLSessionTask *task, id responseObject) {
                  
                  if (completion) {
                      if([[responseObject objectForKey:@"stat"] isEqualToString:@"ok"]) {
                          NSArray *albums = [[responseObject objectForKey:@"result"] objectForKey:@"categories"];
                          completion(task, albums);
                      } else {
                          completion(task, nil);
                      }
                  }
              } failure:^(NSURLSessionTask *task, NSError *error) {
#if defined(DEBUG)
                  NSLog(@"getCommunityAlbumListForCategory — Fail: %@", [error description]);
#endif
              }];
}

+(NSURLSessionTask*)createCategoryWithName:(NSString*)categoryName
                                withStatus:(NSString*)categoryStatus
                              OnCompletion:(void (^)(NSURLSessionTask *task, BOOL createdSuccessfully))completion
                                 onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
	return [self post:kPiwigoCategoriesAdd
		URLParameters:@{
                        @"name" : [categoryName stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
                        @"status" : categoryStatus
                        }
           parameters:nil
             progress:nil
			  success:^(NSURLSessionTask *task, id responseObject) {
				  
				  if(completion)
				  {
					  completion(task, [[responseObject objectForKey:@"stat"] isEqualToString:@"ok"]);
				  }
			  } failure:fail];
}

+(NSURLSessionTask*)renameCategory:(NSInteger)categoryId
                           forName:(NSString*)categoryName
                      OnCompletion:(void (^)(NSURLSessionTask *task, BOOL renamedSuccessfully))completion
                         onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
	return [self post:kPiwigoCategoriesSetInfo
		URLParameters:nil
		   parameters:@{
						@"category_id" : [NSString stringWithFormat:@"%@", @(categoryId)],
						@"name" : categoryName
                        }
             progress:nil
			  success:^(NSURLSessionTask *task, id responseObject) {
				  
				  if(completion)
				  {
					  completion(task, [[responseObject objectForKey:@"stat"] isEqualToString:@"ok"]);
				  }
			  } failure:fail];
}

+(NSURLSessionTask*)deleteCategory:(NSInteger)categoryId
                      OnCompletion:(void (^)(NSURLSessionTask *task, BOOL deletedSuccessfully))completion
                         onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
	return [self post:kPiwigoCategoriesDelete
		URLParameters:nil
		   parameters:@{
						@"category_id" : [NSString stringWithFormat:@"%@", @(categoryId)],
						@"pwg_token" : [Model sharedInstance].pwgToken
                        }
             progress:nil
			  success:^(NSURLSessionTask *task, id responseObject) {
				  
				  if(completion)
				  {
					  completion(task, [[responseObject objectForKey:@"stat"] isEqualToString:@"ok"]);
				  }
			  } failure:fail];
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
			  } failure:fail];
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
			  } failure:fail];
}

@end
