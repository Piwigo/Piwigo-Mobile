//
//  SessionService.m
//  piwigo
//
//  Created by Spencer Baker on 1/20/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "ImagesCollection.h"
#import "PiwigoImageData.h"
#import "SessionService.h"

@implementation SessionService

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
       sessionManager:NetworkVarsObjc.sessionManager
             progress:^(NSProgress * progress) {
                 if (NetworkVarsObjc.userCancelledCommunication) {
                     [progress cancel];
                 }
             }
              success:^(NSURLSessionTask *task, id responseObject) {
                  
                  if([[responseObject objectForKey:@"stat"] isEqualToString:@"ok"])
                  {
                      NSDictionary *result = [responseObject objectForKey:@"result"];
                      // Retrieve a potentially new token (required since the use of uploadAsync)
                      NetworkVarsObjc.pwgToken = [result objectForKey:@"pwg_token"];

                      if (isLogginIn) {
                          NetworkVarsObjc.language = [result objectForKey:@"language"];
                          
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
                          NetworkVarsObjc.pwgVersion = [versionStr copy];

                          // Community users cannot upload with uploadAsync with Piwigo 11.x
                          if (NetworkVarsObjc.usesCommunityPluginV29 && NetworkVarsObjc.hasNormalRights &&
                              ([@"11.0.0" compare:versionStr options:NSNumericSearch] != NSOrderedDescending) &&
                              ([@"12.0.0" compare:versionStr options:NSNumericSearch] != NSOrderedAscending)) {
                              NetworkVarsObjc.usesUploadAsync = NO;
                          }

                          NSString *charset = [[result objectForKey:@"charset"] uppercaseString];
                          if ([charset isEqualToString:@"UTF-8"]) {
                              NetworkVarsObjc.stringEncoding = NSUTF8StringEncoding;
                          } else if ([charset isEqualToString:@"UTF-16"]) {
                              NetworkVarsObjc.stringEncoding = NSUTF16StringEncoding;
                          } else if ([charset isEqualToString:@"ISO-8859-1"]) {
                              NetworkVarsObjc.stringEncoding = NSWindowsCP1252StringEncoding;
                          } else if ([charset isEqualToString:@"US-ASCII"]) {
                              NetworkVarsObjc.stringEncoding = NSASCIIStringEncoding;
                          } else if ([charset isEqualToString:@"X-EUC"]) {
                              NetworkVarsObjc.stringEncoding = NSJapaneseEUCStringEncoding;
                          } else if ([charset isEqualToString:@"ISO-8859-3"]) {
                              NetworkVarsObjc.stringEncoding = NSISOLatin1StringEncoding;
                          } else if ([charset isEqualToString:@"ISO-8859-3"]) {
                              NetworkVarsObjc.stringEncoding = NSISOLatin1StringEncoding;
                          } else if ([charset isEqualToString:@"SHIFT-JIS"]) {
                              NetworkVarsObjc.stringEncoding = NSShiftJISStringEncoding;
                          } else if ([charset isEqualToString:@"CP870"]) {
                              NetworkVarsObjc.stringEncoding = NSISOLatin2StringEncoding;
                          } else if ([charset isEqualToString:@"UNICODE"]) {
                              NetworkVarsObjc.stringEncoding = NSUnicodeStringEncoding;
                          } else if ([charset isEqualToString:@"WINDOWS-1251"]) {
                              NetworkVarsObjc.stringEncoding = NSWindowsCP1251StringEncoding;
                          } else if ([charset isEqualToString:@"WINDOWS-1252"]) {
                              NetworkVarsObjc.stringEncoding = NSWindowsCP1252StringEncoding;
                          } else if ([charset isEqualToString:@"WINDOWS-1253"]) {
                              NetworkVarsObjc.stringEncoding = NSWindowsCP1253StringEncoding;
                          } else if ([charset isEqualToString:@"WINDOWS-1254"]) {
                              NetworkVarsObjc.stringEncoding = NSWindowsCP1254StringEncoding;
                          } else if ([charset isEqualToString:@"WINDOWS-1250"]) {
                              NetworkVarsObjc.stringEncoding = NSWindowsCP1250StringEncoding;
                          } else if ([charset isEqualToString:@"ISO-2022-JP"]) {
                              NetworkVarsObjc.stringEncoding = NSISO2022JPStringEncoding;
                          } else if ([charset isEqualToString:@"ISO-2022-JP"]) {
                              NetworkVarsObjc.stringEncoding = NSISO2022JPStringEncoding;
                          } else if ([charset isEqualToString:@"MACINTOSH"]) {
                              NetworkVarsObjc.stringEncoding = NSMacOSRomanStringEncoding;
                          } else if ([charset isEqualToString:@"UNICODEFFFE"]) {
                              NetworkVarsObjc.stringEncoding = NSUTF16BigEndianStringEncoding;
                          } else if ([charset isEqualToString:@"UTF-32"]) {
                              NetworkVarsObjc.stringEncoding = NSUTF32StringEncoding;
                          } else {
                              // UTF-8 string encoding by default
                              NetworkVarsObjc.stringEncoding = NSUTF8StringEncoding;
                          }
                          NSLog(@"   version: %@, usesUploadAsync: %@, charset: %@", NetworkVarsObjc.pwgVersion,
                                NetworkVarsObjc.usesUploadAsync ? @"YES" : @"NO", charset);

                          // Upload chunk size is null if not provided by server
                          NSInteger uploadChunkSize = [[result objectForKey:@"upload_form_chunk_size"] integerValue];
                          if (uploadChunkSize != 0) {
                              UploadVarsObjc.uploadChunkSize = [[result objectForKey:@"upload_form_chunk_size"] integerValue];
                          } else {
                              // Just in case…
                              UploadVarsObjc.uploadChunkSize = 500;
                          }

                          // Images and videos can be uploaded if their file types are found.
                          // The iPhone creates mov files that will be uploaded in mp4 format.
                          // This string is nil if the server does not provide it.
                          UploadVarsObjc.serverFileTypes = [result objectForKey:@"upload_file_types"];
                          
                          // User rights are determined by Community extension (if installed)
                          if(!NetworkVarsObjc.usesCommunityPluginV29) {
                              NSString *userStatus = [result objectForKey:@"status"];
                              NetworkVarsObjc.hasAdminRights = ([userStatus isEqualToString:@"admin"] || [userStatus isEqualToString:@"webmaster"]);
                              NetworkVarsObjc.hasNormalRights = [userStatus isEqualToString:@"normal"];
                              NetworkVarsObjc.hasGuestRights = [userStatus isEqualToString:@"guest"];
                          }
                          
                          // Collect the list of available sizes
                          // Let's start with default values
                          AlbumVars.hasSquareSizeImages  = YES;
                          AlbumVars.hasThumbSizeImages   = YES;
                          AlbumVars.hasXXSmallSizeImages = NO;
                          AlbumVars.hasXSmallSizeImages  = NO;
                          AlbumVars.hasSmallSizeImages   = NO;
                          AlbumVars.hasMediumSizeImages  = YES;
                          AlbumVars.hasLargeSizeImages   = NO;
                          AlbumVars.hasXLargeSizeImages  = NO;
                          AlbumVars.hasXXLargeSizeImages = NO;
                          
                          // Update list of available sizes
                          id availableSizesList = [result objectForKey:@"available_sizes"];
                          for (NSString *size in availableSizesList) {
                              if ([size isEqualToString:@"square"]) {
                                  AlbumVars.hasSquareSizeImages = YES;
                              } else if ([size isEqualToString:@"thumb"]) {
                                  AlbumVars.hasThumbSizeImages = YES;
                              } else if ([size isEqualToString:@"2small"]) {
                                  AlbumVars.hasXXSmallSizeImages = YES;
                              } else if ([size isEqualToString:@"xsmall"]) {
                                  AlbumVars.hasXSmallSizeImages = YES;
                              } else if ([size isEqualToString:@"small"]) {
                                  AlbumVars.hasSmallSizeImages = YES;
                              } else if ([size isEqualToString:@"medium"]) {
                                  AlbumVars.hasMediumSizeImages = YES;
                              } else if ([size isEqualToString:@"large"]) {
                                  AlbumVars.hasLargeSizeImages = YES;
                              } else if ([size isEqualToString:@"xlarge"]) {
                                  AlbumVars.hasXLargeSizeImages = YES;
                              } else if ([size isEqualToString:@"xxlarge"]) {
                                  AlbumVars.hasXXLargeSizeImages = YES;
                              }
                          }
                          
                          // Check that the actual default album thumbnail size is available
                          // and select the next available size in case of unavailability
                          switch (AlbumVars.defaultAlbumThumbnailSize) {
                              case kPiwigoImageSizeSquare:
                                  // Should always be available
                                  break;
                              case kPiwigoImageSizeThumb:
                                  // Should always be available
                                  break;
                              case kPiwigoImageSizeXXSmall:
                                  if (!AlbumVars.hasXXSmallSizeImages) {
                                      // Look for next available larger size
                                      if (AlbumVars.hasXSmallSizeImages) {
                                          AlbumVars.defaultAlbumThumbnailSize = kPiwigoImageSizeXSmall;
                                      } else if (AlbumVars.hasSmallSizeImages) {
                                          AlbumVars.defaultAlbumThumbnailSize = kPiwigoImageSizeSmall;
                                      } else {
                                          AlbumVars.defaultAlbumThumbnailSize = kPiwigoImageSizeMedium;
                                      }
                                  }
                                  break;
                              case kPiwigoImageSizeXSmall:
                                  if (!AlbumVars.hasXSmallSizeImages) {
                                      // Look for next available larger size
                                      if (AlbumVars.hasSmallSizeImages) {
                                          AlbumVars.defaultAlbumThumbnailSize = kPiwigoImageSizeSmall;
                                      } else {
                                          AlbumVars.defaultAlbumThumbnailSize = kPiwigoImageSizeMedium;
                                      }
                                  }
                                  break;
                              case kPiwigoImageSizeSmall:
                                  if (!AlbumVars.hasSmallSizeImages) {
                                      // Select next available larger size
                                      AlbumVars.defaultAlbumThumbnailSize = kPiwigoImageSizeMedium;
                                  }
                                  break;
                              case kPiwigoImageSizeMedium:
                                  // Should always be available
                                  break;
                              case kPiwigoImageSizeLarge:
                                  if (!AlbumVars.hasLargeSizeImages) {
                                      AlbumVars.defaultAlbumThumbnailSize = kPiwigoImageSizeMedium;
                                  }
                                  break;
                              case kPiwigoImageSizeXLarge:
                                  if (!AlbumVars.hasXLargeSizeImages) {
                                      AlbumVars.defaultAlbumThumbnailSize = kPiwigoImageSizeMedium;
                                  }
                                  break;
                              case kPiwigoImageSizeXXLarge:
                                  if (!AlbumVars.hasXXLargeSizeImages) {
                                      AlbumVars.defaultAlbumThumbnailSize = kPiwigoImageSizeMedium;
                                  }
                                  break;
                              case kPiwigoImageSizeFullRes:
                              default:
                                  AlbumVars.defaultAlbumThumbnailSize = kPiwigoImageSizeMedium;
                                  break;
                          }
                          
                          // Check that the actual default image thumbnail size is available
                          // and select the next available size in case of unavailability
                          switch (AlbumVars.defaultThumbnailSize) {
                              case kPiwigoImageSizeSquare:
                                  // Should always be available
                                  break;
                              case kPiwigoImageSizeThumb:
                                  // Should always be available
                                  break;
                              case kPiwigoImageSizeXXSmall:
                                  if (!AlbumVars.hasXXSmallSizeImages) {
                                      // Look for next available larger size
                                      if (AlbumVars.hasXSmallSizeImages) {
                                          AlbumVars.defaultThumbnailSize = kPiwigoImageSizeXSmall;
                                      } else if (AlbumVars.hasSmallSizeImages) {
                                          AlbumVars.defaultThumbnailSize = kPiwigoImageSizeSmall;
                                      } else {
                                          AlbumVars.defaultThumbnailSize = kPiwigoImageSizeMedium;
                                      }
                                  }
                                  break;
                              case kPiwigoImageSizeXSmall:
                                  if (!AlbumVars.hasXSmallSizeImages) {
                                      // Look for next available larger size
                                      if (AlbumVars.hasSmallSizeImages) {
                                          AlbumVars.defaultThumbnailSize = kPiwigoImageSizeSmall;
                                      } else {
                                          AlbumVars.defaultThumbnailSize = kPiwigoImageSizeMedium;
                                      }
                                  }
                                  break;
                              case kPiwigoImageSizeSmall:
                                  if (!AlbumVars.hasSmallSizeImages) {
                                      // Select next available larger size
                                      AlbumVars.defaultThumbnailSize = kPiwigoImageSizeMedium;
                                  }
                                  break;
                              case kPiwigoImageSizeMedium:
                                  // Should always be available
                                  break;
                              case kPiwigoImageSizeLarge:
                                  if (!AlbumVars.hasLargeSizeImages) {
                                      AlbumVars.defaultThumbnailSize = kPiwigoImageSizeMedium;
                                  }
                                  break;
                              case kPiwigoImageSizeXLarge:
                                  if (!AlbumVars.hasXLargeSizeImages) {
                                      AlbumVars.defaultThumbnailSize = kPiwigoImageSizeMedium;
                                  }
                                  break;
                              case kPiwigoImageSizeXXLarge:
                                  if (!AlbumVars.hasXXLargeSizeImages) {
                                      AlbumVars.defaultThumbnailSize = kPiwigoImageSizeMedium;
                                  }
                                  break;
                              case kPiwigoImageSizeFullRes:
                              default:
                                  AlbumVars.defaultThumbnailSize = kPiwigoImageSizeMedium;
                                  break;
                          }

                          // Calculate number of thumbnails per row for that selection
                          NSInteger minNberOfImages = [ImagesCollection imagesPerRowInPortraitForView:nil maxWidth:[PiwigoImageData widthForImageSizeType:(kPiwigoImageSize)AlbumVars.defaultThumbnailSize]];

                          // Make sure that default number fits inside selected range
                          AlbumVars.thumbnailsPerRowInPortrait = MAX(AlbumVars.thumbnailsPerRowInPortrait, minNberOfImages);
                          AlbumVars.thumbnailsPerRowInPortrait = MIN(AlbumVars.thumbnailsPerRowInPortrait, 2*minNberOfImages);

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
                                  if (!AlbumVars.hasXXSmallSizeImages) {
                                      // Look for next available larger size
                                      if (AlbumVars.hasXSmallSizeImages) {
                                          ImageVars.shared.defaultImagePreviewSize = kPiwigoImageSizeXSmall;
                                      } else if (AlbumVars.hasSmallSizeImages) {
                                          ImageVars.shared.defaultImagePreviewSize = kPiwigoImageSizeSmall;
                                      } else {
                                          ImageVars.shared.defaultImagePreviewSize = kPiwigoImageSizeMedium;
                                      }
                                  }
                                  break;
                              case kPiwigoImageSizeXSmall:
                                  if (!AlbumVars.hasXSmallSizeImages) {
                                      // Look for next available larger size
                                      if (AlbumVars.hasSmallSizeImages) {
                                          ImageVars.shared.defaultImagePreviewSize = kPiwigoImageSizeSmall;
                                      } else {
                                          ImageVars.shared.defaultImagePreviewSize = kPiwigoImageSizeMedium;
                                      }
                                  }
                                  break;
                              case kPiwigoImageSizeSmall:
                                  if (!AlbumVars.hasSmallSizeImages) {
                                      // Select next available larger size
                                      ImageVars.shared.defaultImagePreviewSize = kPiwigoImageSizeMedium;
                                  }
                                  break;
                              case kPiwigoImageSizeMedium:
                                  // Should always be available
                                  break;
                              case kPiwigoImageSizeLarge:
                                  if (!AlbumVars.hasLargeSizeImages) {
                                      // Look for next available larger size
                                      if (AlbumVars.hasXLargeSizeImages) {
                                          ImageVars.shared.defaultImagePreviewSize = kPiwigoImageSizeXLarge;
                                      } else if (AlbumVars.hasXXLargeSizeImages) {
                                          ImageVars.shared.defaultImagePreviewSize = kPiwigoImageSizeXXLarge;
                                      } else {
                                          ImageVars.shared.defaultImagePreviewSize = kPiwigoImageSizeFullRes;
                                      }
                                  }
                                  break;
                              case kPiwigoImageSizeXLarge:
                                  if (!AlbumVars.hasXLargeSizeImages) {
                                      // Look for next available larger size
                                      if (AlbumVars.hasXXLargeSizeImages) {
                                          ImageVars.shared.defaultImagePreviewSize = kPiwigoImageSizeXXLarge;
                                      } else {
                                          ImageVars.shared.defaultImagePreviewSize = kPiwigoImageSizeFullRes;
                                      }
                                  }
                                  break;
                              case kPiwigoImageSizeXXLarge:
                                  if (!AlbumVars.hasXXLargeSizeImages) {
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
       sessionManager:NetworkVarsObjc.sessionManager
             progress:^(NSProgress * progress) {
                 if (NetworkVarsObjc.userCancelledCommunication) {
                     [progress cancel];
                 }
             }
              success:^(NSURLSessionTask *task, id responseObject) {
                  
                  if(completion) {
                      if([[responseObject objectForKey:@"stat"] isEqualToString:@"ok"])
                      {
                          NSString *userStatus = [[responseObject objectForKey:@"result" ] objectForKey:@"real_user_status"];
                          NetworkVarsObjc.hasAdminRights = ([userStatus isEqualToString:@"admin"] || [userStatus isEqualToString:@"webmaster"]);
                          NetworkVarsObjc.hasNormalRights = [userStatus isEqualToString:@"normal"];
                          NetworkVarsObjc.hasGuestRights = [userStatus isEqualToString:@"guest"];
                          completion([responseObject objectForKey:@"result"]);
                      }
                      else
                      {
                          NetworkVarsObjc.hasAdminRights = NO;
                          NetworkVarsObjc.hasNormalRights = NO;
                          NetworkVarsObjc.usesUploadAsync = NO;
                          completion(nil);
                      }
                  }
              } failure:^(NSURLSessionTask *task, NSError *error) {
                  
                  if(fail) {
                      fail(task, error);
                  }
              }];
}

@end
