//
//  SessionService.m
//  piwigo
//
//  Created by Spencer Baker on 1/20/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "ImagesCollection.h"
#import "Model.h"
#import "PiwigoImageData.h"
#import "SessionService.h"

@implementation SessionService

// Get Piwigo server methods
// and determine if the Community extension is installed and active
+(NSURLSessionTask*)getMethodsListOnCompletion:(void (^)(NSDictionary *methodsList))completion
                                     onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
    return [self post:kReflectionGetMethodList
        URLParameters:nil
           parameters:nil
             progress:^(NSProgress * progress) {
                 if ([Model sharedInstance].userCancelledCommunication) {
                     [progress cancel];
                 }
             }
              success:^(NSURLSessionTask *task, id responseObject) {
                  
                  if(completion) {
                      
                      // Did the server answer the request? (it should have)
                      if([[responseObject objectForKey:@"stat"] isEqualToString:@"ok"])
                      {
                          // Loop over the methods
                          id methodsList = [[responseObject objectForKey:@"result"] objectForKey:@"methods"];
                          for (NSString *method in methodsList) {
                              
                              // Check if the Community extension is installed and active (> 2.9a)
                              if([method isEqualToString:@"community.session.getStatus"]) {
                                  [Model sharedInstance].usesCommunityPluginV29 = YES;
                              }
                          }
                          completion([[responseObject objectForKey:@"result"] objectForKey:@"methods"]);
                      }
                      else  // Strange…
                      {
                          completion(nil);
                      }
                  }
              } failure:^(NSURLSessionTask *task, NSError *error) {
                  
                  if(fail) {
                      fail(task, error);
                  }
              }];
}

+(NSURLSessionTask*)performLoginWithUser:(NSString*)user
                             andPassword:(NSString*)password
                            onCompletion:(void (^)(BOOL result, id response))completion
                               onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
    [[Model sharedInstance] saveToDisk];
    
    return [self post:kPiwigoSessionLogin
        URLParameters:nil
           parameters:@{@"username" : user,
                        @"password" : password}
             progress:^(NSProgress * progress) {
                 if ([Model sharedInstance].userCancelledCommunication) {
                     [progress cancel];
                 }
             }
              success:^(NSURLSessionTask *task, id responseObject) {
                  
                  if(completion) {
                      if([[responseObject objectForKey:@"stat"] isEqualToString:@"ok"] && [[responseObject objectForKey:@"result"] boolValue])
                      {
                          [Model sharedInstance].username = user;
                          [Model sharedInstance].hadOpenedSession = YES;
                          [[Model sharedInstance] saveToDisk];
                          completion(YES, [responseObject objectForKey:@"result"]);
                      }
                      else
                      {
                          // May be this server only uses HTTP authentication
                          if ([Model sharedInstance].performedHTTPauthentication) {
                              [Model sharedInstance].username = user;
                              [Model sharedInstance].hadOpenedSession = YES;
                              [[Model sharedInstance] saveToDisk];
                             completion(YES, nil);
                          } else {
                              [Model sharedInstance].hadOpenedSession = NO;
                              completion(NO, nil);
                          }
                      }
                  }
              }
              failure:^(NSURLSessionTask *task, NSError *error) {
                  
                  if(fail)
                  {
                      fail(task, error);
                  }
              }];
}

