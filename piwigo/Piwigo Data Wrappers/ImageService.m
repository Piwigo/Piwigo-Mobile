//
//  ImageService.m
//  piwigo
//
//  Created by Spencer Baker on 1/31/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "ImageService.h"
#import "PiwigoImageData.h"
#import "PiwigoAlbumData.h"
#import "CategoriesData.h"
#import "PiwigoTagData.h"
#import "ImagesCollection.h"

NSString * const kGetImageOrderId = @"id";
NSString * const kGetImageOrderFileName = @"file";
NSString * const kGetImageOrderName = @"name";
NSString * const kGetImageOrderVisits = @"hit";
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

#pragma mark - Get images

+(NSURLSessionTask*)getImagesForAlbumId:(NSInteger)albumId
                                 onPage:(NSInteger)page
                               forOrder:(NSString*)order
                           OnCompletion:(void (^)(NSURLSessionTask *task, NSArray *albumImages))completion
                              onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{    
    // Calculate the number of thumbnails displayed per page
    NSInteger imagesPerPage = [ImagesCollection numberOfImagesPerPageForView:nil imagesPerRowInPortrait:AlbumVars.thumbnailsPerRowInPortrait];

    // Compile parameters
    NSDictionary *parameters = @{
                                 @"cat_id"   : @(albumId),
                                 @"per_page" : @(imagesPerPage * 2),
                                 @"page"     : @(page),
                                 @"order"    : order     // Percent-encoded should not be used here!
                                 };

    // Send request
    return [self post:kPiwigoCategoriesGetImages
		URLParameters:nil
           parameters:parameters
       sessionManager:NetworkVarsObjc.sessionManager
             progress:nil
			  success:^(NSURLSessionTask *task, id responseObject) {
				  
          if([[responseObject objectForKey:@"stat"] isEqualToString:@"ok"])
          {
              NSArray *albumImages = [ImageService parseAlbumImagesJSON:[responseObject objectForKey:@"result"] forCategoryId:albumId];
              if(completion) {
                  completion(task, albumImages);
              }
          }
          else
          {
              // Display Piwigo error
              NSError *error = [NetworkHandler getPiwigoErrorFromResponse:responseObject
                                    path:kPiwigoCategoriesGetImages andURLparams:nil];
              if(completion) {
                  [NetworkHandler showPiwigoError:error withCompletion:^{
                      completion(task, nil);
                  }];
              } else {
                  [NetworkHandler showPiwigoError:error withCompletion:nil];
              }
          }
    } failure:^(NSURLSessionTask *task, NSError *error) {
#if defined(DEBUG)
                  NSLog(@"=> getImagesForAlbumId — Fail: %@", [error description]);
#endif
				  if(fail) {
					  fail(task, error);
				  }
			  }];
}

+(NSURLSessionTask*)getImagesForQuery:(NSString *)query
                               onPage:(NSInteger)page
                             forOrder:(NSString *)order
                         OnCompletion:(void (^)(NSURLSessionTask *task, NSArray *searchedImages))completion
                            onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
    // API pwg.images.search returns:
    //  "paging":{"page":0,"per_page":500,"count":1,"total_count":1}
    //  "images":[{"id":240,"width":2016,"height":1342,"hit":1,
    //             "file":"DSC01229.JPG","name":"DSC01229","comment":null,
    //             "date_creation":"2013-01-31 18:32:21","date_available":"2018-08-23 18:32:23",
    //             "page_url":"https:…","element_url":"https:….jpg",
    //             "derivatives":{"square":{"url":"https:….jpg","width":120,"height":120},
    //                            "thumb":{"url":"https:…-th.jpg","width":144,"height":95},
    //                            "2small":{"url":"https:…-2s.jpg","width":240,"height":159},
    //                            "xsmall":{"url":"https:…-xs.jpg","width":432,"height":287},
    //                            "small":{"url":"https:…-sm.jpg","width":576,"height":383},
    //                            "medium":{"url":"https:…-me.jpg","width":792,"height":527},
    //                            "large":{"url":"https:…-la.jpg","width":1008,"height":671},
    //                            "xlarge":{"url":"https:…-xl.jpg","width":1224,"height":814},
    //                            "xxlarge":{"url":"https:…-xx.jpg","width":1656,"height":1102}}
    
    // Calculate the number of thumbnails displayed per page
    NSInteger imagesPerPage = [ImagesCollection numberOfImagesPerPageForView:nil imagesPerRowInPortrait:AlbumVars.thumbnailsPerRowInPortrait];
    
    // Compile parameters
    NSDictionary *parameters = @{
                                 @"query"    : query,
                                 @"per_page" : @(imagesPerPage * 2),
                                 @"page"     : @(page),
                                 @"order"    : order     // Percent-encoded should not be used here!
                                 };
    
    // Cancel active Search request if any
    NSArray <NSURLSessionTask *> *searchTasks = [NetworkVarsObjc.sessionManager tasks];
    for (NSURLSessionTask *task in searchTasks) {
        [task cancel];
    }
    
    // Cancel active image downloads if any
    NSArray <NSURLSessionTask *> *downloadTasks = [NetworkVarsObjc.imagesSessionManager tasks];
    for (NSURLSessionTask *task in downloadTasks) {
        [task cancel];
    }

    // Send request
    return [self post:kPiwigoImageSearch
        URLParameters:nil
           parameters:parameters
       sessionManager:NetworkVarsObjc.sessionManager
             progress:nil
              success:^(NSURLSessionTask *task, id responseObject) {
                  
          if([[responseObject objectForKey:@"stat"] isEqualToString:@"ok"]) {
              // Store number of images in cache
              NSInteger nberImages = [[[[responseObject objectForKey:@"result"] objectForKey:@"paging"] objectForKey:@"total_count"] integerValue];
              [[CategoriesData sharedInstance] getCategoryById:kPiwigoSearchCategoryId].numberOfImages = nberImages;
              [[CategoriesData sharedInstance] getCategoryById:kPiwigoSearchCategoryId].totalNumberOfImages = nberImages;
              
              // Parse images
              NSArray *searchedImages = [ImageService parseAlbumImagesJSON:[responseObject objectForKey:@"result"] forCategoryId:kPiwigoSearchCategoryId];
              if(completion) {
                  completion(task, searchedImages);
              }
          }
          else
          {
              // NOP if query was empty
              if (!query || (query.length == 0)) {
                  [[CategoriesData sharedInstance] getCategoryById:kPiwigoSearchCategoryId].numberOfImages = 0;
                  [[CategoriesData sharedInstance] getCategoryById:kPiwigoSearchCategoryId].totalNumberOfImages = 0;
                  if(completion) {
                      completion(task, @[]);
                  }
              }
              else {
                  // Display Piwigo error
                  NSError *error = [NetworkHandler getPiwigoErrorFromResponse:responseObject
                                        path:kPiwigoImageSearch andURLparams:nil];
                  if(completion) {
                      [NetworkHandler showPiwigoError:error withCompletion:^{
                          completion(task, nil);
                      }];
                  } else {
                      [NetworkHandler showPiwigoError:error withCompletion:nil];
                  }
              }
          }
        } failure:^(NSURLSessionTask *task, NSError *error) {
                  // No error returned if task was cancelled
                  if (task.state == NSURLSessionTaskStateCanceling) {
                      completion(task, @[]);
                  }
                  
                  // Error !
#if defined(DEBUG)
                  NSLog(@"=> getImagesForQuery — Fail: %@", [error description]);
#endif
                  if(fail) {
                      fail(task, error);
                  }
              }];
}

