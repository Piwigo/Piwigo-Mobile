//
//  AlbumService.h
//  piwigo
//
//  Created by Spencer Baker on 1/24/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "NetworkHandler.h"

@class PiwigoImageData;

@interface AlbumService : NetworkHandler

+(NSURLSessionTask*)getAlbumListForCategory:(NSInteger)categoryId
                               OnCompletion:(void (^)(NSURLSessionTask *task, NSArray *albums))completion
                                  onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail;

+(NSURLSessionTask*)createCategoryWithName:(NSString*)categoryName
                                withStatus:(NSString*)categoryStatus
                              OnCompletion:(void (^)(NSURLSessionTask *task, BOOL createdSuccessfully))completion
                                 onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail;

+(NSURLSessionTask*)renameCategory:(NSInteger)categoryId
                           forName:(NSString*)categoryName
                      OnCompletion:(void (^)(NSURLSessionTask *task, BOOL renamedSuccessfully))completion
                         onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail;

+(NSURLSessionTask*)deleteCategory:(NSInteger)categoryId
                      OnCompletion:(void (^)(NSURLSessionTask *task, BOOL deletedSuccessfully))completion
                         onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail;

+(NSURLSessionTask*)moveCategory:(NSInteger)categoryId
                    intoCategory:(NSInteger)categoryToMoveIntoId
                    OnCompletion:(void (^)(NSURLSessionTask *task, BOOL movedSuccessfully))completion
                       onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail;

+(NSURLSessionTask*)setCategoryRepresentativeForCategory:(NSInteger)categoryId
                                              forImageId:(NSInteger)imageId
                                            OnCompletion:(void (^)(NSURLSessionTask *task, BOOL setSuccessfully))completion
                                               onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail;

@end