+(NSURLSessionTask*)getPiwigoStatusAtLogin:(BOOL)isLogginIn
                              OnCompletion:(void (^)(NSDictionary *responseObject))completion
                                 onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
    return [self post:kPiwigoSessionGetStatus
        URLParameters:nil
           parameters:nil
             progress:^(NSProgress * progress) {
                 if ([Model sharedInstance].userCancelledCommunication) {
                     [progress cancel];
                 }
             }
              success:^(NSURLSessionTask *task, id responseObject) {
                  
                  if(completion) {
                      if([[responseObject objectForKey:@"stat"] isEqualToString:@"ok"])
                      {
                          if (isLogginIn) {
                              [Model sharedInstance].pwgToken = [[responseObject objectForKey:@"result"] objectForKey:@"pwg_token"];
                              [Model sharedInstance].language = [[responseObject objectForKey:@"result"] objectForKey:@"language"];
                              [Model sharedInstance].version = [[responseObject objectForKey:@"result"] objectForKey:@"version"];
                              NSString *uploadFileTypes = [[responseObject objectForKey:@"result"] objectForKey:@"upload_file_types"];

                              // Images and videos can be uploaded if their file types are found.
                              // The iPhone creates mov files that will be uploaded in mp4 format.
                              [Model sharedInstance].uploadFileTypes = uploadFileTypes;
                              
                              // User rights are determined by Community extension (if installed)
                              if(![Model sharedInstance].usesCommunityPluginV29) {
                                  NSString *userStatus = [[responseObject objectForKey:@"result" ] objectForKey:@"status"];
                                  [Model sharedInstance].hasAdminRights = ([userStatus isEqualToString:@"admin"] || [userStatus isEqualToString:@"webmaster"]);
                              }
                              
                              // Collect the list of available sizes
                              // Let's start with default values
                              [Model sharedInstance].hasSquareSizeImages  = YES;
                              [Model sharedInstance].hasThumbSizeImages   = YES;
                              [Model sharedInstance].hasXXSmallSizeImages = NO;
                              [Model sharedInstance].hasXSmallSizeImages  = NO;
                              [Model sharedInstance].hasSmallSizeImages   = NO;
                              [Model sharedInstance].hasMediumSizeImages  = YES;
                              [Model sharedInstance].hasLargeSizeImages   = NO;
                              [Model sharedInstance].hasXLargeSizeImages  = NO;
                              [Model sharedInstance].hasXXLargeSizeImages = NO;
                              
                              // Update list of available sizes
                              id availableSizesList = [[responseObject objectForKey:@"result"] objectForKey:@"available_sizes"];
                              for (NSString *size in availableSizesList) {
                                  if ([size isEqualToString:@"square"]) {
                                      [Model sharedInstance].hasSquareSizeImages = YES;
                                  } else if ([size isEqualToString:@"thumb"]) {
                                      [Model sharedInstance].hasThumbSizeImages = YES;
                                  } else if ([size isEqualToString:@"2small"]) {
                                      [Model sharedInstance].hasXXSmallSizeImages = YES;
                                  } else if ([size isEqualToString:@"xsmall"]) {
                                      [Model sharedInstance].hasXSmallSizeImages = YES;
                                  } else if ([size isEqualToString:@"small"]) {
                                      [Model sharedInstance].hasSmallSizeImages = YES;
                                  } else if ([size isEqualToString:@"medium"]) {
                                      [Model sharedInstance].hasMediumSizeImages = YES;
                                  } else if ([size isEqualToString:@"large"]) {
                                      [Model sharedInstance].hasLargeSizeImages = YES;
                                  } else if ([size isEqualToString:@"xlarge"]) {
                                      [Model sharedInstance].hasXLargeSizeImages = YES;
                                  } else if ([size isEqualToString:@"xxlarge"]) {
                                      [Model sharedInstance].hasXXLargeSizeImages = YES;
                                  }
                              }
                              
                              // Check that the actual default thumbnail size is still available
                              // and select Thumb size in case of unavailability
                              switch ([Model sharedInstance].defaultThumbnailSize) {
                                  case kPiwigoImageSizeSquare:
                                      // Always available
                                      break;
                                  case kPiwigoImageSizeXXSmall:
                                      if (![Model sharedInstance].hasXXSmallSizeImages) {
                                          [Model sharedInstance].defaultThumbnailSize = kPiwigoImageSizeThumb;
                                      }
                                      break;
                                  case kPiwigoImageSizeXSmall:
                                      if (![Model sharedInstance].hasXSmallSizeImages) {
                                          [Model sharedInstance].defaultThumbnailSize = kPiwigoImageSizeThumb;
                                      }
                                      break;
                                  case kPiwigoImageSizeSmall:
                                      if (![Model sharedInstance].hasSmallSizeImages) {
                                          [Model sharedInstance].defaultThumbnailSize = kPiwigoImageSizeThumb;
                                      }
                                      break;
                                  case kPiwigoImageSizeLarge:
                                      if (![Model sharedInstance].hasLargeSizeImages) {
                                          [Model sharedInstance].defaultThumbnailSize = kPiwigoImageSizeThumb;
                                      }
                                      break;
                                  case kPiwigoImageSizeXLarge:
                                      if (![Model sharedInstance].hasXLargeSizeImages) {
                                          [Model sharedInstance].defaultThumbnailSize = kPiwigoImageSizeThumb;
                                      }
                                      break;
                                  case kPiwigoImageSizeXXLarge:
                                      if (![Model sharedInstance].hasXXLargeSizeImages) {
                                          [Model sharedInstance].defaultThumbnailSize = kPiwigoImageSizeThumb;
                                      }
                                      break;
                                  case kPiwigoImageSizeThumb:
                                  case kPiwigoImageSizeFullRes:
                                  default:
                                      [Model sharedInstance].defaultThumbnailSize = kPiwigoImageSizeThumb;
                                      break;
                              }

                              // Calculate number of thumbnails per row for that selection
                              NSInteger minNberOfImages = [ImagesCollection numberOfImagesPerRowForViewInPortrait:nil withMaxWidth:[PiwigoImageData widthForImageSizeType:(kPiwigoImageSize)[Model sharedInstance].defaultThumbnailSize]];

                              // Make sure that default number fits inside selected range
                              [Model sharedInstance].thumbnailsPerRowInPortrait = MAX([Model sharedInstance].thumbnailsPerRowInPortrait, minNberOfImages);
                              [Model sharedInstance].thumbnailsPerRowInPortrait = MIN([Model sharedInstance].thumbnailsPerRowInPortrait, 2*minNberOfImages);

                              // Check that the actual default image preview size is still available
                              // and select the next available size in case of unavailability
                              switch ([Model sharedInstance].defaultImagePreviewSize) {
                                  case kPiwigoImageSizeXXSmall:
                                      if (![Model sharedInstance].hasXXSmallSizeImages) {
                                          // Look for next available larger size
                                          if ([Model sharedInstance].hasXSmallSizeImages) {
                                              [Model sharedInstance].defaultImagePreviewSize = kPiwigoImageSizeXSmall;
                                          } else if ([Model sharedInstance].hasSmallSizeImages) {
                                              [Model sharedInstance].defaultImagePreviewSize = kPiwigoImageSizeSmall;
                                          } else {
                                              [Model sharedInstance].defaultImagePreviewSize = kPiwigoImageSizeMedium;
                                          }
                                      }
                                      break;
                                  case kPiwigoImageSizeXSmall:
                                      if (![Model sharedInstance].hasXSmallSizeImages) {
                                          // Look for next available larger size
                                          if ([Model sharedInstance].hasSmallSizeImages) {
                                              [Model sharedInstance].defaultImagePreviewSize = kPiwigoImageSizeSmall;
                                          } else {
                                              [Model sharedInstance].defaultImagePreviewSize = kPiwigoImageSizeMedium;
                                          }
                                      }
                                      break;
                                  case kPiwigoImageSizeSmall:
                                      if (![Model sharedInstance].hasSmallSizeImages) {
                                          [Model sharedInstance].defaultImagePreviewSize = kPiwigoImageSizeMedium;
                                      }
                                      break;
                                  case kPiwigoImageSizeLarge:
                                      if (![Model sharedInstance].hasLargeSizeImages) {
                                          // Look for next available larger size
                                          if ([Model sharedInstance].hasXLargeSizeImages) {
                                              [Model sharedInstance].defaultImagePreviewSize = kPiwigoImageSizeXLarge;
                                          } else if ([Model sharedInstance].hasXXLargeSizeImages) {
                                              [Model sharedInstance].defaultImagePreviewSize = kPiwigoImageSizeXXLarge;
                                          } else {
                                              [Model sharedInstance].defaultImagePreviewSize = kPiwigoImageSizeFullRes;
                                          }
                                      }
                                      break;
                                  case kPiwigoImageSizeXLarge:
                                      if (![Model sharedInstance].hasXLargeSizeImages) {
                                          // Look for next available larger size
                                          if ([Model sharedInstance].hasXXLargeSizeImages) {
                                              [Model sharedInstance].defaultImagePreviewSize = kPiwigoImageSizeXXLarge;
                                          } else {
                                              [Model sharedInstance].defaultImagePreviewSize = kPiwigoImageSizeFullRes;
                                          }
                                      }
                                      break;
                                  case kPiwigoImageSizeXXLarge:
                                      if (![Model sharedInstance].hasXXLargeSizeImages) {
                                          [Model sharedInstance].defaultImagePreviewSize = kPiwigoImageSizeFullRes;
                                      }
                                      break;
                                  case kPiwigoImageSizeFullRes:
                                  default:
                                      [Model sharedInstance].defaultImagePreviewSize = kPiwigoImageSizeFullRes;
                                      break;
                              }
                          }
                          [[Model sharedInstance] saveToDisk];

                          completion([responseObject objectForKey:@"result"]);
                      } else {
                          completion(nil);
                      }
                  }
              } failure:^(NSURLSessionTask *task, NSError *error) {
                  
                  if(fail) {
                      fail(task, error);
                  }
              }];
}