+(NSURLSessionTask*)getImagesForDiscoverId:(NSInteger)categoryId
                                    onPage:(NSInteger)page
                                  forOrder:(NSString *)order
                        OnCompletion:(void (^)(NSURLSessionTask *task, NSArray *searchedImages))completion
                                 onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
    // Calculate the number of thumbnails displayed per page
    NSInteger imagesPerPage = [ImagesCollection numberOfImagesPerPageForView:nil imagesPerRowInPortrait:AlbumVars.thumbnailsPerRowInPortrait];
    
    // Compile parameters
    NSDictionary *parameters = [NSDictionary new];
    if (categoryId == kPiwigoVisitsCategoryId) {
        parameters = @{
                       @"recursive"             : @"true",
                       @"per_page"              : @(imagesPerPage * 2),
                       @"page"                  : @(page),
                       @"order"                 : order,     // Percent-encoded should not be used here!
                       @"f_min_hit"             : @"1"
                     };
    } else if (categoryId == kPiwigoBestCategoryId) {
        parameters = @{
                       @"recursive"             : @"true",
                       @"per_page"              : @(imagesPerPage * 2),
                       @"page"                  : @(page),
                       @"order"                 : order,     // Percent-encoded should not be used here!
                       @"f_min_rate"            : @"1"
                       };
    } else if (categoryId == kPiwigoRecentCategoryId) {
        NSDateFormatter *dateFormatter = [NSDateFormatter new];
        [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
        NSDate *threeMonthsAgo = [NSDate dateWithTimeIntervalSinceNow:(NSTimeInterval)(-3600*24*31*3)];
        NSString *dateAvailableString = [dateFormatter stringFromDate:threeMonthsAgo];
        parameters = @{
                       @"recursive"             : @"true",
                       @"per_page"              : @(imagesPerPage * 2),
                       @"page"                  : @(page),
                       @"order"                 : order,     // Percent-encoded should not be used here!
                       @"f_min_date_available"  : dateAvailableString
                       };
    } else {
        completion(nil, @[]);
    }
    
    // Cancel active Search request if any
    NSArray <NSURLSessionTask *> *searchTasks = [NetworkVarsObjc.sessionManager tasks];
    for (NSURLSessionTask *task in searchTasks) {
        [task cancel];
    }
    
    // Cancel active image downloads if any
    NSArray <NSURLSessionTask *> *downloadTasks = [NetworkVarsObjc.imagesSessionManager tasks];
    for (NSURLSessionTask *task in downloadTasks) {
        [task cancel];
    }
    
    // Send request
    return [self post:kPiwigoCategoriesGetImages
        URLParameters:nil
           parameters:parameters
       sessionManager:NetworkVarsObjc.sessionManager
             progress:nil
              success:^(NSURLSessionTask *task, id responseObject) {
                  
          if([[responseObject objectForKey:@"stat"] isEqualToString:@"ok"]) {
              // Store number of images in cache
              NSInteger nberImages = [[[[responseObject objectForKey:@"result"] objectForKey:@"paging"] objectForKey:@"total_count"] integerValue];
              [[CategoriesData sharedInstance] getCategoryById:categoryId].numberOfImages = nberImages;
              [[CategoriesData sharedInstance] getCategoryById:categoryId].totalNumberOfImages = nberImages;
              
              // Parse images
              NSArray *searchedImages = [ImageService parseAlbumImagesJSON:[responseObject objectForKey:@"result"] forCategoryId:categoryId];
              if(completion) {
                  completion(task, searchedImages);
              }
          }
          else
          {
              // Display Piwigo error
              NSError *error = [NetworkHandler getPiwigoErrorFromResponse:responseObject
                                    path:kPiwigoCategoriesGetImages andURLparams:nil];
              if(completion) {
                  [NetworkHandler showPiwigoError:error withCompletion:^{
                      completion(task, nil);
                  }];
              } else {
                  [NetworkHandler showPiwigoError:error withCompletion:nil];
              }
          }
        } failure:^(NSURLSessionTask *task, NSError *error) {
                  // No error returned if task was cancelled
                  if (task.state == NSURLSessionTaskStateCanceling) {
                      completion(task, @[]);
                  }
                  
                  // Error !
#if defined(DEBUG)
                  NSLog(@"=> getImagesForDiscoverId — Fail: %@", [error description]);
#endif
                  if(fail) {
                      fail(task, error);
                  }
              }];
}

