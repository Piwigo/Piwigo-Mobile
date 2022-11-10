//
//  NetworkHandler.h
//  piwigo
//
//  Created by Spencer Baker on 9/10/14.
//  Copyright (c) 2014 CS 3450. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AFAutoPurgingImageCache.h"

typedef void(^SuccessBlock)(id responseObject);

// Piwigo URLs:
//FOUNDATION_EXPORT NSString * const kReflectionGetMethodList;
//FOUNDATION_EXPORT NSString * const pwgSessionLogin;
//FOUNDATION_EXPORT NSString * const pwgSessionGetStatus;
//FOUNDATION_EXPORT NSString * const kCommunitySessionGetStatus;
//FOUNDATION_EXPORT NSString * const kPiwigoSessionGetPluginsList;
//FOUNDATION_EXPORT NSString * const pwgSessionLogout;

//FOUNDATION_EXPORT NSString * const pwgCategoriesGetList;
//FOUNDATION_EXPORT NSString * const kCommunityCategoriesGetList;
FOUNDATION_EXPORT NSString * const pwgCategoriesGetImages;
//FOUNDATION_EXPORT NSString * const pwgCategoriesAdd;
//FOUNDATION_EXPORT NSString * const pwgCategoriesSetInfo;
//FOUNDATION_EXPORT NSString * const pwgCategoriesDelete;
//FOUNDATION_EXPORT NSString * const pwgCategoriesMove;
//FOUNDATION_EXPORT NSString * const pwgCategoriesSetRepresentative;
//FOUNDATION_EXPORT NSString * const kPiwigoCategoriesRefreshRepresentative;

//FOUNDATION_EXPORT NSString * const pwgImagesUpload;
//FOUNDATION_EXPORT NSString * const kCommunityImagesUploadCompleted;
//FOUNDATION_EXPORT NSString * const pwgImagesGetInfo;
//FOUNDATION_EXPORT NSString * const kPiwigoImageSetInfo;
//FOUNDATION_EXPORT NSString * const kPiwigoImageDelete;
FOUNDATION_EXPORT NSString * const kPiwigoImageSearch;

//FOUNDATION_EXPORT NSString * const pwgTagsGetList;
//FOUNDATION_EXPORT NSString * const pwgTagsGetAdminList;
FOUNDATION_EXPORT NSString * const kPiwigoTagsGetImages;
//FOUNDATION_EXPORT NSString * const pwgTagsAdd;

//FOUNDATION_EXPORT NSString * const kPiwigoUserFavoritesAdd;
//FOUNDATION_EXPORT NSString * const kPiwigoUserFavoritesRemove;
FOUNDATION_EXPORT NSString * const kPiwigoUserFavoritesGetList;

// Parameter keys:
FOUNDATION_EXPORT NSString * const kPiwigoImagesUploadParamData;
FOUNDATION_EXPORT NSString * const kPiwigoImagesUploadParamTitle;
FOUNDATION_EXPORT NSString * const kPiwigoImagesUploadParamFileName;
FOUNDATION_EXPORT NSString * const kPiwigoImagesUploadParamAuthor;
FOUNDATION_EXPORT NSString * const kPiwigoImagesUploadParamCreationDate;
FOUNDATION_EXPORT NSString * const kPiwigoImagesUploadParamDescription;
FOUNDATION_EXPORT NSString * const kPiwigoImagesUploadParamCategory;
FOUNDATION_EXPORT NSString * const kPiwigoImagesUploadParamTags;
FOUNDATION_EXPORT NSString * const kPiwigoImagesUploadParamPrivacy;
FOUNDATION_EXPORT NSString * const kPiwigoImagesUploadParamChunk;
FOUNDATION_EXPORT NSString * const kPiwigoImagesUploadParamChunks;
FOUNDATION_EXPORT NSString * const kPiwigoImagesUploadParamMimeType;

// Piwigo errors
FOUNDATION_EXPORT NSInteger const kInvalidMethod;
FOUNDATION_EXPORT NSInteger const kMissingParameter;
FOUNDATION_EXPORT NSInteger const kInvalidParameter;

@interface NetworkHandler : NSObject

+(void)createJSONdataSessionManager;
+(void)createFavoritesDataSessionManager;
+(void)createImagesSessionManager;
+(AFHTTPSessionManager *)createUploadSessionManager;

+(NSString*)encodedImageURL:(NSString*)originalURL;
+(NSString*)getURLWithPath:(NSString*)originalURL withURLParams:(NSDictionary*)params;

+(NSURLSessionTask*)post:(NSString*)path
           URLParameters:(NSDictionary*)urlParams
              parameters:(NSDictionary*)parameters
          sessionManager:(AFHTTPSessionManager *)sessionManager
                progress:(void (^)(NSProgress *))progress
                 success:(void (^)(NSURLSessionTask *task, id responseObject))success
                 failure:(void (^)(NSURLSessionTask *task, NSError *error))fail;

+(NSError *)getPiwigoErrorFromResponse:(id)responseObject path:(NSString *)path andURLparams:(NSDictionary *)urlParams;
+(void)showPiwigoError:(NSError*)error withCompletion:(void (^)(void))completion;

@end