+(NSURLSessionTask*)getCommunityStatusOnCompletion:(void (^)(NSDictionary *responseObject))completion
                                         onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
    return [self post:kCommunitySessionGetStatus
        URLParameters:nil
           parameters:nil
             progress:^(NSProgress * progress) {
                 if ([Model sharedInstance].userCancelledCommunication) {
                     [progress cancel];
                 }
             }
              success:^(NSURLSessionTask *task, id responseObject) {
                  
                  if(completion) {
                      if([[responseObject objectForKey:@"stat"] isEqualToString:@"ok"])
                      {
                          NSString *userStatus = [[responseObject objectForKey:@"result" ] objectForKey:@"real_user_status"];
                          [Model sharedInstance].hasAdminRights = ([userStatus isEqualToString:@"admin"] || [userStatus isEqualToString:@"webmaster"]);
                          
                          completion([responseObject objectForKey:@"result"]);
                      }
                      else
                      {
                          completion(nil);
                      }
                  }
              } failure:^(NSURLSessionTask *task, NSError *error) {
                  
                  if(fail) {
                      fail(task, error);
                  }
              }];
}

+(NSURLSessionTask*)sessionLogoutOnCompletion:(void (^)(NSURLSessionTask *task, BOOL sucessfulLogout))completion
                                    onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
	return [self post:kPiwigoSessionLogout
		URLParameters:nil
           parameters:nil
             progress:nil
			  success:^(NSURLSessionTask *task, id responseObject) {
				  
				  if(completion) {
					  if([[responseObject objectForKey:@"stat"] isEqualToString:@"ok"])
					  {
						  completion(task, [[responseObject objectForKey:@"result" ] boolValue]);
					  }
					  else
					  {
						  completion(task, NO);
					  }
				  }
			  } failure:^(NSURLSessionTask *task, NSError *error) {
				  
				  if(fail) {
                      [SessionService showConnectionError:error];
					  fail(task, error);
				  }
			  }];
}

@end
