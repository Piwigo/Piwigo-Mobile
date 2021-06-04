//
//  SessionService.m
//  piwigo
//
//  Created by Spencer Baker on 1/20/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "AppDelegate.h"
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
    // API reflection.getMethodList returns:
    //      methods

    return [self post:kReflectionGetMethodList
        URLParameters:nil
           parameters:nil
       sessionManager:NetworkVarsObjc.shared.sessionManager
             progress:^(NSProgress * progress) {
                 if (NetworkVarsObjc.shared.userCancelledCommunication) {
                     [progress cancel];
                 }
             }
              success:^(NSURLSessionTask *task, id responseObject) {
                  
                  if(completion) {
                      
                      // Initialise flags
                      NetworkVarsObjc.shared.usesCommunityPluginV29 = NO;
                      NetworkVarsObjc.shared.usesUploadAsync = NO;
                      
                      // Did the server answer the request? (it should have)
                      if([[responseObject objectForKey:@"stat"] isEqualToString:@"ok"])
                      {
                          // Loop over the methods
                          id methodsList = [[responseObject objectForKey:@"result"] objectForKey:@"methods"];
                          for (NSString *method in methodsList) {
                              // Check if the Community extension is installed and active (> 2.9a)
                              if([method isEqualToString:@"community.session.getStatus"]) {
                                  NetworkVarsObjc.shared.usesCommunityPluginV29 = YES;
                              }
                              // Check if the pwg.images.uploadAsync method is available
                              if ([method isEqualToString:@"pwg.images.uploadAsync"]) {
                                  NetworkVarsObjc.shared.usesUploadAsync = YES;
                              }
                          }
                          completion([[responseObject objectForKey:@"result"] objectForKey:@"methods"]);
                      }
                      else  // Strange…
                      {
                          NSError *error = [NetworkHandler getPiwigoErrorFromResponse:responseObject
                                                 path:kPiwigoSessionLogin andURLparams:nil];
                          fail(task, error);
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
    // API pwg.session.login returns:
    //      result = 1 if logged successfully
    return [self post:kPiwigoSessionLogin
        URLParameters:nil
           parameters:@{@"username" : user,
                        @"password" : password}
       sessionManager:NetworkVarsObjc.shared.sessionManager
             progress:^(NSProgress * progress) {
                 if (NetworkVarsObjc.shared.userCancelledCommunication) {
                     [progress cancel];
                 }
             }
              success:^(NSURLSessionTask *task, id responseObject) {
                  
                  if([[responseObject objectForKey:@"stat"] isEqualToString:@"ok"] &&
                     [[responseObject objectForKey:@"result"] boolValue])
                  {
                      // Login successful
                      NetworkVarsObjc.shared.username = user;
                      NetworkVarsObjc.shared.hadOpenedSession = YES;
                      if (completion) {
                          completion(YES, [responseObject objectForKey:@"result"]);
                      }
                  }
                  else
                  {
                      // Login failed
                      NetworkVarsObjc.shared.hadOpenedSession = NO;
                      NSError *error = [NetworkHandler getPiwigoErrorFromResponse:responseObject
                                             path:kPiwigoSessionLogin andURLparams:nil];
                      if (completion) {
                          completion(NO, error);
                      }
                  }
              }
              failure:^(NSURLSessionTask *task, NSError *error) {
                  
                  if(fail)
                  {
                      NetworkVarsObjc.shared.hadOpenedSession = NO;
                      fail(task, error);
                  }
              }];
}

+(NSURLSessionTask*)getPiwigoStatusAtLogin:(BOOL)isLogginIn
                              OnCompletion:(void (^)(NSDictionary *responseObject))completion
                                 onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
    // API pwg.session.getStatus returns:
    //      username, status, pwg_token
    //      version, language, charset, theme
    //      available_sizes, upload_file_types, upload_form_chunk_size
    //      current_datetime

    return [self post:kPiwigoSessionGetStatus
        URLParameters:nil
           parameters:nil
       sessionManager:NetworkVarsObjc.shared.sessionManager
             progress:^(NSProgress * progress) {
                 if (NetworkVarsObjc.shared.userCancelledCommunication) {
                     [progress cancel];
                 }
             }
              success:^(NSURLSessionTask *task, id responseObject) {
                  
                  if([[responseObject objectForKey:@"stat"] isEqualToString:@"ok"])
                  {
                      NSDictionary *result = [responseObject objectForKey:@"result"];
                      // Retrieve a potentially new token (required since the use of uploadAsync)
                      NetworkVarsObjc.shared.pwgToken = [result objectForKey:@"pwg_token"];

                      if (isLogginIn) {
                          NetworkVarsObjc.shared.language = [result objectForKey:@"language"];
                          
                          // Piwigo server version should be of format 1.2.3
                          NSMutableString *versionStr = [result objectForKey:@"version"];
                          NSArray<NSString *> *components = [versionStr componentsSeparatedByString:@"."];
                          switch (components.count) {
                              case 1:
                                  // Version of type 1
                                  [versionStr appendString:@".0.0"];
                                  break;

                              case 2:
                                  // Version of type 1.2
                                  [versionStr appendString:@".0"];
                                  break;

                              default:
                                  break;
                          }
                          NetworkVarsObjc.shared.version = [versionStr copy];

                          // Community users cannot upload with uploadAsync with Piwigo 11.0.0 and above
                          if (NetworkVarsObjc.shared.usesCommunityPluginV29 &&
                              !NetworkVarsObjc.shared.hasAdminRights &&
                              [@"11.0.0" compare:versionStr options:NSNumericSearch] != NSOrderedDescending) {
                              NetworkVarsObjc.shared.usesUploadAsync = NO;
                          }
                          NSLog(@"   version: %@, usesUploadAsync: %@", NetworkVarsObjc.shared.version,
                                NetworkVarsObjc.shared.usesUploadAsync ? @"YES" : @"NO");

                          NSString *charset = [[result objectForKey:@"charset"] uppercaseString];
                          if ([charset isEqualToString:@"UTF-8"]) {
                              NetworkVarsObjc.shared.stringEncoding = NSUTF8StringEncoding;
                          } else if ([charset isEqualToString:@"UTF-16"]) {
                              NetworkVarsObjc.shared.stringEncoding = NSUTF16StringEncoding;
                          } else if ([charset isEqualToString:@"ISO-8859-1"]) {
                              NetworkVarsObjc.shared.stringEncoding = NSWindowsCP1252StringEncoding;
                          } else if ([charset isEqualToString:@"US-ASCII"]) {
                              NetworkVarsObjc.shared.stringEncoding = NSASCIIStringEncoding;
                          } else if ([charset isEqualToString:@"X-EUC"]) {
                              NetworkVarsObjc.shared.stringEncoding = NSJapaneseEUCStringEncoding;
                          } else if ([charset isEqualToString:@"ISO-8859-3"]) {
                              NetworkVarsObjc.shared.stringEncoding = NSISOLatin1StringEncoding;
                          } else if ([charset isEqualToString:@"ISO-8859-3"]) {
                              NetworkVarsObjc.shared.stringEncoding = NSISOLatin1StringEncoding;
                          } else if ([charset isEqualToString:@"SHIFT-JIS"]) {
                              NetworkVarsObjc.shared.stringEncoding = NSShiftJISStringEncoding;
                          } else if ([charset isEqualToString:@"CP870"]) {
                              NetworkVarsObjc.shared.stringEncoding = NSISOLatin2StringEncoding;
                          } else if ([charset isEqualToString:@"UNICODE"]) {
                              NetworkVarsObjc.shared.stringEncoding = NSUnicodeStringEncoding;
                          } else if ([charset isEqualToString:@"WINDOWS-1251"]) {
                              NetworkVarsObjc.shared.stringEncoding = NSWindowsCP1251StringEncoding;
                          } else if ([charset isEqualToString:@"WINDOWS-1252"]) {
                              NetworkVarsObjc.shared.stringEncoding = NSWindowsCP1252StringEncoding;
                          } else if ([charset isEqualToString:@"WINDOWS-1253"]) {
                              NetworkVarsObjc.shared.stringEncoding = NSWindowsCP1253StringEncoding;
                          } else if ([charset isEqualToString:@"WINDOWS-1254"]) {
                              NetworkVarsObjc.shared.stringEncoding = NSWindowsCP1254StringEncoding;
                          } else if ([charset isEqualToString:@"WINDOWS-1250"]) {
                              NetworkVarsObjc.shared.stringEncoding = NSWindowsCP1250StringEncoding;
                          } else if ([charset isEqualToString:@"ISO-2022-JP"]) {
                              NetworkVarsObjc.shared.stringEncoding = NSISO2022JPStringEncoding;
                          } else if ([charset isEqualToString:@"ISO-2022-JP"]) {
                              NetworkVarsObjc.shared.stringEncoding = NSISO2022JPStringEncoding;
                          } else if ([charset isEqualToString:@"MACINTOSH"]) {
                              NetworkVarsObjc.shared.stringEncoding = NSMacOSRomanStringEncoding;
                          } else if ([charset isEqualToString:@"UNICODEFFFE"]) {
                              NetworkVarsObjc.shared.stringEncoding = NSUTF16BigEndianStringEncoding;
                          } else if ([charset isEqualToString:@"UTF-32"]) {
                              NetworkVarsObjc.shared.stringEncoding = NSUTF32StringEncoding;
                          } else {
                              // UTF-8 string encoding by default
                              NetworkVarsObjc.shared.stringEncoding = NSUTF8StringEncoding;
                          }
                          
                          // Upload chunk size is null if not provided by server
                          NSInteger uploadChunkSize = [[result objectForKey:@"upload_form_chunk_size"] integerValue];
                          if (uploadChunkSize != 0) {
                              UploadVars.shared.uploadChunkSize = [[result objectForKey:@"upload_form_chunk_size"] integerValue];
                          } else {
                              // Just in case…
                              UploadVars.shared.uploadChunkSize = 500;
                          }

                          // Images and videos can be uploaded if their file types are found.
                          // The iPhone creates mov files that will be uploaded in mp4 format.
                          // This string is nil if the server does not provide it.
                          UploadVars.shared.serverFileTypes = [result objectForKey:@"upload_file_types"];
                          
                          // User rights are determined by Community extension (if installed)
                          if(!NetworkVarsObjc.shared.usesCommunityPluginV29) {
                              NSString *userStatus = [result objectForKey:@"status"];
                              NetworkVarsObjc.shared.hasAdminRights = ([userStatus isEqualToString:@"admin"] || [userStatus isEqualToString:@"webmaster"]);
                              NetworkVarsObjc.shared.hasNormalRights = [userStatus isEqualToString:@"normal"];
                          }
                          
                          // Collect the list of available sizes
                          // Let's start with default values
                          AlbumVars.shared.hasSquareSizeImages  = YES;
                          AlbumVars.shared.hasThumbSizeImages   = YES;
                          AlbumVars.shared.hasXXSmallSizeImages = NO;
                          AlbumVars.shared.hasXSmallSizeImages  = NO;
                          AlbumVars.shared.hasSmallSizeImages   = NO;
                          AlbumVars.shared.hasMediumSizeImages  = YES;
                          AlbumVars.shared.hasLargeSizeImages   = NO;
                          AlbumVars.shared.hasXLargeSizeImages  = NO;
                          AlbumVars.shared.hasXXLargeSizeImages = NO;
                          
                          // Update list of available sizes
                          id availableSizesList = [result objectForKey:@"available_sizes"];
                          for (NSString *size in availableSizesList) {
                              if ([size isEqualToString:@"square"]) {
                                  AlbumVars.shared.hasSquareSizeImages = YES;
                              } else if ([size isEqualToString:@"thumb"]) {
                                  AlbumVars.shared.hasThumbSizeImages = YES;
                              } else if ([size isEqualToString:@"2small"]) {
                                  AlbumVars.shared.hasXXSmallSizeImages = YES;
                              } else if ([size isEqualToString:@"xsmall"]) {
                                  AlbumVars.shared.hasXSmallSizeImages = YES;
                              } else if ([size isEqualToString:@"small"]) {
                                  AlbumVars.shared.hasSmallSizeImages = YES;
                              } else if ([size isEqualToString:@"medium"]) {
                                  AlbumVars.shared.hasMediumSizeImages = YES;
                              } else if ([size isEqualToString:@"large"]) {
                                  AlbumVars.shared.hasLargeSizeImages = YES;
                              } else if ([size isEqualToString:@"xlarge"]) {
                                  AlbumVars.shared.hasXLargeSizeImages = YES;
                              } else if ([size isEqualToString:@"xxlarge"]) {
                                  AlbumVars.shared.hasXXLargeSizeImages = YES;
                              }
                          }
                          
                          // Check that the actual default album thumbnail size is available
                          // and select the next available size in case of unavailability
                          switch (AlbumVars.shared.defaultAlbumThumbnailSize) {
                              case kPiwigoImageSizeSquare:
                                  // Should always be available
                                  break;
                              case kPiwigoImageSizeThumb:
                                  // Should always be available
                                  break;
                              case kPiwigoImageSizeXXSmall:
                                  if (!AlbumVars.shared.hasXXSmallSizeImages) {
                                      // Look for next available larger size
                                      if (AlbumVars.shared.hasXSmallSizeImages) {
                                          AlbumVars.shared.defaultAlbumThumbnailSize = kPiwigoImageSizeXSmall;
                                      } else if (AlbumVars.shared.hasSmallSizeImages) {
                                          AlbumVars.shared.defaultAlbumThumbnailSize = kPiwigoImageSizeSmall;
                                      } else {
                                          AlbumVars.shared.defaultAlbumThumbnailSize = kPiwigoImageSizeMedium;
                                      }
                                  }
                                  break;
                              case kPiwigoImageSizeXSmall:
                                  if (!AlbumVars.shared.hasXSmallSizeImages) {
                                      // Look for next available larger size
                                      if (AlbumVars.shared.hasSmallSizeImages) {
                                          AlbumVars.shared.defaultAlbumThumbnailSize = kPiwigoImageSizeSmall;
                                      } else {
                                          AlbumVars.shared.defaultAlbumThumbnailSize = kPiwigoImageSizeMedium;
                                      }
                                  }
                                  break;
                              case kPiwigoImageSizeSmall:
                                  if (!AlbumVars.shared.hasSmallSizeImages) {
                                      // Select next available larger size
                                      AlbumVars.shared.defaultAlbumThumbnailSize = kPiwigoImageSizeMedium;
                                  }
                                  break;
                              case kPiwigoImageSizeMedium:
                                  // Should always be available
                                  break;
                              case kPiwigoImageSizeLarge:
                                  if (!AlbumVars.shared.hasLargeSizeImages) {
                                      AlbumVars.shared.defaultAlbumThumbnailSize = kPiwigoImageSizeMedium;
                                  }
                                  break;
                              case kPiwigoImageSizeXLarge:
                                  if (!AlbumVars.shared.hasXLargeSizeImages) {
                                      AlbumVars.shared.defaultAlbumThumbnailSize = kPiwigoImageSizeMedium;
                                  }
                                  break;
                              case kPiwigoImageSizeXXLarge:
                                  if (!AlbumVars.shared.hasXXLargeSizeImages) {
                                      AlbumVars.shared.defaultAlbumThumbnailSize = kPiwigoImageSizeMedium;
                                  }
                                  break;
                              case kPiwigoImageSizeFullRes:
                              default:
                                  AlbumVars.shared.defaultAlbumThumbnailSize = kPiwigoImageSizeMedium;
                                  break;
                          }
                          
                          // Check that the actual default image thumbnail size is available
                          // and select the next available size in case of unavailability
                          switch (AlbumVars.shared.defaultThumbnailSize) {
                              case kPiwigoImageSizeSquare:
                                  // Should always be available
                                  break;
                              case kPiwigoImageSizeThumb:
                                  // Should always be available
                                  break;
                              case kPiwigoImageSizeXXSmall:
                                  if (!AlbumVars.shared.hasXXSmallSizeImages) {
                                      // Look for next available larger size
                                      if (AlbumVars.shared.hasXSmallSizeImages) {
                                          AlbumVars.shared.defaultThumbnailSize = kPiwigoImageSizeXSmall;
                                      } else if (AlbumVars.shared.hasSmallSizeImages) {
                                          AlbumVars.shared.defaultThumbnailSize = kPiwigoImageSizeSmall;
                                      } else {
                                          AlbumVars.shared.defaultThumbnailSize = kPiwigoImageSizeMedium;
                                      }
                                  }
                                  break;
                              case kPiwigoImageSizeXSmall:
                                  if (!AlbumVars.shared.hasXSmallSizeImages) {
                                      // Look for next available larger size
                                      if (AlbumVars.shared.hasSmallSizeImages) {
                                          AlbumVars.shared.defaultThumbnailSize = kPiwigoImageSizeSmall;
                                      } else {
                                          AlbumVars.shared.defaultThumbnailSize = kPiwigoImageSizeMedium;
                                      }
                                  }
                                  break;
                              case kPiwigoImageSizeSmall:
                                  if (!AlbumVars.shared.hasSmallSizeImages) {
                                      // Select next available larger size
                                      AlbumVars.shared.defaultThumbnailSize = kPiwigoImageSizeMedium;
                                  }
                                  break;
                              case kPiwigoImageSizeMedium:
                                  // Should always be available
                                  break;
                              case kPiwigoImageSizeLarge:
                                  if (!AlbumVars.shared.hasLargeSizeImages) {
                                      AlbumVars.shared.defaultThumbnailSize = kPiwigoImageSizeMedium;
                                  }
                                  break;
                              case kPiwigoImageSizeXLarge:
                                  if (!AlbumVars.shared.hasXLargeSizeImages) {
                                      AlbumVars.shared.defaultThumbnailSize = kPiwigoImageSizeMedium;
                                  }
                                  break;
                              case kPiwigoImageSizeXXLarge:
                                  if (!AlbumVars.shared.hasXXLargeSizeImages) {
                                      AlbumVars.shared.defaultThumbnailSize = kPiwigoImageSizeMedium;
                                  }
                                  break;
                              case kPiwigoImageSizeFullRes:
                              default:
                                  AlbumVars.shared.defaultThumbnailSize = kPiwigoImageSizeMedium;
                                  break;
                          }

                          // Calculate number of thumbnails per row for that selection
                          NSInteger minNberOfImages = [ImagesCollection imagesPerRowInPortraitForView:nil maxWidth:[PiwigoImageData widthForImageSizeType:(kPiwigoImageSize)AlbumVars.shared.defaultThumbnailSize]];

                          // Make sure that default number fits inside selected range
                          AlbumVars.shared.thumbnailsPerRowInPortrait = MAX(AlbumVars.shared.thumbnailsPerRowInPortrait, minNberOfImages);
                          AlbumVars.shared.thumbnailsPerRowInPortrait = MIN(AlbumVars.shared.thumbnailsPerRowInPortrait, 2*minNberOfImages);

                          // Check that the actual default image preview size is still available
                          // and select the next available size in case of unavailability
                          switch (ImageVars.shared.defaultImagePreviewSize) {
                              case kPiwigoImageSizeSquare:
                                  // Should always be available
                                  break;
                              case kPiwigoImageSizeThumb:
                                  // Should always be available
                                  break;
                              case kPiwigoImageSizeXXSmall:
                                  if (!AlbumVars.shared.hasXXSmallSizeImages) {
                                      // Look for next available larger size
                                      if (AlbumVars.shared.hasXSmallSizeImages) {
                                          ImageVars.shared.defaultImagePreviewSize = kPiwigoImageSizeXSmall;
                                      } else if (AlbumVars.shared.hasSmallSizeImages) {
                                          ImageVars.shared.defaultImagePreviewSize = kPiwigoImageSizeSmall;
                                      } else {
                                          ImageVars.shared.defaultImagePreviewSize = kPiwigoImageSizeMedium;
                                      }
                                  }
                                  break;
                              case kPiwigoImageSizeXSmall:
                                  if (!AlbumVars.shared.hasXSmallSizeImages) {
                                      // Look for next available larger size
                                      if (AlbumVars.shared.hasSmallSizeImages) {
                                          ImageVars.shared.defaultImagePreviewSize = kPiwigoImageSizeSmall;
                                      } else {
                                          ImageVars.shared.defaultImagePreviewSize = kPiwigoImageSizeMedium;
                                      }
                                  }
                                  break;
                              case kPiwigoImageSizeSmall:
                                  if (!AlbumVars.shared.hasSmallSizeImages) {
                                      // Select next available larger size
                                      ImageVars.shared.defaultImagePreviewSize = kPiwigoImageSizeMedium;
                                  }
                                  break;
                              case kPiwigoImageSizeMedium:
                                  // Should always be available
                                  break;
                              case kPiwigoImageSizeLarge:
                                  if (!AlbumVars.shared.hasLargeSizeImages) {
                                      // Look for next available larger size
                                      if (AlbumVars.shared.hasXLargeSizeImages) {
                                          ImageVars.shared.defaultImagePreviewSize = kPiwigoImageSizeXLarge;
                                      } else if (AlbumVars.shared.hasXXLargeSizeImages) {
                                          ImageVars.shared.defaultImagePreviewSize = kPiwigoImageSizeXXLarge;
                                      } else {
                                          ImageVars.shared.defaultImagePreviewSize = kPiwigoImageSizeFullRes;
                                      }
                                  }
                                  break;
                              case kPiwigoImageSizeXLarge:
                                  if (!AlbumVars.shared.hasXLargeSizeImages) {
                                      // Look for next available larger size
                                      if (AlbumVars.shared.hasXXLargeSizeImages) {
                                          ImageVars.shared.defaultImagePreviewSize = kPiwigoImageSizeXXLarge;
                                      } else {
                                          ImageVars.shared.defaultImagePreviewSize = kPiwigoImageSizeFullRes;
                                      }
                                  }
                                  break;
                              case kPiwigoImageSizeXXLarge:
                                  if (!AlbumVars.shared.hasXXLargeSizeImages) {
                                      ImageVars.shared.defaultImagePreviewSize = kPiwigoImageSizeFullRes;
                                  }
                                  break;
                              case kPiwigoImageSizeFullRes:
                              default:
                                  ImageVars.shared.defaultImagePreviewSize = kPiwigoImageSizeFullRes;
                                  break;
                          }
                      }

                      if(completion) { completion(result); }
                  } else {
                      if(completion) { completion(nil); }
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
    // API community.session.getStatus returns:
    //      real_user_status
    //      upload_categories_getList_method

    return [self post:kCommunitySessionGetStatus
        URLParameters:nil
           parameters:nil
       sessionManager:NetworkVarsObjc.shared.sessionManager
             progress:^(NSProgress * progress) {
                 if (NetworkVarsObjc.shared.userCancelledCommunication) {
                     [progress cancel];
                 }
             }
              success:^(NSURLSessionTask *task, id responseObject) {
                  
                  if(completion) {
                      if([[responseObject objectForKey:@"stat"] isEqualToString:@"ok"])
                      {
                          NSString *userStatus = [[responseObject objectForKey:@"result" ] objectForKey:@"real_user_status"];
                          NetworkVarsObjc.shared.hasAdminRights = ([userStatus isEqualToString:@"admin"] || [userStatus isEqualToString:@"webmaster"]);
                          NetworkVarsObjc.shared.hasNormalRights = [userStatus isEqualToString:@"normal"];

                          completion([responseObject objectForKey:@"result"]);
                      }
                      else
                      {
                          NetworkVarsObjc.shared.hasAdminRights = NO;
                          NetworkVarsObjc.shared.hasNormalRights = NO;
                          NetworkVarsObjc.shared.usesUploadAsync = NO;
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
       sessionManager:NetworkVarsObjc.shared.sessionManager
             progress:nil
			  success:^(NSURLSessionTask *task, id responseObject) {

                    if([[responseObject objectForKey:@"stat"] isEqualToString:@"ok"])
                      {
                          if (completion) {
                              completion(task, YES);
                          }
                      }
                      else
                      {
                          // Display Piwigo error
                          NSError *error = [NetworkHandler getPiwigoErrorFromResponse:responseObject
                                                path:kPiwigoSessionLogout andURLparams:nil];
                          if(completion) {
                              [NetworkHandler showPiwigoError:error withCompletion:^{
                                  completion(task, NO);
                              }];
                          } else {
                              [NetworkHandler showPiwigoError:error withCompletion:nil];
                          }
                      }

    } failure:^(NSURLSessionTask *task, NSError *error) {
                  if (fail) {
                      fail(task, error);
                  }
			  }];
}

@end
