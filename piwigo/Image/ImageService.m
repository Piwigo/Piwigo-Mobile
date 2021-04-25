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
    NSInteger imagesPerPage = [ImagesCollection numberOfImagesPerPageForView:nil imagesPerRowInPortrait:[Model sharedInstance].thumbnailsPerRowInPortrait];

    // Compile parameters
    NSDictionary *parameters = @{
                                 @"cat_id"   : @(albumId),
                                 @"per_page" : @(imagesPerPage),
                                 @"page"     : @(page),
                                 @"order"    : order     // Percent-encoded should not be used here!
                                 };

    // Send request
    return [self post:kPiwigoCategoriesGetImages
		URLParameters:nil
           parameters:parameters
       sessionManager:[Model sharedInstance].sessionManager
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
    NSInteger imagesPerPage = [ImagesCollection numberOfImagesPerPageForView:nil imagesPerRowInPortrait:[Model sharedInstance].thumbnailsPerRowInPortrait];
    
    // Compile parameters
    NSDictionary *parameters = @{
                                 @"query"    : query,
                                 @"per_page" : @(imagesPerPage),
                                 @"page"     : @(page),
                                 @"order"    : order     // Percent-encoded should not be used here!
                                 };
    
    // Cancel active Search request if any
    NSArray <NSURLSessionTask *> *searchTasks = [[Model sharedInstance].sessionManager tasks];
    for (NSURLSessionTask *task in searchTasks) {
        [task cancel];
    }
    
    // Cancel active image downloads if any
    NSArray <NSURLSessionTask *> *downloadTasks = [[Model sharedInstance].imagesSessionManager tasks];
    for (NSURLSessionTask *task in downloadTasks) {
        [task cancel];
    }

    // Send request
    return [self post:kPiwigoImageSearch
        URLParameters:nil
           parameters:parameters
       sessionManager:[Model sharedInstance].sessionManager
             progress:nil
              success:^(NSURLSessionTask *task, id responseObject) {
                  
          if([[responseObject objectForKey:@"stat"] isEqualToString:@"ok"]) {
              // Store number of images in cache
              NSInteger nberImages = [[[[responseObject objectForKey:@"result"] objectForKey:@"paging"] objectForKey:@"count"] integerValue];
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
    NSInteger imagesPerPage = [ImagesCollection numberOfImagesPerPageForView:nil imagesPerRowInPortrait:[Model sharedInstance].thumbnailsPerRowInPortrait];
    
    // Compile parameters
    NSDictionary *parameters = [NSDictionary new];
    if (categoryId == kPiwigoVisitsCategoryId) {
        parameters = @{
                       @"recursive"             : @"true",
                       @"per_page"              : @(imagesPerPage),
                       @"page"                  : @(page),
                       @"order"                 : order,     // Percent-encoded should not be used here!
                       @"f_min_hit"             : @"1"
                     };
    } else if (categoryId == kPiwigoBestCategoryId) {
        parameters = @{
                       @"recursive"             : @"true",
                       @"per_page"              : @(imagesPerPage),
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
                       @"per_page"              : @(imagesPerPage),
                       @"page"                  : @(page),
                       @"order"                 : order,     // Percent-encoded should not be used here!
                       @"f_min_date_available"  : dateAvailableString
                       };
    } else {
        completion(nil, @[]);
    }
    
    // Cancel active Search request if any
    NSArray <NSURLSessionTask *> *searchTasks = [[Model sharedInstance].sessionManager tasks];
    for (NSURLSessionTask *task in searchTasks) {
        [task cancel];
    }
    
    // Cancel active image downloads if any
    NSArray <NSURLSessionTask *> *downloadTasks = [[Model sharedInstance].imagesSessionManager tasks];
    for (NSURLSessionTask *task in downloadTasks) {
        [task cancel];
    }
    
    // Send request
    return [self post:kPiwigoCategoriesGetImages
        URLParameters:nil
           parameters:parameters
       sessionManager:[Model sharedInstance].sessionManager
             progress:nil
              success:^(NSURLSessionTask *task, id responseObject) {
                  
          if([[responseObject objectForKey:@"stat"] isEqualToString:@"ok"]) {
              // Store number of images in cache
              NSInteger nberImages;
              if ((categoryId == kPiwigoVisitsCategoryId) ||
                  (categoryId == kPiwigoBestCategoryId)   ||
                  (categoryId == kPiwigoRecentCategoryId)) {
                  nberImages = [[[[responseObject objectForKey:@"result"] objectForKey:@"paging"] objectForKey:@"total_count"] integerValue];
              } else {
                  nberImages = [[[[responseObject objectForKey:@"result"] objectForKey:@"paging"] objectForKey:@"count"] integerValue];
              }
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
    NSInteger imagesPerPage = [ImagesCollection numberOfImagesPerPageForView:nil imagesPerRowInPortrait:[Model sharedInstance].thumbnailsPerRowInPortrait];
    
    // Compile parameters
    NSDictionary *parameters = @{@"tag_id"         : @(tagId),
                                 @"per_page"       : @(imagesPerPage),
                                 @"page"           : @(page),
                                 @"order"          : @"rank asc, id desc"
                                  };
    
    // Cancel active Search request if any
    NSArray <NSURLSessionTask *> *searchTasks = [[Model sharedInstance].sessionManager tasks];
    for (NSURLSessionTask *task in searchTasks) {
        [task cancel];
    }
    
    // Cancel active image downloads if any
    NSArray <NSURLSessionTask *> *downloadTasks = [[Model sharedInstance].imagesSessionManager tasks];
    for (NSURLSessionTask *task in downloadTasks) {
        [task cancel];
    }
    
    // Send request
    return [self post:kPiwigoTagsGetImages
        URLParameters:nil
           parameters:parameters
       sessionManager:[Model sharedInstance].sessionManager
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
    NSInteger imagesPerPage = [ImagesCollection numberOfImagesPerPageForView:nil imagesPerRowInPortrait:[Model sharedInstance].thumbnailsPerRowInPortrait];
    
    // Compile parameters
    NSDictionary *parameters = @{@"per_page"       : @(imagesPerPage),
                                 @"page"           : @(page),
                                 @"order"          : order
                                 };
    
    // Cancel active Search request if any
    NSArray <NSURLSessionTask *> *searchTasks = [[Model sharedInstance].sessionManager tasks];
    for (NSURLSessionTask *task in searchTasks) {
        [task cancel];
    }
    
    // Cancel active image downloads if any
    NSArray <NSURLSessionTask *> *downloadTasks = [[Model sharedInstance].imagesSessionManager tasks];
    for (NSURLSessionTask *task in downloadTasks) {
        [task cancel];
    }
    
    // Send request
    return [self post:kPiwigoUserFavoritesGetList
        URLParameters:nil
           parameters:parameters
       sessionManager:[Model sharedInstance].sessionManager
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
    {    // done. don't need anymore
        if(fail)
        {
            fail(nil, nil);
        }
        return nil;
    }
    
    NSURLSessionTask *task;
    if (categoryId == kPiwigoSearchCategoryId) {
        // Load search image data for query
        task = [ImageService getImagesForQuery:query
                                        onPage:onPage
                                      forOrder:sort
                                  OnCompletion:^(NSURLSessionTask *task, NSArray *searchedImages) {
                                      if (searchedImages)
                                      {
                                          PiwigoAlbumData *albumData = [[CategoriesData sharedInstance] getCategoryById:categoryId];
                                          [albumData addImages:searchedImages];
//                                          NSLog(@"loadImageChunkForLastChunkCount: added %ld images", (long)searchedImages.count);
                                          if (completion) {
                                              completion(task, searchedImages.count);
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
                                       OnCompletion:^(NSURLSessionTask *task, NSArray *searchedImages) {
                                      if (searchedImages)
                                      {
                                          PiwigoAlbumData *albumData = [[CategoriesData sharedInstance] getCategoryById:categoryId];
                                          [albumData addImages:searchedImages];
//                                          NSLog(@"loadImageChunkForLastChunkCount: added %ld images", (long)searchedImages.count);
                                          if (completion) {
                                              completion(task, searchedImages.count);
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
                                  OnCompletion:^(NSURLSessionTask *task, NSArray *searchedImages) {
                                      if (searchedImages)
                                      {
                                          PiwigoAlbumData *albumData = [[CategoriesData sharedInstance] getCategoryById:categoryId];
                                          [albumData addImages:searchedImages];
//                                          NSLog(@"loadImageChunkForLastChunkCount: added %ld images", (long)searchedImages.count);
                                          if (completion) {
                                              completion(task, searchedImages.count);
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
                                   OnCompletion:^(NSURLSessionTask *task, NSArray *searchedImages) {
                                        if (searchedImages)
                                        {
                                            PiwigoAlbumData *albumData = [[CategoriesData sharedInstance] getCategoryById:categoryId];
                                            [albumData addImages:searchedImages];
//                                            NSLog(@"loadImageChunkForLastChunkCount: added %ld images", (long)searchedImages.count);
                                            if (completion) {
                                                completion(task, searchedImages.count);
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
    else
    {
        // Load category image data
        task = [ImageService getImagesForAlbumId:categoryId
                                          onPage:onPage
                                        forOrder:sort
                                    OnCompletion:^(NSURLSessionTask *task, NSArray *albumImages) {
                                          if (albumImages)
                                          {
                                              PiwigoAlbumData *albumData = [[CategoriesData sharedInstance] getCategoryById:categoryId];
                                              [albumData addImages:albumImages];
//                                              NSLog(@"loadImageChunkForLastChunkCount: added %ld images", (long)albumImages.count);
                                              if (completion) {
                                                  completion(task, albumImages.count);
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

+(NSURLSessionTask*)getImageInfoById:(NSInteger)imageId
                        OnCompletion:(void (^)(NSURLSessionTask *task, PiwigoImageData *imageData))completion
                           onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
    // Compile parameters
    NSDictionary *parameters = @{
                                 @"image_id" : @(imageId)
                                 };
    
    // Send request
	return [self post:kPiwigoImagesGetInfo
		URLParameters:nil
           parameters:parameters
       sessionManager:[Model sharedInstance].sessionManager
             progress:nil
			  success:^(NSURLSessionTask *task, id responseObject) {
				  
          if([[responseObject objectForKey:@"stat"] isEqualToString:@"ok"])
          {
              PiwigoImageData *imageData = [ImageService parseBasicImageInfoJSON:[responseObject objectForKey:@"result"]];
              for(NSNumber *categoryId in imageData.categoryIds)
              {
                  [[[CategoriesData sharedInstance] getCategoryById:[categoryId integerValue]] updateImages:@[imageData]];
              }
              if(completion) {
                  completion(task, imageData);
              }
          }
          else
          {
              // Display Piwigo error
              NSError *error = [NetworkHandler getPiwigoErrorFromResponse:responseObject
                                    path:kPiwigoImagesGetInfo andURLparams:nil];
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
                  NSLog(@"=> getImageInfoById: %@ failed with error %ld:%@", @(imageId), (long)[error code], [error localizedDescription]);
#endif
				  if(fail) {
					  fail(task, error);
				  }
			  }];
}

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
    if (![[imageJson objectForKey:@"name"] isKindOfClass:[NSNull class]]) {
        imageData.imageTitle = [NetworkUtilities utf8mb4StringFrom:[imageJson objectForKey:@"name"]];
    } else {
        imageData.imageTitle = @"";
    }
    
    // Object "comment"
    if (![[imageJson objectForKey:@"comment"] isKindOfClass:[NSNull class]]) {
        imageData.comment = [NetworkUtilities utf8mb4StringFrom:[imageJson objectForKey:@"comment"]];
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
    if (![[imageJson objectForKey:@"file"] isKindOfClass:[NSNull class]]) {
        imageData.fileName = [NetworkUtilities utf8mb4StringFrom:[imageJson objectForKey:@"file"]];
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
    if (![dateAvailableString isKindOfClass:[NSNull class]]) {
        imageData.datePosted = [dateFormat dateFromString:dateAvailableString];
    } else {
        imageData.datePosted = [NSDate date];
    }
    
    // Object "date_creation"
    NSString *dateCreatedString = [imageJson objectForKey:@"date_creation"];
    if (![dateCreatedString isKindOfClass:[NSNull class]]) {
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
    imageData.fullResPath = [NetworkHandler encodedImageURL:[[imageJson objectForKey:@"element_url"] stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"]];
    
    // Objects "derivatives"
    // When $conf['original_url_protection'] = 'images' or 'all'; is enabled
    // the URLs returned by the Piwigo server contain &amp; instead of & (Piwigo v2.9.2)
	NSDictionary *imageSizes = [imageJson objectForKey:@"derivatives"];
    
    // Square image
    imageData.SquarePath = [NetworkHandler encodedImageURL:[[[imageSizes objectForKey:@"square"] objectForKey:@"url"] stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"]];
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
    imageData.ThumbPath = [NetworkHandler encodedImageURL:[[[imageSizes objectForKey:@"thumb"] objectForKey:@"url"] stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"]];
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
    imageData.MediumPath = [NetworkHandler encodedImageURL:[[[imageSizes objectForKey:@"medium"] objectForKey:@"url"] stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"]];
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
    imageData.XXSmallPath = [NetworkHandler encodedImageURL:[[[imageSizes objectForKey:@"2small"] objectForKey:@"url"] stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"]];
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
    imageData.XSmallPath = [NetworkHandler encodedImageURL:[[[imageSizes objectForKey:@"xsmall"] objectForKey:@"url"] stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"]];
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
    imageData.SmallPath = [NetworkHandler encodedImageURL:[[[imageSizes objectForKey:@"small"] objectForKey:@"url"] stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"]];
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
    imageData.LargePath = [NetworkHandler encodedImageURL:[[[imageSizes objectForKey:@"large"] objectForKey:@"url"] stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"]];
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
    imageData.XLargePath = [NetworkHandler encodedImageURL:[[[imageSizes objectForKey:@"xlarge"] objectForKey:@"url"] stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"]];
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
    imageData.XXLargePath = [NetworkHandler encodedImageURL:[[[imageSizes objectForKey:@"xxlarge"] objectForKey:@"url"] stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"]];
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
    if (![[imageJson objectForKey:@"author"] isKindOfClass:[NSNull class]]) {
        imageData.author = [NetworkUtilities utf8mb4StringFrom:[imageJson objectForKey:@"author"]];
    } else {
        imageData.author = @"NSNotFound";
    }

    // Object "level"
    if ([imageJson objectForKey:@"level"] &&
        ![[imageJson objectForKey:@"level"] isKindOfClass:[NSNull class]]) {
        imageData.privacyLevel = (kPiwigoPrivacy)[[imageJson objectForKey:@"level"] integerValue];
    } else {
        imageData.privacyLevel = kPiwigoPrivacyUnknown;
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
                tagData.tagName = [NetworkUtilities utf8mb4StringFrom:[tag objectForKey:@"name"]];
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
    if (![[imageJson objectForKey:@"md5sum"] isKindOfClass:[NSNull class]]) {
        imageData.MD5checksum = [NetworkUtilities utf8mb4StringFrom:[imageJson objectForKey:@"md5sum"]];
    } else {
        imageData.MD5checksum = @"";
    }

    return imageData;
}


#pragma mark - Delete images

+(NSURLSessionTask*)deleteImage:(PiwigoImageData*)image
               ListOnCompletion:(void (^)(NSURLSessionTask *task))completion
                      onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
    return [self post:kPiwigoImageDelete
		URLParameters:nil
		   parameters:@{
                        @"image_id" : [NSString stringWithFormat:@"%ld", (long)image.imageId],
                        @"pwg_token" : [Model sharedInstance].pwgToken
                        }
       sessionManager:[Model sharedInstance].sessionManager
             progress:nil
			  success:^(NSURLSessionTask *task, id responseObject)
    {
        if([[responseObject objectForKey:@"stat"] isEqualToString:@"ok"]) {
            // Remove image from cache and update UI
            [[CategoriesData sharedInstance] removeImage:image];
            if(completion) {
                completion(task);
            }
        } else {
            if(fail) {
                NSError *error = [NetworkHandler getPiwigoErrorFromResponse:responseObject
                                 path:kPiwigoImageDelete andURLparams:nil];
                fail(task, error);
            }
        }
    }
              failure:^(NSURLSessionTask *task, NSError *error)
    {
#if defined(DEBUG)
        NSLog(@"=> deleteImage — Fail: %@", [error description]);
#endif
        if(fail) {
            fail(task, error);
        }
    }];
}

+(NSURLSessionTask*)deleteImages:(NSArray *)images
                ListOnCompletion:(void (^)(NSURLSessionTask *task))completion
                       onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
    // Create string containing pipe separated list of image ids
    NSMutableString *listOfImageIds = [NSMutableString new];
    for (PiwigoImageData *image in images) {
        [listOfImageIds appendFormat:(NSString *)@"%ld", (long)image.imageId];
        [listOfImageIds appendString:@"|"];
    }
    [listOfImageIds deleteCharactersInRange:NSMakeRange((listOfImageIds.length -1), 1)];
    
    // Send request to server
    return [self post:kPiwigoImageDelete
        URLParameters:nil
           parameters:@{
                        @"image_id" : listOfImageIds,
                        @"pwg_token" : [Model sharedInstance].pwgToken
                        }
       sessionManager:[Model sharedInstance].sessionManager
             progress:nil
              success:^(NSURLSessionTask *task, id responseObject)
    {
        if([[responseObject objectForKey:@"stat"] isEqualToString:@"ok"]) {
            for (PiwigoImageData *image in images) {
              // Remove image from cache and update UI
              [[CategoriesData sharedInstance] removeImage:image];
            }
            if(completion) {
                completion(task);
            }
        } else {
            if(fail) {
                NSError *error = [NetworkHandler getPiwigoErrorFromResponse:responseObject
                                     path:kPiwigoImageDelete andURLparams:nil];
                fail(task, error);
            }
        }
    }
              failure:^(NSURLSessionTask *task, NSError *error)
    {
#if defined(DEBUG)
        NSLog(@"=> deleteImages — Fail: %@", [error description]);
#endif
        if(fail) {
            fail(task, error);
        }
    }];
}


#pragma mark - Set image data

+(NSURLSessionTask*)setImageProperties:(PiwigoImageData *)imageData
                            onProgress:(void (^)(NSProgress *))progress
                          OnCompletion:(void (^)(NSURLSessionTask *task, id response))completion
                             onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
    // Prepare dictionary of parameters
    NSMutableDictionary *imageInformation = [NSMutableDictionary new];
    
    // File name
    NSString *fileName = imageData.fileName;
    if ([fileName isEqualToString:@"NSNotFound"] || (fileName == nil)) {
        fileName = @"Unknown.jpg";
    }
    [imageInformation setObject:fileName
                         forKey:kPiwigoImagesUploadParamFileName];
    
    // Date created
    NSString *creationDate = @"";
    if (imageData.dateCreated != nil) {
        NSDateFormatter *dateFormat = [NSDateFormatter new];
        [dateFormat setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
        creationDate = [dateFormat stringFromDate:imageData.dateCreated];
    }
    [imageInformation setObject:creationDate
                         forKey:kPiwigoImagesUploadParamCreationDate];
    
    // Title
    NSString *title = @"";
    if ((imageData.imageTitle != nil) && (imageData.imageTitle.length > 0)) {
        title = imageData.imageTitle;
    }
    [imageInformation setObject:title
                         forKey:kPiwigoImagesUploadParamTitle];

    // Author
    NSString *author = imageData.author;
    if ([author isEqualToString:@"NSNotFound"] || (author == nil)) {
        // We should never set NSNotFound in the database
        author = @"";
    }
    [imageInformation setObject:author
                         forKey:kPiwigoImagesUploadParamAuthor];

    // Description
    NSString *description = @"";
    if ((imageData.comment != nil) && (imageData.comment.length > 0)) {
        description = imageData.comment;
    }
    [imageInformation setObject:description
                         forKey:kPiwigoImagesUploadParamDescription];

    // Tags
    NSMutableString *tagIds = [NSMutableString new];
    for(PiwigoTagData *tagData in imageData.tags)
    {
        [tagIds appendFormat:@"%ld,", (long)tagData.tagId];
    }
    NSInteger nberChars = tagIds.length;
    if (nberChars > 0) {
        [tagIds deleteCharactersInRange:NSMakeRange(nberChars - 1, 1)];
    }
    [imageInformation setObject:tagIds
                         forKey:kPiwigoImagesUploadParamTags];

    // Privacy level
    NSString *privacyLevel = [NSString stringWithFormat:@"%@", @(imageData.privacyLevel)];
    [imageInformation setObject:privacyLevel
                         forKey:kPiwigoImagesUploadParamPrivacy];
    
    // Call pwg.images.setInfo to set image parameters
    return [self setImageInfoForImageWithId:imageData.imageId
                                information:imageInformation
                             sessionManager:[Model sharedInstance].sessionManager
                                 onProgress:progress
                               OnCompletion:^(NSURLSessionTask *task, NSDictionary *response) {
                      
                if([[response objectForKey:@"stat"] isEqualToString:@"ok"])
                {
                    // Update cache
                    for (NSNumber *cat in imageData.categoryIds) {
                        NSInteger catId = [cat integerValue];
                        [[[CategoriesData sharedInstance] getCategoryById:catId] updateImageAfterEdit:imageData];
                    }

                    // Notify album/image view of modification
                    [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationCategoryDataUpdated object:nil];
                }
                if(completion)
                {
                    completion(task, response);
                }
                               }
                                onFailure:fail];
}

+(NSURLSessionTask*)setImageInfoForImageWithId:(NSInteger)imageId
                                   information:(NSDictionary*)imageInfo
                                sessionManager:(AFHTTPSessionManager *)sessionManager
                                    onProgress:(void (^)(NSProgress *))progress
                                  OnCompletion:(void (^)(NSURLSessionTask *task, id response))completion
                                     onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
    // Author
    NSString *author = [imageInfo objectForKey:kPiwigoImagesUploadParamAuthor];
    if ([author isEqualToString:@"NSNotFound"] || (author == nil)) {
        // We should never set NSNotFound in the database
        author = @"";
    }

    return [self post:kPiwigoImageSetInfo
         URLParameters:nil
            parameters:@{
                         @"image_id" : @(imageId),
                         @"file" : [imageInfo objectForKey:kPiwigoImagesUploadParamFileName],
                         @"name" : [imageInfo objectForKey:kPiwigoImagesUploadParamTitle],
                         @"author" : author,
                         @"date_creation" : [imageInfo objectForKey:kPiwigoImagesUploadParamCreationDate],
                         @"level" : [imageInfo objectForKey:kPiwigoImagesUploadParamPrivacy],
                         @"comment" : [imageInfo objectForKey:kPiwigoImagesUploadParamDescription],
                         @"single_value_mode" : @"replace",
                         @"tag_ids" : [imageInfo objectForKey:kPiwigoImagesUploadParamTags],
                         @"multiple_value_mode" : @"replace"
                         }
       sessionManager:sessionManager
             progress:progress
              success:^(NSURLSessionTask *task, id responseObject) {
                        if(completion) {
                            completion(task, responseObject);
                        }
            } failure:^(NSURLSessionTask *task, NSError *error) {
#if defined(DEBUG)
                  NSLog(@"=> setImageInfoForImageWithId — Fail: %@", [error description]);
#endif
                  if(fail) {
                      fail(task, error);
                  }
              }];
}

+(NSURLSessionTask*)setImageFileForImageWithId:(NSInteger)imageId
                                  withFileName:(NSString*)fileName
                                    onProgress:(void (^)(NSProgress *))progress
                                  OnCompletion:(void (^)(NSURLSessionTask *task, id response))completion
                                     onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
    NSURLSessionTask *request = [self post:kPiwigoImageSetInfo
         URLParameters:nil
            parameters:@{
                         @"image_id" : @(imageId),
                         @"file" : fileName,
                         @"single_value_mode" : @"replace"
                         }
        sessionManager:[Model sharedInstance].sessionManager
              progress:progress
               success:^(NSURLSessionTask *task, id responseObject) {
                        if(completion) {
                            if([[responseObject objectForKey:@"stat"] isEqualToString:@"ok"])
                            {
                                completion(task, responseObject);
                            }
                            else
                            {
                                // Display Piwigo error
                                NSError *error = [NetworkHandler getPiwigoErrorFromResponse:responseObject
                                                      path:kPiwigoImageSetInfo andURLparams:nil];
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
#if defined(DEBUG)
                  NSLog(@"=> setImageFileForImageWithId — Fail: %@", [error description]);
#endif
                  if(fail) {
                      fail(task, error);
                  }
              }];
    
    return request;
}

+(NSURLSessionTask*)setCategoriesForImageWithId:(NSInteger)imageId
                                 withCategories:(NSArray *)categoryIds
                                     onProgress:(void (^)(NSProgress *))progress
                                   OnCompletion:(void (^)(NSURLSessionTask *task))completion
                                      onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
    NSString *newImageCategories = [categoryIds componentsJoinedByString:@";"];
    NSURLSessionTask *request = [self post:kPiwigoImageSetInfo
             URLParameters:nil
                parameters:@{
                             @"image_id" : [NSString stringWithFormat:@"%ld", (long)imageId],
                             @"categories" : newImageCategories,
                             @"multiple_value_mode" : @"replace"
                             }
            sessionManager:[Model sharedInstance].sessionManager
                  progress:progress
                   success:^(NSURLSessionTask *task, id responseObject)
    {
        if(![[responseObject objectForKey:@"stat"] isEqualToString:@"ok"]) {
            if(completion) {
                completion(task);
            }
        } else {
            NSError *error = [NetworkHandler getPiwigoErrorFromResponse:responseObject
                                   path:kPiwigoImageDelete andURLparams:nil];
            if(fail) {
                fail(task, error);
            }
        }
    }
                    failure:^(NSURLSessionTask *task, NSError *error)
    {
#if defined(DEBUG)
         NSLog(@"=> setCategoriesForImage — Fail: %@", [error description]);
#endif
         if(fail) {
             fail(task, error);
         }
    }];

    return request;
}

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
            sessionManager:[Model sharedInstance].sessionManager
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
            sessionManager:[Model sharedInstance].sessionManager
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
