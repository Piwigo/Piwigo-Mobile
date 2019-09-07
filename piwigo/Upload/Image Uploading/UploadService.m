//
//  UploadService.m
//  piwigo
//
//  Created by Spencer Baker on 1/28/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "UploadService.h"
#import "Model.h"
#import "ImageUpload.h"
#import "PiwigoTagData.h"
#import "CategoriesData.h"

@implementation UploadService

+(void)uploadImage:(NSData *)imageData
   withInformation:(NSDictionary *)imageInformation
			onProgress:(void (^)(NSProgress *progress, NSInteger currentChunk, NSInteger totalChunks))onProgress
		  OnCompletion:(void (^)(NSURLSessionTask *task, NSDictionary *response))completion
			 onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
    // Calculate chunk size
    NSInteger chunkSize = ([Model sharedInstance].uploadChunkSize * 1024);
    
    // Create upload session
    [NetworkHandler createUploadSessionManager];        // 60s timeout, 2 connections max

    // Calculate number of chunks
    NSInteger chunks = imageData.length / chunkSize;
	if(imageData.length % chunkSize != 0) {
		chunks++;
	}
	
    // Start sending data to server
    [self sendChunk:imageData withInformation:[imageInformation mutableCopy]
          forOffset:0
            onChunk:0 forTotalChunks:(NSInteger)chunks
         onProgress:onProgress
       OnCompletion:^(NSURLSessionTask *task, NSDictionary *response) {
           // Close upload session
           [[Model sharedInstance].imageUploadManager invalidateSessionCancelingTasks:YES];
           // Done, return
           if(completion) {
               completion(task, response);
           }
       }
          onFailure:^(NSURLSessionTask *task, NSError *error) {
              // Close upload session
              [[Model sharedInstance].imageUploadManager invalidateSessionCancelingTasks:YES];
              // Done, return
              if(fail) {
                  fail(task, error);
              }
          }
    ];
}

+(void)sendChunk:(NSData *)imageData withInformation:(NSMutableDictionary *)imageInformation
       forOffset:(NSInteger)offset
         onChunk:(NSInteger)count forTotalChunks:(NSInteger)chunks
					 onProgress:(void (^)(NSProgress *progress, NSInteger currentChunk, NSInteger totalChunks))onProgress
				   OnCompletion:(void (^)(NSURLSessionTask *task, NSDictionary *response))completion
					  onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
    // Calculate this chunk size
    NSInteger chunkSize = ([Model sharedInstance].uploadChunkSize * 1024);
    NSInteger length = [imageData length];
    NSUInteger thisChunkSize = length  - offset > chunkSize ? chunkSize : length - offset;
    __block NSData *chunk = [imageData subdataWithRange:NSMakeRange(offset, thisChunkSize)];

    [imageInformation setObject:[NSString stringWithFormat:@"%@", @(count)]
                         forKey:kPiwigoImagesUploadParamChunk];
    [imageInformation setObject:[NSString stringWithFormat:@"%@", @(chunks)]
                         forKey:kPiwigoImagesUploadParamChunks];

    NSInteger nextChunkNumber = count + 1;
    offset += thisChunkSize;

//    NSLog(@"=> postMultiPart…");
//    CFRunLoopRunInMode(kCFRunLoopDefaultMode, 5.0, false);
    [self postMultiPart:kPiwigoImagesUpload
                   data:chunk
             parameters:imageInformation
               progress:^(NSProgress *progress) {
                   dispatch_async(dispatch_get_main_queue(),
                                  ^(void){if(progress) onProgress((NSProgress *)progress, count + 1, chunks);});
               }
                success:^(NSURLSessionTask *task, id responseObject) {
                    // Continue?
                    if(count >= chunks - 1)
                    {
                        // Release memory
                        chunk = nil;
                        [imageInformation removeAllObjects];

                        // Done, return
                        if(completion) {
                            completion(task, responseObject);
                        }
                    }
                    else
                    {
                        // Release memory
                        chunk = nil;
                        [imageInformation removeObjectsForKeys:@[kPiwigoImagesUploadParamChunk,kPiwigoImagesUploadParamChunks]];

                        // Keep going!
                        [self sendChunk:imageData
                        withInformation:imageInformation
                              forOffset:offset
                                onChunk:nextChunkNumber
                         forTotalChunks:chunks
                             onProgress:onProgress
                           OnCompletion:completion
                              onFailure:fail];
                    }
            
              } failure:^(NSURLSessionTask *task, NSError *error) {
                  // Release memory
                  chunk = nil;
                  [imageInformation removeAllObjects];
                  // failed!
                  if(fail)
                  {
                      fail(task, error);
                  }
              }
      ];
}

