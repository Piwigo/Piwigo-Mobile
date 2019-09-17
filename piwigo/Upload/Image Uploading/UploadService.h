//
//  UploadService.h
//  piwigo
//
//  Created by Spencer Baker on 1/28/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "NetworkHandler.h"

FOUNDATION_EXPORT NSString * const kUploadImage;

@class ImageUpload;
@class PiwigoImageData;

@interface UploadService : NetworkHandler

+(void)uploadImage:(NSData*)imageData
   withInformation:(NSDictionary*)imageInformation
        onProgress:(void (^)(NSProgress *progress, NSInteger currentChunk, NSInteger totalChunks))onProgress
      OnCompletion:(void (^)(NSURLSessionTask *task, NSDictionary *response))completion
         onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail;

+(NSURLSessionTask*)setImageInfoForImageWithId:(NSInteger)imageId
                               withInformation:(NSDictionary*)imageInformation
                                    onProgress:(void (^)(NSProgress *))progress
                                  OnCompletion:(void (^)(NSURLSessionTask *task, NSDictionary *response))completion
                                     onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail;

+(NSURLSessionTask*)setImageFileForImageWithId:(NSInteger)imageId
                                  withFileName:(NSString*)fileName
                                    onProgress:(void (^)(NSProgress *))progress
                                  OnCompletion:(void (^)(NSURLSessionTask *task, NSDictionary *response))completion
                                     onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail;

+(NSURLSessionTask*)updateImageInfo:(ImageUpload*)imageInfo
                         onProgress:(void (^)(NSProgress *))progress
                       OnCompletion:(void (^)(NSURLSessionTask *task, NSDictionary *response))completion
                          onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail;

+(NSURLSessionTask*)getUploadedImageStatusById:(NSString*)imageId
                                    inCategory:(NSInteger)categoryId
                                    onProgress:(void (^)(NSProgress *))progress
                                  OnCompletion:(void (^)(NSURLSessionTask *task, NSDictionary *response))completion
                                     onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail;

@end