+(NSURLSessionTask*)getImagesForTagId:(NSInteger)tagId
                               onPage:(NSInteger)page
                             forOrder:(NSString *)order
                         OnCompletion:(void (^)(NSURLSessionTask *task, NSArray *searchedImages))completion
                            onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
    // API pwg.tags.getImages returns:
    // "paging":{"page":0,"per_page":100,"count":5,"total_count":5},
    // "images":[{"rank":0,"id":28799,"width":3264,"height":2448,"hit":4,
    //            "file":"Eucalyptine (recto).jpg","name":"Eucalyptine 1","comment":"Tr\u00e8s efficace",
    //            "date_creation":"2015-08-18 20:26:37","date_available":"2016-01-02 12:29:07",
    //            "page_url":"https:…","element_url":"https:….jpg",
    //            "derivatives":{"square":{"url":"https:…-sq.jpg","width":120,"height":120},
    //                           "thumb":{"url":"https:…-th.jpg","width":144,"height":108},
    //                           "2small":{"url":"https:…-2s.jpg","width":240,"height":180},
    //                           "xsmall":{"url":"https:…-xs.jpg","width":432,"height":324},
    //                           "small":{"url":"https:…-sm.jpg","width":576,"height":432},
    //                           "medium":{"url":"https:…-me.jpg","width":792,"height":594},
    //                           "large":{"url":"https:…-la.jpg","width":1008,"height":756},
    //                           "xlarge":{"url":"https:…-xl.jpg","width":1224,"height":918},
    //                           "xxlarge":{"url":"https:…-xx.jpg","width":1656,"height":1242}},
    //            "tags":[{"id":15,"url":"https:…","page_url":"https:…"}]},
    //           {"rank":1,"id":28800,"width":3264,"height":2448,"hit":1,
    //            "file":…
    
    // Calculate the number of thumbnails displayed per page
    NSInteger imagesPerPage = [ImagesCollection numberOfImagesPerPageForView:nil imagesPerRowInPortrait:AlbumVars.thumbnailsPerRowInPortrait];
    
    // Compile parameters
    NSDictionary *parameters = @{@"tag_id"         : @(tagId),
                                 @"per_page"       : @(imagesPerPage * 2),
                                 @"page"           : @(page),
                                 @"order"          : @"rank asc, id desc"
                                  };
    
    // Cancel active Search request if any
    NSArray <NSURLSessionTask *> *searchTasks = [NetworkVarsObjc.sessionManager tasks];
    for (NSURLSessionTask *task in searchTasks) {
        [task cancel];
    }
    
    // Cancel active image downloads if any
    NSArray <NSURLSessionTask *> *downloadTasks = [NetworkVarsObjc.imagesSessionManager tasks];
    for (NSURLSessionTask *task in downloadTasks) {
        [task cancel];
    }
    
    // Send request
    return [self post:kPiwigoTagsGetImages
        URLParameters:nil
           parameters:parameters
       sessionManager:NetworkVarsObjc.sessionManager
             progress:nil
              success:^(NSURLSessionTask *task, id responseObject) {
                  
        if([[responseObject objectForKey:@"stat"] isEqualToString:@"ok"]) {
            // Store number of images in cache
            NSInteger nberImages = [[[[responseObject objectForKey:@"result"] objectForKey:@"paging"] objectForKey:@"total_count"] integerValue];
            [[CategoriesData sharedInstance] getCategoryById:kPiwigoTagsCategoryId].numberOfImages = nberImages;
            [[CategoriesData sharedInstance] getCategoryById:kPiwigoTagsCategoryId].totalNumberOfImages = nberImages;
            
            // Parse images
            NSArray *searchedImages = [ImageService parseAlbumImagesJSON:[responseObject objectForKey:@"result"] forCategoryId:kPiwigoTagsCategoryId];
            if(completion) {
                completion(task, searchedImages);
            }
        }
        else
        {
            // Display Piwigo error
            NSError *error = [NetworkHandler getPiwigoErrorFromResponse:responseObject
                                        path:kPiwigoTagsGetImages andURLparams:nil];
            if(completion) {
                [NetworkHandler showPiwigoError:error withCompletion:^{
                    completion(task, nil);
                }];
            } else {
                [NetworkHandler showPiwigoError:error withCompletion:nil];
            }
        }
    } failure:^(NSURLSessionTask *task, NSError *error) {
                  // No error returned if task was cancelled
                  if (task.state == NSURLSessionTaskStateCanceling) {
                      completion(task, @[]);
                  }
                  
                  // Error !
#if defined(DEBUG)
                  NSLog(@"=> getImagesForDiscoverId — Fail: %@", [error description]);
#endif
                  if(fail) {
                      fail(task, error);
                  }
              }];
}

