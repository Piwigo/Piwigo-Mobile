//
//  SessionService.h
//  piwigo
//
//  Created by Spencer Baker on 1/20/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "NetworkHandler.h"
#import <Foundation/Foundation.h>

@interface SessionService : NetworkHandler

+(NSURLSessionTask*)getPiwigoStatusAtLogin:(BOOL)isLogginIn
                              OnCompletion:(void (^)(NSDictionary *responseObject))completion
                                 onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail;

+(NSURLSessionTask*)getCommunityStatusOnCompletion:(void (^)(NSDictionary *responseObject))completion
                                         onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail;

@end