+(NSURLSessionTask*)setImageInfoForImageWithId:(NSString*)imageId
                               withInformation:(NSDictionary*)imageInformation
                                    onProgress:(void (^)(NSProgress *))progress
                                  OnCompletion:(void (^)(NSURLSessionTask *task, NSDictionary *response))completion
                                     onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
	
    NSString *tagIdList;
    if ([[[imageInformation objectForKey:kPiwigoImagesUploadParamTags]
          valueForKey:@"description"] count]) {
        tagIdList = [[[imageInformation objectForKey:kPiwigoImagesUploadParamTags]
                            valueForKey:@"description"] componentsJoinedByString:@","];
    } else {
        tagIdList = @"";
    }
	
	NSURLSessionTask *request = [self post:kPiwigoImageSetInfo
                             URLParameters:nil
                                parameters:@{
                                             @"image_id" : imageId,
                                             @"file" : [imageInformation objectForKey:kPiwigoImagesUploadParamFileName],
                                             @"name" : [imageInformation objectForKey:kPiwigoImagesUploadParamTitle],
                                             @"author" : [imageInformation objectForKey:kPiwigoImagesUploadParamAuthor],
                                             @"comment" : [imageInformation objectForKey:kPiwigoImagesUploadParamDescription],
                                             @"tag_ids" : tagIdList,
                                             @"level" : [imageInformation objectForKey:kPiwigoImagesUploadParamPrivacy],
                                             @"single_value_mode" : @"replace",
                                             @"multiple_value_mode" : @"replace"
                                             }
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
                                NSInteger errorCode = NSNotFound;
                                if ([responseObject objectForKey:@"err"]) {
                                    errorCode = [[responseObject objectForKey:@"err"] intValue];
                                }
                                NSString *errorMsg = @"";
                                if ([responseObject objectForKey:@"message"]) {
                                    errorMsg = [responseObject objectForKey:@"message"];
                                }
                                [NetworkHandler showPiwigoError:errorCode withMessage:errorMsg forPath:kPiwigoImagesGetInfo andURLparams:nil];

                                completion(task, nil);
                            }
                        }
                    }
                   failure:fail
    ];
	
	return request;
}

+(NSURLSessionTask*)getUploadedImageStatusById:(NSString*)imageId
                                    inCategory:(NSInteger)categoryId
                                    onProgress:(void (^)(NSProgress *))progress
                                  OnCompletion:(void (^)(NSURLSessionTask *task, NSDictionary *response))completion
                                     onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
	NSURLSessionTask *request = [self post:kCommunityImagesUploadCompleted
                             URLParameters:nil
                                parameters:@{
                                             @"pwg_token"   : [Model sharedInstance].pwgToken,
                                             @"image_id"    : imageId,
                                             @"category_id" : @(categoryId),
                                            }
                                  progress:progress
                                   success:completion
                                   failure:fail];
	
	return request;
}

+(NSURLSessionTask*)updateImageInfo:(ImageUpload*)imageInfo
                         onProgress:(void (^)(NSProgress *))progress
                       OnCompletion:(void (^)(NSURLSessionTask *task, NSDictionary *response))completion
                          onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
	NSMutableArray *tagIds = [NSMutableArray new];
	for(PiwigoTagData *tagData in imageInfo.tags)
	{
		[tagIds addObject:@(tagData.tagId)];
	}
	
	NSDictionary *imageProperties = @{
                                      kPiwigoImagesUploadParamFileName : imageInfo.fileName,
                                      kPiwigoImagesUploadParamTitle : imageInfo.title,
									  kPiwigoImagesUploadParamPrivacy : [NSString stringWithFormat:@"%@", @(imageInfo.privacyLevel)],
									  kPiwigoImagesUploadParamAuthor : imageInfo.author,
									  kPiwigoImagesUploadParamDescription : imageInfo.imageDescription,
									  kPiwigoImagesUploadParamTags : [tagIds copy]
									  };
	
	return [self setImageInfoForImageWithId:[NSString stringWithFormat:@"%@", @(imageInfo.imageId)]
                            withInformation:imageProperties
                                 onProgress:progress
                               OnCompletion:^(NSURLSessionTask *task, NSDictionary *response) {
                                   
                                   // Update cache
                                   [[[CategoriesData sharedInstance] getCategoryById:imageInfo.categoryToUploadTo] updateImageAfterEdit:imageInfo];
                                   
                                   if(completion)
                                   {
                                       completion(task, response);
                                   }
                               }
                                  onFailure:fail];
}

@end