+(NSURLSessionTask*)getFavoritesOnPage:(NSInteger)page
                              forOrder:(NSString *)order
                          OnCompletion:(void (^)(NSURLSessionTask *task, NSArray *searchedImages))completion
                             onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
    // API pwg.users.favorites.getList
    // "paging":{"page":0,"per_page":100,"count":4},
    // "images":[{"id":506,"width":3872,"height":2592,"hit":3,
    //          "file":"Saragossa.jpg","name":"Saragossa","comment":null,
    //          "date_creation":"2012-05-31 22:13:18","date_available":"2018-08-23 22:00:28",
    //          "page_url":"https:…","element_url":"https:….jpg",
    //          "derivatives":{"square":{"url":"https:…-sq.jpg","width":120,"height":120},
    //                         "thumb":{"url":"https:…-th.jpg","width":144,"height":96},
    //                         "2small":{"url":"https:…-2s.jpg","width":240,"height":160},
    //                         "xsmall":{"url":"https:…-xs.jpg","width":432,"height":289},
    //                         "small":{"url":"https:…-sm.jpg","width":576,"height":385},
    //                         "medium":{"url":"https:…-me.jpg","width":792,"height":530},
    //                         "large":{"url":"https:…-la.jpg","width":1008,"height":674},
    //                         "xlarge":{"url":"https:…-xl.jpg","width":1224,"height":819},
    //                         "xxlarge":{"url":"https:…-xx.jpg","width":1656,"height":1108}}},
    //          {"id":…
    
    // Calculate the number of thumbnails displayed per page
    NSInteger imagesPerPage = [ImagesCollection numberOfImagesPerPageForView:nil imagesPerRowInPortrait:AlbumVars.thumbnailsPerRowInPortrait];
    
    // Compile parameters
    NSDictionary *parameters = @{@"per_page"       : @(imagesPerPage * 2),
                                 @"page"           : @(page),
                                 @"order"          : order
                                 };
    
    // Send request
    return [self post:kPiwigoUserFavoritesGetList
        URLParameters:nil
           parameters:parameters
       sessionManager:NetworkVarsObjc.favoritesManager
             progress:nil
              success:^(NSURLSessionTask *task, id responseObject) {
                  
          if([[responseObject objectForKey:@"stat"] isEqualToString:@"ok"]) {
              // Check the presence of favorite images
              if ([[responseObject objectForKey:@"result"] isKindOfClass:[NSDictionary class]]) {
                  // Store number of images in cache
                  NSInteger nberImages = [[[[responseObject objectForKey:@"result"] objectForKey:@"paging"] objectForKey:@"count"] integerValue];
                  [[CategoriesData sharedInstance] getCategoryById:kPiwigoFavoritesCategoryId].numberOfImages = nberImages;
                  [[CategoriesData sharedInstance] getCategoryById:kPiwigoFavoritesCategoryId].totalNumberOfImages = nberImages;
                  
                  // Parse images
                  NSArray *searchedImages = [ImageService parseAlbumImagesJSON:[responseObject objectForKey:@"result"] forCategoryId:kPiwigoFavoritesCategoryId];
                  if(completion) {
                      completion(task, searchedImages);
                  }
              } else {
                  // No favorite image in the server database
                  [[CategoriesData sharedInstance] getCategoryById:kPiwigoFavoritesCategoryId].numberOfImages = 0;
                  [[CategoriesData sharedInstance] getCategoryById:kPiwigoFavoritesCategoryId].totalNumberOfImages = 0;
                  if(completion) {
                      completion(task, [NSArray new]);
                  }
              }
          }
          else
          {
              // Display Piwigo error
              NSError *error = [NetworkHandler getPiwigoErrorFromResponse:responseObject
                                    path:kPiwigoUserFavoritesGetList andURLparams:nil];
              if(completion) {
                  [NetworkHandler showPiwigoError:error withCompletion:^{
                      completion(task, nil);
                  }];
              } else {
                  [NetworkHandler showPiwigoError:error withCompletion:nil];
              }
          }
      } failure:^(NSURLSessionTask *task, NSError *error) {
                  // No error returned if task was cancelled
                  if (task.state == NSURLSessionTaskStateCanceling) {
                      completion(task, @[]);
                  }
                  
                  // Error !
#if defined(DEBUG)
                  NSLog(@"=> getImagesForDiscoverId — Fail: %@", [error description]);
#endif
                  if(fail) {
                      fail(task, error);
                  }
              }];
}

+(NSURLSessionTask*)loadImageChunkForLastChunkCount:(NSInteger)lastImageBulkCount
                                        forCategory:(NSInteger)categoryId orQuery:(NSString*)query
                                             onPage:(NSInteger)onPage
                                            forSort:(NSString *)sort
                                   ListOnCompletion:(void (^)(NSURLSessionTask *task, NSInteger count))completion
                                          onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
    NSInteger downloadedImageDataCount = [[CategoriesData sharedInstance] getCategoryById:categoryId].imageList.count;
    NSInteger totalImageCount = [[CategoriesData sharedInstance] getCategoryById:categoryId].numberOfImages;
