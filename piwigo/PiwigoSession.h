//
//  PiwigoNetwork.h
//  piwigo
//
//  Created by Spencer Baker on 1/20/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "NetworkHandler.h"
#import <Foundation/Foundation.h>

@interface PiwigoSession : NetworkHandler

+(AFHTTPRequestOperation*)performLoginWithServer:(NSString*)server
										 andUser:(NSString*)user
									 andPassword:(NSString*)password
									onCompletion:(void (^)(BOOL result, id response))completion
									   onFailure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))fail;

+(AFHTTPRequestOperation*)getStatusOnCompletion:(void (^)(NSDictionary *responseObject))completion
									  onFailure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))fail;

@end