//    NSLog(@"loadImageChunkForLastChunkCount: %ld / %ld images", (long)downloadedImageDataCount, (long)totalImageCount);
    if (downloadedImageDataCount >= totalImageCount)
    {    // Done. Don't need anymore
        if (completion) {
            completion(nil, 0);
        }
        return nil;
    }
    
    NSURLSessionTask *task;
    if (categoryId == kPiwigoSearchCategoryId) {
        // Load search image data for query
        task = [ImageService getImagesForQuery:query
                                        onPage:onPage
                                      forOrder:sort
                                  OnCompletion:^(NSURLSessionTask *task, NSArray *albumImages) {
                                      if (albumImages) {
                                          PiwigoAlbumData *albumData = [[CategoriesData sharedInstance] getCategoryById:categoryId];
                                          NSInteger count = [albumData addImages:albumImages];
//                                          NSLog(@"loadImageChunkForLastChunkCount: added %ld images", (long)count);
                                          if (completion) {
                                              completion(task, count);
                                          }
                                      } else {
                                          if (completion) {
                                            completion(task, 0);
                                          }
                                      }

                                  } onFailure:^(NSURLSessionTask *task, NSError *error) {
#if defined(DEBUG)
                                      NSLog(@"loadImageChunkForLastChunkCount — Fail: %@", [error description]);
#endif
                                      if(fail) {
                                          fail(nil, error);
                                      }
                                  }];
    }
    else if ((categoryId == kPiwigoVisitsCategoryId) ||
             (categoryId == kPiwigoBestCategoryId)   ||
             (categoryId == kPiwigoRecentCategoryId)) {
        // Load most visited images, best images, recent images
        task = [ImageService getImagesForDiscoverId:categoryId
                                             onPage:onPage
                                           forOrder:sort
                                       OnCompletion:^(NSURLSessionTask *task, NSArray *albumImages) {
                                      if (albumImages) {
                                          PiwigoAlbumData *albumData = [[CategoriesData sharedInstance] getCategoryById:categoryId];
                                          NSInteger count = [albumData addImages:albumImages];
//                                          NSLog(@"loadImageChunkForLastChunkCount: added %ld images", (long)count);
                                          if (completion) {
                                              completion(task, count);
                                          }
                                      } else {
                                          if (completion) {
                                            completion(task, 0);
                                          }
                                      }

                                  } onFailure:^(NSURLSessionTask *task, NSError *error) {
#if defined(DEBUG)
                                      NSLog(@"loadImageChunkForLastChunkCount — Fail: %@", [error description]);
#endif
                                      if(fail) {
                                          fail(nil, error);
                                      }
                                  }];
    }
    else if (categoryId == kPiwigoTagsCategoryId) {
        // Load tagged images
        NSInteger tagId = [[[CategoriesData sharedInstance] getCategoryById:categoryId].query integerValue];
        task = [ImageService getImagesForTagId:tagId
                                        onPage:onPage
                                      forOrder:sort
                                  OnCompletion:^(NSURLSessionTask *task, NSArray *albumImages) {
                                      if (albumImages) {
                                          PiwigoAlbumData *albumData = [[CategoriesData sharedInstance] getCategoryById:categoryId];
                                          NSInteger count = [albumData addImages:albumImages];
//                                          NSLog(@"loadImageChunkForLastChunkCount: added %ld images", (long)count);
                                          if (completion) {
                                              completion(task, count);
                                          }
                                      } else {
                                          if (completion) {
                                            completion(task, 0);
                                          }
                                      }
                                  } onFailure:^(NSURLSessionTask *task, NSError *error) {
#if defined(DEBUG)
                                      NSLog(@"loadImageChunkForLastChunkCount — Fail: %@", [error description]);
#endif
                                      if(fail) {
                                          fail(nil, error);
                                      }
                                  }];
    }
    else if (categoryId == kPiwigoFavoritesCategoryId) {
        // Load favorite images
        task = [ImageService getFavoritesOnPage:onPage
                                       forOrder:sort
                                   OnCompletion:^(NSURLSessionTask *task, NSArray *albumImages) {
                                        if (albumImages) {
                                            PiwigoAlbumData *albumData = [[CategoriesData sharedInstance] getCategoryById:categoryId];
                                            NSInteger count = [albumData addImages:albumImages];
//                                            NSLog(@"loadImageChunkForLastChunkCount: added %ld images", (long)count);
                                            if (completion) {
                                                completion(task, count);
                                            }
                                        } else {
                                            if (completion) {
                                              completion(task, 0);
                                            }
                                        }

                                   } onFailure:^(NSURLSessionTask *task, NSError *error) {
#if defined(DEBUG)
                                       NSLog(@"loadImageChunkForLastChunkCount — Fail: %@", [error description]);
#endif
                                       if (fail) {
                                           fail(task, error);
                                       }
                                   }];
    }
    else
    {
        // Load category image data
        task = [ImageService getImagesForAlbumId:categoryId
                                          onPage:onPage
                                        forOrder:sort
                                    OnCompletion:^(NSURLSessionTask *task, NSArray *albumImages) {
                                          if (albumImages) {
                                              PiwigoAlbumData *albumData = [[CategoriesData sharedInstance] getCategoryById:categoryId];
                                              NSInteger count = [albumData addImages:albumImages];
//                                              NSLog(@"loadImageChunkForLastChunkCount: added %ld images", (long)count);
                                              if (completion) {
                                                  completion(task, count);
                                              }
                                          } else {
                                              if (completion) {
                                                  completion(task, 0);
                                              }
                                          }
                                      } onFailure:^(NSURLSessionTask *task, NSError *error) {
#if defined(DEBUG)
                                          NSLog(@"loadImageChunkForLastChunkCount — Fail: %@", [error description]);
#endif
                                          if(fail) {
                                              fail(task, error);
                                          }
                                      }
                              ];
    }
    
    task.priority = NSOperationQueuePriorityVeryHigh;
    return task;
}

+(NSArray*)parseAlbumImagesJSON:(NSDictionary*)json forCategoryId:(NSInteger)categoryId
{
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


#pragma mark - Get image data

+(PiwigoImageData*)parseBasicImageInfoJSON:(NSDictionary*)imageJson
{
	PiwigoImageData *imageData = [PiwigoImageData new];
	
    // API pwg.categories.getImages returns:
    //      id, categories, name, comment, hit
    //      file, date_creation, date_available, width, height
    //      element_url, derivatives, (page_url)
    //

    // Object "id"
    imageData.imageId = [[imageJson objectForKey:@"id"] integerValue];

    // Object "categories"
    NSDictionary *categories = [imageJson objectForKey:@"categories"];
    NSMutableArray *categoryIds = [NSMutableArray new];
    for(NSDictionary *category in categories)
    {
        [categoryIds addObject:[category objectForKey:@"id"]];
    }
    imageData.categoryIds = categoryIds;
    categoryIds = nil;

    // Object "name"
    NSString *name = [imageJson objectForKey:@"name"];
    if ((name != nil) && ![name isKindOfClass:[NSNull class]]) {
        imageData.imageTitle = [NetworkObjcUtilities utf8mb4ObjcStringFrom:[imageJson objectForKey:@"name"]];
    } else {
        imageData.imageTitle = @"";
    }
    
    // Object "comment"
    NSString *comment = [imageJson objectForKey:@"comment"];
    if ((comment != nil) && ![comment isKindOfClass:[NSNull class]]) {
        imageData.comment = [NetworkObjcUtilities utf8mb4ObjcStringFrom:[imageJson objectForKey:@"comment"]];
    } else {
        imageData.comment = @"";
    }
    
    // Object "hit"
    if (![[imageJson objectForKey:@"hit"] isKindOfClass:[NSNull class]]) {
        imageData.visits = [[imageJson objectForKey:@"hit"] integerValue];
    } else {
        imageData.visits = 0;
    }
    
    // Object "file"
    NSString *file = [imageJson objectForKey:@"file"];
    if ((file != nil) && ![file isKindOfClass:[NSNull class]]) {
        imageData.fileName = [NetworkObjcUtilities utf8mb4ObjcStringFrom:[imageJson objectForKey:@"file"]];
    } else {
        imageData.fileName = @"NoName.jpg";    // Filename should never be empty. Just in case…
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
    
    // Object "date_available"
    NSDateFormatter *dateFormat = [NSDateFormatter new];
    [dateFormat setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    NSString *dateAvailableString = [imageJson objectForKey:@"date_available"];
    if ((dateAvailableString != nil) && ![dateAvailableString isKindOfClass:[NSNull class]]) {
        imageData.datePosted = [dateFormat dateFromString:dateAvailableString];
    } else {
        imageData.datePosted = [NSDate date];
    }
    
    // Object "date_creation"
    NSString *dateCreatedString = [imageJson objectForKey:@"date_creation"];
    if ((dateCreatedString != nil) && ![dateCreatedString isKindOfClass:[NSNull class]]) {
        imageData.dateCreated = [dateFormat dateFromString:dateCreatedString];
    }
    else {
        // When creation is unknown, use posted date so that image sort becomes possible
        imageData.dateCreated = imageData.datePosted;
    }

    // Object "width"
    if (![[imageJson objectForKey:@"width"] isKindOfClass:[NSNull class]]) {
        imageData.fullResWidth = [[imageJson objectForKey:@"width"] integerValue];
    }
    
    // Object "height"
    if (![[imageJson objectForKey:@"height"] isKindOfClass:[NSNull class]]) {
        imageData.fullResHeight = [[imageJson objectForKey:@"height"] integerValue];
    }

    // Object "element_url"
    // When $conf['original_url_protection'] = 'images' or 'all'; is enabled
    // the URLs returned by the Piwigo server contain &amp; instead of & (Piwigo v2.9.2)
    NSString *fullResURL = [imageJson objectForKey:@"element_url"];
    if ((fullResURL != nil) && ![fullResURL isKindOfClass:[NSNull class]]) {
        imageData.fullResPath = [NetworkHandler encodedImageURL:[fullResURL stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"]];
    } else {
        // When the image URL is unknown, use an empty URL
        imageData.fullResPath = @"";
    }
    
    // Objects "derivatives"
    // When $conf['original_url_protection'] = 'images' or 'all'; is enabled
    // the URLs returned by the Piwigo server contain &amp; instead of & (Piwigo v2.9.2)
	NSDictionary *imageSizes = [imageJson objectForKey:@"derivatives"];
    
    // Square image
    NSString *square = [[imageSizes objectForKey:@"square"] objectForKey:@"url"];
    if ((square != nil) && ![square isKindOfClass:[NSNull class]]) {
        imageData.SquarePath = [NetworkHandler encodedImageURL:[square stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"]];
    } else {
        imageData.SquarePath = @"";
    }
    if (![[[imageSizes objectForKey:@"square"] objectForKey:@"width"] isKindOfClass:[NSNull class]]) {
        imageData.SquareWidth = [[[imageSizes objectForKey:@"square"] objectForKey:@"width"] integerValue];
    }
    else {
        // When the image dimensions are unknown, use 1
        imageData.SquareWidth = 1;
    }
    if (![[[imageSizes objectForKey:@"square"] objectForKey:@"height"] isKindOfClass:[NSNull class]]) {
        imageData.SquareHeight = [[[imageSizes objectForKey:@"square"] objectForKey:@"height"] integerValue];
    }
    else {
        // When the image dimensions are unknown, use 1
        imageData.SquareHeight = 1;
    }

    // Thumbnail image
    NSString *thumb = [[imageSizes objectForKey:@"thumb"] objectForKey:@"url"];
    if ((thumb != nil) && ![thumb isKindOfClass:[NSNull class]]) {
        imageData.ThumbPath = [NetworkHandler encodedImageURL:[thumb stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"]];
    } else {
        imageData.ThumbPath = @"";
    }
    if (![[[imageSizes objectForKey:@"thumb"] objectForKey:@"width"] isKindOfClass:[NSNull class]]) {
        imageData.ThumbWidth = [[[imageSizes objectForKey:@"thumb"] objectForKey:@"width"] integerValue];
    }
    else {
        // When the image dimensions are unknown, use 1
        imageData.ThumbWidth = 1;
    }
    if (![[[imageSizes objectForKey:@"thumb"] objectForKey:@"height"] isKindOfClass:[NSNull class]]) {
        imageData.ThumbHeight = [[[imageSizes objectForKey:@"thumb"] objectForKey:@"height"] integerValue];
    }
    else {
        // When the image dimensions are unknown, use 1
        imageData.ThumbHeight = 1;
    }

    // Medium image
    NSString *medium = [[imageSizes objectForKey:@"medium"] objectForKey:@"url"];
    if ((medium != nil) && ![medium isKindOfClass:[NSNull class]]) {
        imageData.MediumPath = [NetworkHandler encodedImageURL:[medium stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"]];
    } else {
        imageData.MediumPath = @"";
    }
    if (![[[imageSizes objectForKey:@"medium"] objectForKey:@"width"] isKindOfClass:[NSNull class]]) {
        imageData.MediumWidth = [[[imageSizes objectForKey:@"medium"] objectForKey:@"width"] integerValue];
    }
    else {
        // When the image dimensions are unknown, use 1
        imageData.MediumWidth = 1;
    }
    if (![[[imageSizes objectForKey:@"medium"] objectForKey:@"height"] isKindOfClass:[NSNull class]]) {
        imageData.MediumHeight = [[[imageSizes objectForKey:@"medium"] objectForKey:@"height"] integerValue];
    }
    else {
        // When the image dimensions are unknown, use 1
        imageData.MediumHeight = 1;
    }

    // XX small image
    NSString *xxsmall = [[imageSizes objectForKey:@"2small"] objectForKey:@"url"];
    if ((xxsmall != nil) && ![xxsmall isKindOfClass:[NSNull class]]) {
        imageData.XXSmallPath = [NetworkHandler encodedImageURL:[xxsmall stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"]];
    } else {
        imageData.XXSmallPath = @"";
    }
    if (![[[imageSizes objectForKey:@"2small"] objectForKey:@"width"] isKindOfClass:[NSNull class]]) {
        imageData.XXSmallWidth = [[[imageSizes objectForKey:@"2small"] objectForKey:@"width"] integerValue];
    }
    else {
        // When the image dimensions are unknown, use 1
        imageData.XXSmallWidth = 1;
    }
    if (![[[imageSizes objectForKey:@"2small"] objectForKey:@"height"] isKindOfClass:[NSNull class]]) {
        imageData.XXSmallHeight = [[[imageSizes objectForKey:@"2small"] objectForKey:@"height"] integerValue];
    }
    else {
        // When the image dimensions are unknown, use 1
        imageData.XXSmallHeight = 1;
    }

    // X small image
    NSString *xsmall = [[imageSizes objectForKey:@"xsmall"] objectForKey:@"url"];
    if ((xsmall != nil) && ![xsmall isKindOfClass:[NSNull class]]) {
        imageData.XSmallPath = [NetworkHandler encodedImageURL:[xsmall stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"]];
    } else {
        imageData.XSmallPath = @"";
    }
    if (![[[imageSizes objectForKey:@"xsmall"] objectForKey:@"width"] isKindOfClass:[NSNull class]]) {
        imageData.XSmallWidth = [[[imageSizes objectForKey:@"xsmall"] objectForKey:@"width"] integerValue];
    }
    else {
        // When the image dimensions are unknown, use 1
        imageData.XSmallWidth = 1;
    }
    if (![[[imageSizes objectForKey:@"xsmall"] objectForKey:@"height"] isKindOfClass:[NSNull class]]) {
        imageData.XSmallHeight = [[[imageSizes objectForKey:@"xsmall"] objectForKey:@"height"] integerValue];
    }
    else {
        // When the image dimensions are unknown, use 1
        imageData.XSmallHeight = 1;
    }

    // Small image
    NSString *small = [[imageSizes objectForKey:@"small"] objectForKey:@"url"];
    if ((small != nil) && ![small isKindOfClass:[NSNull class]]) {
        imageData.SmallPath = [NetworkHandler encodedImageURL:[small stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"]];
    } else {
        imageData.SmallPath = @"";
    }
    if (![[[imageSizes objectForKey:@"small"] objectForKey:@"width"] isKindOfClass:[NSNull class]]) {
        imageData.SmallWidth = [[[imageSizes objectForKey:@"small"] objectForKey:@"width"] integerValue];
    }
    else {
        // When the image dimensions are unknown, use 1
        imageData.SmallWidth = 1;
    }
    if (![[[imageSizes objectForKey:@"small"] objectForKey:@"height"] isKindOfClass:[NSNull class]]) {
        imageData.SmallHeight = [[[imageSizes objectForKey:@"small"] objectForKey:@"height"] integerValue];
    }
    else {
        // When the image dimensions are unknown, use 1
        imageData.SmallHeight = 1;
    }

    // Large image
    NSString *large = [[imageSizes objectForKey:@"large"] objectForKey:@"url"];
    if ((large != nil) && ![large isKindOfClass:[NSNull class]]) {
        imageData.LargePath = [NetworkHandler encodedImageURL:[large stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"]];
    } else {
        imageData.LargePath = @"";
    }
    if (![[[imageSizes objectForKey:@"large"] objectForKey:@"width"] isKindOfClass:[NSNull class]]) {
        imageData.LargeWidth = [[[imageSizes objectForKey:@"large"] objectForKey:@"width"] integerValue];
    }
    else {
        // When the image dimensions are unknown, use 1
        imageData.LargeWidth = 1;
    }
    if (![[[imageSizes objectForKey:@"large"] objectForKey:@"height"] isKindOfClass:[NSNull class]]) {
        imageData.LargeHeight = [[[imageSizes objectForKey:@"large"] objectForKey:@"height"] integerValue];
    }
    else {
        // When the image dimensions are unknown, use 1
        imageData.LargeHeight = 1;
    }

    // X large image
    NSString *xlarge = [[imageSizes objectForKey:@"xlarge"] objectForKey:@"url"];
    if ((xlarge != nil) && ![xlarge isKindOfClass:[NSNull class]]) {
        imageData.XLargePath = [NetworkHandler encodedImageURL:[xlarge stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"]];
    } else {
        imageData.XLargePath = @"";
    }
    if (![[[imageSizes objectForKey:@"xlarge"] objectForKey:@"width"] isKindOfClass:[NSNull class]]) {
        imageData.XLargeWidth = [[[imageSizes objectForKey:@"xlarge"] objectForKey:@"width"] integerValue];
    }
    else {
        // When the image dimensions are unknown, use 1
        imageData.XLargeWidth = 1;
    }
    if (![[[imageSizes objectForKey:@"xlarge"] objectForKey:@"height"] isKindOfClass:[NSNull class]]) {
        imageData.XLargeHeight = [[[imageSizes objectForKey:@"xlarge"] objectForKey:@"height"] integerValue];
    }
    else {
        // When the image dimensions are unknown, use 1
        imageData.XLargeHeight = 1;
    }

    // XX large image
    NSString *xxlarge = [[imageSizes objectForKey:@"xxlarge"] objectForKey:@"url"];
    if ((xxlarge != nil) && ![xxlarge isKindOfClass:[NSNull class]]) {
        imageData.XXLargePath = [NetworkHandler encodedImageURL:[xxlarge stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"]];
    } else {
        imageData.XXLargePath = @"";
    }
    if (![[[imageSizes objectForKey:@"xxlarge"] objectForKey:@"width"] isKindOfClass:[NSNull class]]) {
        imageData.XXLargeWidth = [[[imageSizes objectForKey:@"xxlarge"] objectForKey:@"width"] integerValue];
    }
    else {
        // When the image dimensions are unknown, use 1
        imageData.XXLargeWidth = 1;
    }
    if (![[[imageSizes objectForKey:@"xxlarge"] objectForKey:@"height"] isKindOfClass:[NSNull class]]) {
        imageData.XXLargeHeight = [[[imageSizes objectForKey:@"xxlarge"] objectForKey:@"height"] integerValue];
    }
    else {
        // When the image dimensions are unknown, use 1
        imageData.XXLargeHeight = 1;
    }
    
    // API pwg.images.getInfo returns in addition:
    //
    //      author, level, tags, (added_by), rating_score, (rates), (representative_ext)
    //      filesize, (md5sum), (date_metadata_update), (lastmodified), (rotation), (latitude), (longitude)
    //      (comments), (comments_paging), (coi)
    //
    
    // Object "author"
    NSString *author = [imageJson objectForKey:@"author"];
    if ((author != nil) && ![author isKindOfClass:[NSNull class]]) {
        imageData.author = [NetworkObjcUtilities utf8mb4ObjcStringFrom:author];
    } else {
        imageData.author = @"NSNotFound";
    }

    // Object "level"
    if ([imageJson objectForKey:@"level"] &&
        ![[imageJson objectForKey:@"level"] isKindOfClass:[NSNull class]]) {
        imageData.privacyLevel = (kPiwigoPrivacyObjc)[[imageJson objectForKey:@"level"] integerValue];
    } else {
        imageData.privacyLevel = kPiwigoPrivacyObjcUnknown;
    }
    
    // Object "tags"
    if ([imageJson objectForKey:@"tags"] &&
        ![[imageJson objectForKey:@"tags"] isKindOfClass:[NSNull class]]) {
        NSDictionary *tags = [imageJson objectForKey:@"tags"];
        NSMutableArray *imageTags = [NSMutableArray new];
        for(NSDictionary *tag in tags)
        {
            PiwigoTagData *tagData = [PiwigoTagData new];
            tagData.tagId = [[tag objectForKey:@"id"] integerValue];
            if (![[tag objectForKey:@"name"] isKindOfClass:[NSNull class]]) {
                tagData.tagName = [NetworkObjcUtilities utf8mb4ObjcStringFrom:[tag objectForKey:@"name"]];
            } else {
                tagData.tagName = @"";
            }
            NSDateFormatter *dateFormat = [NSDateFormatter new];
            [dateFormat setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
            NSString *lastModifiedString = [tag objectForKey:@"lastmodified"];
            if (![lastModifiedString isKindOfClass:[NSNull class]]) {
                tagData.lastModified = [dateFormat dateFromString:lastModifiedString];
            } else {
                tagData.lastModified = [NSDate date];
            }
            tagData.numberOfImagesUnderTag = NSNotFound;
            [imageTags addObject:tagData];
        }
        imageData.tags = imageTags;
        imageTags = nil;
    }
    
    // Object "rating_score"
    if ([imageJson objectForKey:@"rating_score"] &&
        ![[imageJson objectForKey:@"rating_score"] isKindOfClass:[NSNull class]]) {
        imageData.ratingScore = [[imageJson objectForKey:@"rating_score"] floatValue];
    } else {
        imageData.ratingScore = NSNotFound;
    }
    
    // Object "filesize"
    if ([imageJson objectForKey:@"filesize"] &&
        ![[imageJson objectForKey:@"filesize"] isKindOfClass:[NSNull class]]) {
        imageData.fileSize = [[imageJson objectForKey:@"filesize"] integerValue];
    } else {
        imageData.fileSize = NSNotFound;
    }
    
    // Object "md5sum"
    NSString *md5sum = [imageJson objectForKey:@"md5sum"];
    if ((md5sum != nil) && ![md5sum isKindOfClass:[NSNull class]]) {
        imageData.MD5checksum = [NetworkObjcUtilities utf8mb4ObjcStringFrom:[imageJson objectForKey:@"md5sum"]];
    } else {
        imageData.MD5checksum = @"";
    }

    return imageData;
}


#pragma mark - Set image data

+(NSURLSessionTask*)addToFavoritesImageWithId:(NSInteger)imageId
                                   onProgress:(void (^)(NSProgress *))progress
                                 OnCompletion:(void (^)(NSURLSessionTask *task, BOOL addedSuccessfully))completion
                                    onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
    NSURLSessionTask *request = [self post:kPiwigoUserFavoritesAdd
             URLParameters:nil
                parameters:@{
                             @"image_id" : [NSString stringWithFormat:@"%ld", (long)imageId]
                             }
            sessionManager:NetworkVarsObjc.sessionManager
                  progress:progress
                   success:^(NSURLSessionTask *task, id responseObject) {
                       
                       if(completion)
                       {
                           completion(task, [[responseObject objectForKey:@"stat"] isEqualToString:@"ok"]);
                       }
                } failure:^(NSURLSessionTask *task, NSError *error) {
#if defined(DEBUG)
                    NSLog(@"=> addToFavoritesImageWithId — Fail: %@", [error description]);
#endif
                    if(fail) {
                        fail(task, error);
                    }
                }];

    return request;
}

+(NSURLSessionTask*)removeImageFromFavorites:(PiwigoImageData *)image
                                  onProgress:(void (^)(NSProgress *))progress
                                OnCompletion:(void (^)(NSURLSessionTask *task, BOOL removedSuccessfully))completion
                                   onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
    NSURLSessionTask *request = [self post:kPiwigoUserFavoritesRemove
             URLParameters:nil
                parameters:@{
                             @"image_id" : [NSString stringWithFormat:@"%ld", (long)image.imageId]
                             }
            sessionManager:NetworkVarsObjc.sessionManager
                  progress:progress
                   success:^(NSURLSessionTask *task, id responseObject) {
                       
                       if(completion)
                       {
                           completion(task, [[responseObject objectForKey:@"stat"] isEqualToString:@"ok"]);
                       }
                } failure:^(NSURLSessionTask *task, NSError *error) {
#if defined(DEBUG)
                   NSLog(@"=> removeImageFromFavorites — Fail: %@", [error description]);
#endif
                   if(fail) {
                       fail(task, error);
                   }
               }];

    return request;
}

@end
